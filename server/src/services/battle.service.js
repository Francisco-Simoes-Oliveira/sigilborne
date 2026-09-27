const { createHash } = require('node:crypto');
const GameError = require('../domain/game-error');
const { validId, validateCard, validateDeckCards } = require('../domain/card-schema');
const { validateEnemy, validateRewards } = require('../domain/enemy-schema');
const { createDeckService } = require('./deck.service');
const { finalizeRewards } = require('./reward.service');
const Engine = require('../battle/BattleEngine');

function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(key => [key, stable(value[key])]));
  return value;
}
const fingerprint = cards => createHash('sha256').update(JSON.stringify(stable([...cards].sort((a, b) => a.id.localeCompare(b.id))))).digest('hex');
function checkId(id) { if (!validId(id)) throw new GameError('INVALID_ID', 400, 'Identificador inválido.'); }
function owned(doc, ownerId, label) {
  if (!doc.exists) throw new GameError('NOT_FOUND', 404, `${label} não encontrado.`);
  const data = doc.data();
  if (data.ownerId !== ownerId) throw new GameError('FORBIDDEN', 403, 'Você não tem acesso a este registro.');
  return data;
}

function createBattleService(db, { choose } = {}) {
  const deckService = createDeckService(db);

  async function readCards(transaction, battle) {
    const deck = { cards: battle.normalCardIds, ultimateId: battle.player.ultimate.id };
    const ids = [...new Set([...deck.cards, deck.ultimateId])];
    const docs = await transaction.getAll(...ids.map(id => db.collection('cards').doc(id)));
    const cards = docs.filter(doc => doc.exists).map(doc => ({ ...doc.data(), id: doc.id }));
    let changed = fingerprint(cards) !== battle.catalogFingerprint;
    try { validateDeckCards(deck, battle.classId, new Map(cards.map(card => [card.id, card]))); } catch (_) { changed = true; }
    // Invalid or removed definitions cannot make a saved result unreadable in Flutter.
    const displayCards = ids.map(id => {
      const card = cards.find(item => item.id === id);
      try { validateCard(card); return card; } catch (_) { /* Safe display placeholder. */ }
      return {
      id, name: 'Carta indisponível', classId: battle.classId, cost: 0,
      type: id === deck.ultimateId ? 'ultimate' : 'skill', description: 'A definição desta carta está inválida ou foi removida do catálogo.',
      damage: null, tags: [], requirements: [], conditionalEffects: [], effects: [],
      };
    });
    return { cards: displayCards, changed };
  }

  function present(id, battle, catalog, events = []) {
    const playable = Object.fromEntries(catalog.cards.map(card => {
      const state = catalog.changed ? { canPlay: false, reason: 'O catálogo mudou. A luta foi preservada; restaure as definições para continuar.', target: 'enemy' }
        : Engine.availability(battle, card, card.id === battle.player.ultimate.id);
      return [card.id, state];
    }));
    return {
      battle: { ...battle, id, cards: catalog.cards, playable, catalogChanged: catalog.changed,
        canEndTurn: !catalog.changed && battle.status === 'active' && battle.currentActor === 'player' },
      events,
    };
  }

  function record(battle, events) {
    const numbered = events.map(event => ({ ...event, id: ++battle.eventSequence, version: battle.version }));
    battle.recentEvents = [...battle.recentEvents, ...numbered].slice(-40);
    return numbered;
  }

  async function listEnemies() {
    const snapshot = await db.collection('enemies').get();
    return { enemies: snapshot.docs.map(doc => {
      const enemy = doc.data();
      validateEnemy(enemy);
      return { id: doc.id, name: enemy.name, description: enemy.description ?? '', attributes: enemy.attributes };
    }), supportedClassIds: ['warrior'] };
  }

  async function startBattle(ownerId, { characterId, enemyId }) {
    checkId(characterId); checkId(enemyId);
    // Reuses the existing, concurrency-safe starter deck recovery for legacy characters.
    await deckService.getCharacterDeck(ownerId, characterId);
    const reference = db.collection('battles').doc();
    return db.runTransaction(async transaction => {
      const characterRef = db.collection('characters').doc(characterId);
      const character = owned(await transaction.get(characterRef), ownerId, 'Personagem');
      if (character.classId !== 'warrior') throw new GameError('CLASS_NOT_SUPPORTED', 422, 'Esta primeira batalha está disponível para Guerreiro. Os outros decks continuam disponíveis para consulta.');
      if (character.lastBattleId) {
        checkId(character.lastBattleId);
        const previousDoc = await transaction.get(db.collection('battles').doc(character.lastBattleId));
        if (previousDoc.exists) {
          const previous = owned(previousDoc, ownerId, 'Batalha');
          if (previous.characterId !== characterId) throw new GameError('INVALID_BATTLE_LINK', 409, 'Vínculo de batalha inválido.');
          if (previous.status === 'active') return present(previousDoc.id, previous, await readCards(transaction, previous));
        }
      }
      const enemyDoc = await transaction.get(db.collection('enemies').doc(enemyId));
      if (!enemyDoc.exists) throw new GameError('ENEMY_NOT_FOUND', 404, 'Inimigo não encontrado. Execute o seed de inimigos.');
      const enemy = enemyDoc.data(); validateEnemy(enemy);
      if (enemy.rewards == null) throw new GameError('ENEMY_REWARDS_MISSING', 503, 'Atualize o seed de inimigos com --migrate-rewards antes de iniciar uma nova luta.');
      validateRewards(enemy.rewards);
      const deckDoc = await transaction.get(db.collection('decks').doc(character.equippedDeckId));
      const deckData = owned(deckDoc, ownerId, 'Deck');
      if (deckData.characterId !== characterId) throw new GameError('INVALID_DECK_LINK', 403, 'O deck não pertence a este personagem.');
      const ids = [...new Set([...deckData.cards, deckData.ultimateId])];
      const docs = await transaction.getAll(...ids.map(id => db.collection('cards').doc(id)));
      const cards = docs.filter(doc => doc.exists).map(doc => ({ ...doc.data(), id: doc.id }));
      const byId = new Map(cards.map(card => [card.id, card]));
      try { validateDeckCards(deckData, character.classId, byId); }
      catch (_) { throw new GameError('INVALID_DECK', 503, 'Deck inválido para iniciar a batalha. Confira o catálogo.'); }
      const deck = { id: deckDoc.id, cards: deckData.cards.map(id => byId.get(id)), ultimate: byId.get(deckData.ultimateId) };
      const result = Engine.startBattle({ ownerId, characterId, character, enemyId, enemy, deck }, choose);
      const now = new Date();
      const battle = { ...result.battle, rewards: { xp: enemy.rewards.xp, gold: enemy.rewards.gold }, result: null,
        catalogFingerprint: fingerprint(cards), createdAt: now, updatedAt: now };
      const settlement = finalizeRewards(battle, character, now);
      if (settlement) battle.result = settlement.result;
      const events = record(battle, result.events);
      transaction.create(reference, battle);
      transaction.update(characterRef, { lastBattleId: reference.id, ...(settlement?.characterUpdates ?? {}) });
      return present(reference.id, battle, { cards, changed: false }, events);
    });
  }

  async function getBattle(ownerId, id) {
    checkId(id);
    return db.runTransaction(async transaction => {
      const battle = owned(await transaction.get(db.collection('battles').doc(id)), ownerId, 'Batalha');
      return present(id, battle, await readCards(transaction, battle));
    });
  }

  async function latestBattle(ownerId, characterId) {
    checkId(characterId);
    return db.runTransaction(async transaction => {
      const character = owned(await transaction.get(db.collection('characters').doc(characterId)), ownerId, 'Personagem');
      if (!character.lastBattleId) return { battle: null, events: [] };
      checkId(character.lastBattleId);
      const doc = await transaction.get(db.collection('battles').doc(character.lastBattleId));
      const battle = owned(doc, ownerId, 'Batalha');
      if (battle.characterId !== characterId) throw new GameError('INVALID_BATTLE_LINK', 409, 'Vínculo de batalha inválido.');
      return present(doc.id, battle, await readCards(transaction, battle));
    });
  }

  async function command(ownerId, id, action, payload) {
    checkId(id);
    if (!Number.isInteger(payload.expectedVersion) || payload.expectedVersion < 1) throw new GameError('VERSION_REQUIRED', 400, 'Envie a versão atual da batalha.');
    const ref = db.collection('battles').doc(id);
    return db.runTransaction(async transaction => {
      const battle = owned(await transaction.get(ref), ownerId, 'Batalha');
      if (battle.version !== payload.expectedVersion) throw new GameError('STALE_BATTLE', 409, 'A batalha já mudou. Atualize o estado antes de agir novamente.');
      if (battle.status !== 'active') throw new GameError('BATTLE_FINISHED', 409, 'A batalha já terminou.');
      const catalog = await readCards(transaction, battle);
      if (catalog.changed) throw new GameError('CATALOG_CHANGED', 409, 'O catálogo mudou durante a luta. Restaure as definições para continuar esta batalha.');
      let events;
      if (action === 'end-turn') events = Engine.endTurn(battle);
      else if (['play-card', 'play-ultimate'].includes(action)) {
        const ultimate = action === 'play-ultimate';
        const cardId = ultimate ? battle.player.ultimate.id : payload.cardId;
        const card = catalog.cards.find(card => card.id === cardId);
        if (!card) throw new GameError('CARD_NOT_IN_HAND', 409, 'Carta indisponível nesta batalha.');
        events = Engine.playCard(battle, card, payload.target, ultimate);
      } else throw new GameError('INVALID_ACTION', 400, 'Ação inválida.');
      battle.version++;
      battle.updatedAt = new Date();
      // All reads happen before any writes. A retry re-reads both the battle
      // version and the character balance, so rewards cannot be duplicated/lost.
      if (battle.status !== 'active' && battle.result?.rewardsApplied !== true) {
        checkId(battle.characterId);
        const characterRef = db.collection('characters').doc(battle.characterId);
        const character = owned(await transaction.get(characterRef), ownerId, 'Personagem');
        const settlement = finalizeRewards(battle, character, battle.updatedAt);
        battle.result = settlement.result;
        if (settlement.characterUpdates) transaction.update(characterRef, settlement.characterUpdates);
      }
      const numbered = record(battle, events);
      transaction.update(ref, battle);
      return present(id, battle, catalog, numbered);
    });
  }

  return { listEnemies, startBattle, getBattle, latestBattle, command };
}
module.exports = { createBattleService };
