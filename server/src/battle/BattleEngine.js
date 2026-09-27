const GameError = require('../domain/game-error');
const rules = require('../data/game-rules');
const { startCycle, rotate } = require('./CardCycle');
const { matches } = require('./ConditionResolver');
const { endActorTurn } = require('./StatusResolver');
const { dealDamage, resolveEffect, cardSupported } = require('./EffectResolver');

const fail = (code, message) => { throw new GameError(code, 409, message); };

function finish(battle, events) {
  if (battle.status !== 'active') return true;
  if (battle.player.hp <= 0 || battle.enemy.hp <= 0) {
    battle.status = battle.player.hp <= 0 ? 'defeat' : 'victory';
    battle.currentActor = 'none';
    events.push({ type: battle.status === 'victory' ? 'VICTORY' : 'DEFEAT' });
    return true;
  }
  return false;
}

function cardTarget(card) {
  const effects = [...card.effects, ...card.conditionalEffects.flatMap(item => item.effects)];
  return card.damage || effects.some(effect => effect.target === 'enemy') ? 'enemy' : 'self';
}

function availability(battle, card, ultimate = false) {
  let reason = null;
  if (battle.status !== 'active') reason = 'A batalha terminou.';
  else if (battle.currentActor !== 'player') reason = 'Aguarde seu turno.';
  else if (!cardSupported(card)) reason = 'Esta carta ainda não é suportada em batalha.';
  else if (!ultimate && !battle.player.hand.includes(card.id)) reason = 'A carta não está na mão.';
  else if (ultimate && battle.player.ultimate.charge < battle.player.ultimate.maxCharge) reason = 'A Ultimate ainda está carregando.';
  else if (battle.player.energy < card.cost) reason = 'Energia insuficiente.';
  else if (!card.requirements.every(condition => matches(condition, battle))) reason = 'Requisito da carta não atendido.';
  return { canPlay: reason === null, reason, target: cardTarget(card) };
}

function enemyTurn(battle, events) {
  battle.currentActor = 'enemy';
  battle.player.receivedDamageThisTurn = false;
  battle.enemy.receivedDamageThisTurn = false;
  events.push({ type: 'TURN_STARTED', actor: 'enemy' });
  const index = battle.enemy.patternIndex;
  const actionId = battle.enemy.behavior.actions[index];
  const action = battle.enemy.behavior.definitions[actionId];
  battle.enemy.patternIndex = (index + 1) % battle.enemy.behavior.actions.length;
  if (battle.enemy.statuses.stunned) {
    events.push({ type: 'ACTION_SKIPPED', actor: 'enemy', reason: 'stunned' });
  } else {
    events.push({ type: 'ENEMY_ACTION', actionId, name: action.name });
    dealDamage(battle, 'enemy', 'player', action.damage, {}, events);
    if (finish(battle, events)) return;
    const counter = battle.player.statuses.counterStance;
    if (counter) {
      events.push({ type: 'COUNTER_ATTACK', source: 'player' });
      // Reaction damage never recursively triggers another reaction.
      dealDamage(battle, 'player', 'enemy', counter.parameters.damage, {}, events);
      if (finish(battle, events)) return;
    }
  }
  endActorTurn(battle, 'enemy', events);
  events.push({ type: 'TURN_ENDED', actor: 'enemy' });
}

function startBattle({ ownerId, characterId, character, enemyId, enemy, deck }, choose) {
  const definitions = [...deck.cards, deck.ultimate];
  if (!definitions.every(cardSupported)) throw new GameError('UNSUPPORTED_CARD', 422, 'O deck possui efeitos ainda não suportados nesta versão de batalha.');
  const attributes = character.attributes;
  if (!['hp', 'strength', 'magicPower', 'defense', 'speed', 'maxEnergy'].every(key => Number.isFinite(attributes?.[key]) && attributes[key] >= 0) || attributes.hp <= 0 || attributes.maxEnergy <= 0) {
    throw new GameError('INVALID_ATTRIBUTES', 409, 'Os atributos do personagem estão inválidos.');
  }
  const participant = (name, values) => ({
    name, hp: values.hp, maxHp: values.hp, attributes: structuredClone(values),
    guard: 0, statuses: {}, receivedDamageThisTurn: false,
  });
  const battle = {
    schemaVersion: 1, ownerId, characterId, enemyId, classId: character.classId, deckId: deck.id,
    status: 'active', turn: 1, currentActor: 'player', version: 1,
    normalCardIds: deck.cards.map(card => card.id),
    player: {
      ...participant(character.name, attributes), energy: attributes.maxEnergy, maxEnergy: attributes.maxEnergy,
      ...startCycle(deck.cards.map(card => card.id), choose),
      ultimate: { id: deck.ultimate.id, charge: 0, maxCharge: 100 },
    },
    enemy: { ...participant(enemy.name, enemy.attributes), behavior: structuredClone(enemy.behavior), patternIndex: 0 },
    recentEvents: [], eventSequence: 0,
  };
  const events = [{ type: 'BATTLE_STARTED', enemyId }];
  for (const cardId of battle.player.hand) events.push({ type: 'CARD_DRAWN', cardId });
  if (battle.enemy.attributes.speed > battle.player.attributes.speed) enemyTurn(battle, events);
  if (battle.status === 'active') { battle.currentActor = 'player'; events.push({ type: 'TURN_STARTED', actor: 'player' }); }
  return { battle, events };
}

function playCard(battle, card, target, ultimate = false) {
  if (battle.status !== 'active') fail('BATTLE_FINISHED', 'A batalha já terminou.');
  if (battle.currentActor !== 'player') fail('NOT_PLAYER_TURN', 'Aguarde seu turno.');
  if (ultimate ? card.id !== battle.player.ultimate.id : !battle.player.hand.includes(card.id)) fail('CARD_NOT_IN_HAND', 'Esta carta não está disponível na mão.');
  if (!ultimate && card.type === 'ultimate') fail('INVALID_CARD', 'Use a ação separada da Ultimate.');
  if (target !== cardTarget(card)) fail('INVALID_TARGET', 'Alvo inválido para esta carta.');
  if (battle.player.energy < card.cost) fail('NOT_ENOUGH_ENERGY', 'Energia insuficiente.');
  if (!card.requirements.every(condition => matches(condition, battle))) fail('REQUIREMENTS_NOT_MET', 'Requisito da carta não atendido.');
  if (ultimate && battle.player.ultimate.charge < battle.player.ultimate.maxCharge) fail('ULTIMATE_NOT_READY', 'A Ultimate ainda está carregando.');
  if (!cardSupported(card)) fail('UNSUPPORTED_CARD', 'Efeito ainda não suportado.');

  // Evaluate all conditions before any effect changes the state.
  const effects = [...card.effects, ...card.conditionalEffects.filter(entry => matches(entry.condition, battle)).flatMap(entry => entry.effects)];
  const modifiers = { criticalMultiplier: 1, damageMultiplier: 1 };
  for (const effect of effects) {
    if (effect.type === 'critical') modifiers.criticalMultiplier = Math.max(modifiers.criticalMultiplier, effect.multiplier ?? 1.5);
    if (effect.type === 'modifyDamage') modifiers.damageMultiplier *= effect.multiplier;
  }
  const events = [{ type: ultimate ? 'ULTIMATE_USED' : 'CARD_USED', cardId: card.id }, { type: 'ENERGY_SPENT', amount: card.cost }];
  battle.player.energy -= card.cost;
  if (card.damage) dealDamage(battle, 'player', 'enemy', card.damage, modifiers, events);
  for (const effect of effects) resolveEffect(battle, 'player', effect, events);
  if (ultimate) {
    battle.player.ultimate.charge = 0;
  } else {
    events.push({ type: 'CARD_DRAWN', cardId: rotate(battle.player, card.id) });
    battle.player.ultimate.charge = Math.min(100, battle.player.ultimate.charge + 25);
  }
  finish(battle, events);
  return events;
}

function endTurn(battle) {
  if (battle.status !== 'active') fail('BATTLE_FINISHED', 'A batalha já terminou.');
  if (battle.currentActor !== 'player') fail('NOT_PLAYER_TURN', 'Aguarde seu turno.');
  const events = [{ type: 'TURN_ENDED', actor: 'player' }];
  endActorTurn(battle, 'player', events);
  enemyTurn(battle, events);
  if (battle.status !== 'active') return events;
  battle.turn++;
  battle.currentActor = 'player';
  const recovered = Math.min(rules.energyPerTurn, battle.player.maxEnergy - battle.player.energy);
  battle.player.energy += recovered;
  events.push({ type: 'ENERGY_RECOVERED', amount: recovered }, { type: 'TURN_STARTED', actor: 'player' });
  return events;
}

module.exports = { startBattle, playCard, endTurn, availability };
