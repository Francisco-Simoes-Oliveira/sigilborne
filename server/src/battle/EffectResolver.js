const { calculateDamage } = require('./DamageCalculator');
const ElementResolver = require('./ElementResolver');
const { applyStatus, removeStatus, supportedStatuses } = require('./StatusResolver');
const { conditionsSupported } = require('./ConditionResolver');
const { hunterPet } = require('../data/combat-classes');
function targetFor(source, target) { return target === 'self' ? source : source === 'player' ? 'enemy' : 'player'; }

function dealDamage(battle, source, target, damage, modifiers = {}, events) {
  if (!damage || battle[target].hp <= 0) return { dodged: false, totalDamage: 0 };
  const defender = battle[target];
  const dodge = defender.statuses.dodge;
  if (dodge && (dodge.parameters.charges ?? 1) > 0) {
    dodge.parameters.charges = (dodge.parameters.charges ?? 1) - 1;
    events.push({ type: 'DODGE', source, target });
    if (dodge.parameters.charges <= 0) removeStatus(defender, 'dodge', events, target);
    if (target === 'player') applyStatus(battle, target, { status: 'prepared', durationTurns: 1 }, events, target);
    return { dodged: true, totalDamage: 0 };
  }
  const reaction = ElementResolver.reaction(damage.element, defender);
  const focused = battle[source].statuses.focused;
  const focusApplies = focused && focused.parameters.damageNature === damage.nature && (focused.parameters.charges ?? 1) > 0;
  const appliedModifiers = { ...modifiers, damageMultiplier: (modifiers.damageMultiplier ?? 1) * (reaction === 'conductive' ? 1.25 : 1) * (focusApplies ? focused.parameters.damageMultiplier : 1) };
  if (focusApplies) {
    focused.parameters.charges = (focused.parameters.charges ?? 1) - 1;
    if (focused.parameters.charges <= 0) removeStatus(battle[source], 'focused', events, source);
  }
  const elementMultiplier = ElementResolver.multiplier(damage.element, defender);
  if (elementMultiplier !== 1) events.push({ type: elementMultiplier > 1 ? 'ELEMENT_ADVANTAGE' : 'ELEMENT_RESISTED', source, target, element: damage.element, multiplier: elementMultiplier });
  if (reaction) events.push({ type: 'ELEMENT_REACTION', source, target, reaction });
  let totalDamage = 0;
  for (let hit = 0; hit < (damage.hits ?? 1) && defender.hp > 0; hit++) {
    const result = calculateDamage(battle[source], defender, damage, appliedModifiers);
    if ((appliedModifiers.criticalMultiplier ?? 1) > 1) events.push({ type: 'CRITICAL', source, target, multiplier: appliedModifiers.criticalMultiplier });
    if (result.absorbed > 0) events.push({ type: 'GUARD_ABSORBED', target, amount: result.absorbed });
    let amount = result.amount;
    const shield = defender.statuses.shield;
    if (shield && amount > 0) {
      const absorbed = Math.min(amount, shield.remainingHp ?? 0);
      shield.remainingHp -= absorbed; amount -= absorbed;
      events.push({ type: 'SHIELD_ABSORBED', target, amount: absorbed });
      if (shield.remainingHp <= 0) removeStatus(defender, 'shield', events, target);
    }
    amount = Math.min(defender.hp, amount);
    defender.hp -= amount;
    totalDamage += amount;
    if (amount > 0) defender.receivedDamageThisTurn = true;
    events.push({ type: 'DAMAGE', source, target, amount, nature: damage.nature, element: damage.element });
  }
  if (reaction === 'freeze' && defender.hp > 0) applyStatus(battle, target, { status: 'frozen', durationTurns: 1 }, events, source);
  return { dodged: false, totalDamage };
}
function resolveEffect(battle, source, effect, events) {
  const target = targetFor(source, effect.target);
  const actor = battle[target];
  switch (effect.type) {
    case 'damage': dealDamage(battle, source, target, effect.damage, {}, events); break;
    case 'applyStatus': applyStatus(battle, target, effect, events, source); break;
    case 'gainGuard': applyStatus(battle, target, { status: 'guard', durationTurns: effect.durationTurns, parameters: { damageReduction: effect.reduction } }, events, source); break;
    case 'removeStatus': removeStatus(actor, effect.status, events, target); break;
    case 'heal':
    case 'restoreHealth': {
      const amount = Math.min(actor.maxHp - actor.hp, Math.max(0, Math.round(battle[source].attributes[effect.scaling] * effect.multiplier)));
      actor.hp += amount; events.push({ type: 'HEAL', source, target, amount }); break;
    }
    case 'restoreEnergy': {
      const amount = Math.min(effect.amount, actor.maxEnergy - actor.energy);
      actor.energy += amount; events.push({ type: 'ENERGY_RECOVERED', amount, actor: target }); break;
    }
    case 'summonPet': {
      actor.pet = { ...structuredClone(effect.pet), remainingTurns: effect.durationTurns, appliedOnTurn: battle.turn,
        onHitEffects: battle.player.pet?.onHitEffects ?? (battle.classId === 'hunter' ? structuredClone(hunterPet.onHitEffects) : []) };
      events.push({ type: 'PET_SUMMONED', name: actor.pet.name, target, turns: effect.durationTurns }); break;
    }
    case 'petAttack': {
      const pet = battle[source].pet;
      if (!pet) break;
      events.push({ type: 'PET_ATTACK', name: pet.name, source, target });
      const hit = dealDamage(battle, source, target, { ...pet.damage, multiplier: pet.damage.multiplier * effect.multiplier }, {}, events);
      if (actor.hp > 0 && !hit.dodged) for (const onHit of pet.onHitEffects ?? []) resolveEffect(battle, source, onHit, events);
      break;
    }
    case 'setTrap': {
      battle[source].traps ??= [];
      battle[source].traps.push({ trigger: effect.trigger, remainingTurns: effect.durationTurns, charges: effect.charges, effects: structuredClone(effect.effects), appliedOnTurn: battle.turn });
      events.push({ type: 'TRAP_SET', source, turns: effect.durationTurns }); break;
    }
    case 'critical':
    case 'modifyDamage': break;
    default: throw new Error(`Unsupported effect: ${effect.type}`);
  }
}
function effectSupported(effect) {
  if (effect.type === 'applyStatus') return supportedStatuses.has(effect.status);
  if (effect.type === 'setTrap') return Array.isArray(effect.effects) && effect.effects.every(effectSupported);
  return ['damage', 'gainGuard', 'heal', 'restoreHealth', 'restoreEnergy', 'petAttack', 'summonPet', 'critical', 'modifyDamage', 'removeStatus'].includes(effect.type);
}
function cardSupported(card) {
  return card.requirements.every(conditionsSupported) && card.effects.every(effectSupported)
    && card.conditionalEffects.every(item => conditionsSupported(item.condition) && item.effects.every(effectSupported));
}
module.exports = { dealDamage, resolveEffect, cardSupported };
