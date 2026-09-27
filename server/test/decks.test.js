const assert = require('node:assert/strict');
const { test } = require('node:test');
const { cards, starterDecks } = require('../src/data/starter-cards');
const rules = require('../src/data/game-rules');
const { classIds, validateCatalog, validateDeckCards } = require('../src/domain/card-schema');
const { seedCards } = require('../scripts/seedCards');
const { createDeckService } = require('../src/services/deck.service');
const FakeFirestore = require('./helpers/fake-firestore');
const load = require('./helpers/load-module');

function database() {
  return new FakeFirestore(Object.fromEntries(classIds.map(id => [`classes/${id}`, {
    name: id, baseAttributes: { hp: 100, strength: 10, magicPower: 12, defense: 8, speed: 9, maxEnergy: 6 },
  }])));
}
async function seeded() { const db = database(); await seedCards(db); return db; }
function legacy(db, classId = 'warrior', characterId = 'old') {
  db.set(`characters/${characterId}`, { ownerId: 'user-a', classId, name: 'Kael', equippedDeckId: null, attributes: { hp: 100 } });
}
const code = expected => error => error.code === expected;
const characterService = db => load('src/services/character.service.js', { '../config/firebase': { db } });

test('catalog contains exactly the requested 9 normal cards and one Ultimate for each class', () => {
  validateCatalog(cards, starterDecks);
  const expected = {
    warrior: ['Corte', 'Golpe Pesado', 'Bloqueio', 'Golpe de Escudo', 'Contra-Ataque', 'Investida', 'Provocar', 'Segundo Fôlego', 'Golpe Duplo', 'Muralha Inquebrável'],
    mage: ['Míssil Arcano', 'Bola de Fogo', 'Lança de Gelo', 'Faísca', 'Barreira Arcana', 'Canalizar', 'Encharcar', 'Explosão Elemental', 'Concentração', 'Zero Absoluto'],
    rogue: ['Corte Rápido', 'Esquiva', 'Ataque pelas Costas', 'Veneno', 'Corte Profundo', 'Preparação', 'Golpe Duplo', 'Explorar Fraqueza', 'Execução', 'Execução Perfeita'],
    hunter: ['Tiro Rápido', 'Tiro Marcador', 'Tiro Preciso', 'Comando: Atacar', 'Armadilha de Caça', 'Recuar', 'Flecha Perfurante', 'Instinto Predador', 'Disparo Duplo', 'A Caçada Começou'],
  };
  for (const classId of classIds) assert.deepEqual(cards.filter(card => card.classId === classId).map(card => card.name), expected[classId]);
  assert.equal(cards.some(card => 'level' in card), false);
  assert.equal(rules.handSize, 3);
  assert.equal(rules.initialMaxEnergy, 6);
  assert.equal(rules.energyPerTurn, 3);
  assert.equal(rules.resetEnergyAtTurnEnd, false);
  assert.equal(rules.ultimateInHandCycle, false);
});

test('seed writes 40 cards and four starters once, preserving unrelated data on rerun', async () => {
  const db = database();
  legacy(db);
  assert.equal((await seedCards(db)).created, 44);
  assert.equal(db.paths('cards').length, 40);
  assert.equal(db.paths('starterDecks').length, 4);
  assert.equal((await seedCards(db)).created, 0);
  assert.equal(db.data('characters/old').equippedDeckId, null);
  assert.equal(db.commits, 1);
});

test('seed conflicts or missing classes abort without partial writes', async () => {
  const db = database();
  db.set(`cards/${cards[0].id}`, { name: 'Edited by user' });
  await assert.rejects(seedCards(db), /já existe com dados diferentes/);
  assert.equal(db.paths('cards').length, 1);
  assert.equal(db.paths('starterDecks').length, 0);
  const empty = new FakeFirestore();
  await assert.rejects(seedCards(empty), /quatro classes/);
  assert.equal(empty.paths('cards').length, 0);
});

for (const classId of classIds) {
  test(`new ${classId} character and a resolved 9+1 deck are committed atomically`, async () => {
    const db = await seeded();
    const character = await characterService(db).createCharacter({ ownerId: 'user-a', name: '  Hero  ', classId });
    const stored = db.data(`characters/${character.id}`);
    assert.equal(stored.name, 'Hero');
    assert.ok(stored.equippedDeckId);
    assert.equal(stored.attributes.maxEnergy, 6);
    const deck = await createDeckService(db).getCharacterDeck('user-a', character.id);
    assert.equal(deck.id, character.equippedDeckId);
    assert.equal(deck.characterId, character.id);
    assert.equal(deck.ownerId, 'user-a');
    assert.equal(deck.cards.length, 9);
    assert.equal(deck.ultimate.type, 'ultimate');
    assert.ok(deck.cards.every(card => card.classId === classId && card.type !== 'ultimate'));
    assert.deepEqual(deck.cards.map(card => card.id), starterDecks[classId].cards);
    assert.equal(deck.ultimate.id, starterDecks[classId].ultimateId);
    assert.ok(db.data(`decks/${deck.id}`).createdAt instanceof Date);
    assert.equal(db.commits, 2);
  });
}

test('old characters get one deck even under simultaneous requests and later reloads', async () => {
  const db = await seeded();
  legacy(db);
  const service = createDeckService(db);
  const decks = await Promise.all(Array.from({ length: 6 }, () => service.getCharacterDeck('user-a', 'old')));
  assert.equal(new Set(decks.map(deck => deck.id)).size, 1);
  assert.equal(db.paths('decks').length, 1);
  assert.equal(db.data('characters/old').equippedDeckId, decks[0].id);
  assert.deepEqual(db.data('characters/old').attributes, { hp: 100 });
  assert.equal((await service.getCharacterDeck('user-a', 'old')).id, decks[0].id);
  assert.ok(db.retries > 0);
});

test('missing starter or invalid catalog creates neither partial character nor orphan deck', async () => {
  const db = database();
  await assert.rejects(characterService(db).createCharacter({ ownerId: 'user-a', name: 'Hero', classId: 'warrior' }), code('STARTER_DECK_NOT_FOUND'));
  assert.equal(db.paths('characters').length, 0);
  assert.equal(db.paths('decks').length, 0);
  legacy(db);
  await assert.rejects(createDeckService(db).getCharacterDeck('user-a', 'old'), code('STARTER_DECK_NOT_FOUND'));
  assert.equal(db.data('characters/old').equippedDeckId, null);
});

test('unknown characters return 404 and foreign characters return 403 before any deck write', async () => {
  const db = await seeded();
  legacy(db);
  const service = createDeckService(db);
  await assert.rejects(service.getCharacterDeck('user-a', 'absent'), code('CHARACTER_NOT_FOUND'));
  await assert.rejects(service.getCharacterDeck('user-a', 'bad/path'), code('CHARACTER_NOT_FOUND'));
  await assert.rejects(service.getCharacterDeck('user-b', 'old'), error => error.status === 403);
  assert.equal(db.paths('decks').length, 0);
  assert.equal(db.data('characters/old').equippedDeckId, null);
});

test('existing custom decks retain order and up to three copies, without replacement', async () => {
  const db = await seeded();
  legacy(db);
  const service = createDeckService(db);
  const deck = await service.getCharacterDeck('user-a', 'old');
  const stored = db.data(`decks/${deck.id}`);
  const custom = [stored.cards[0], stored.cards[0], stored.cards[0], ...stored.cards.slice(1, 7)];
  db.set(`decks/${deck.id}`, { ...stored, name: 'Meu deck', cards: custom });
  const again = await service.getCharacterDeck('user-a', 'old');
  assert.equal(again.name, 'Meu deck');
  assert.deepEqual(again.cards.map(card => card.id), custom);
  assert.equal(db.paths('decks').length, 1);
});

for (const mismatch of [{ ownerId: 'user-b' }, { characterId: 'other-character' }]) {
  test(`a forged deck relationship is rejected: ${JSON.stringify(mismatch)}`, async () => {
    const db = await seeded();
    legacy(db);
    const service = createDeckService(db);
    const deck = await service.getCharacterDeck('user-a', 'old');
    db.set(`decks/${deck.id}`, { ...db.data(`decks/${deck.id}`), ...mismatch });
    await assert.rejects(service.getCharacterDeck('user-a', 'old'), error => error.status === 403);
    assert.equal(db.paths('decks').length, 1);
  });
}

test('a broken non-null deck link is reported without overwriting it', async () => {
  const db = await seeded();
  legacy(db);
  db.set('characters/old', { ...db.data('characters/old'), equippedDeckId: 'missing' });
  await assert.rejects(createDeckService(db).getCharacterDeck('user-a', 'old'), code('DECK_NOT_FOUND'));
  assert.equal(db.data('characters/old').equippedDeckId, 'missing');
  assert.equal(db.paths('decks').length, 0);
});

test('missing card, wrong class, Ultimate in normal slots and excess copies are rejected', async () => {
  const byId = new Map(cards.map(card => [card.id, card]));
  const source = starterDecks.warrior;
  for (const replacement of ['unknown', starterDecks.mage.cards[0], source.ultimateId]) {
    assert.throws(() => validateDeckCards({ ...source, cards: [replacement, ...source.cards.slice(1)] }, 'warrior', byId));
  }
  assert.throws(() => validateDeckCards({ ...source, cards: Array(9).fill(source.cards[0]) }, 'warrior', byId));
  const db = await seeded();
  db.records.delete(`cards/${source.cards[0]}`);
  await assert.rejects(characterService(db).createCharacter({ ownerId: 'user-a', name: 'Hero', classId: 'warrior' }), code('INVALID_CARD_CATALOG'));
  assert.equal(db.paths('characters').length, 0);
  assert.equal(db.paths('decks').length, 0);
});

test('character controller ignores attributes, cards, owner and equipped deck supplied by Flutter', async () => {
  const db = await seeded();
  const controller = load('src/controllers/character.controller.js', { '../services/character.service': characterService(db) });
  const res = { status(value) { this.statusCode = value; return this; }, json(value) { this.body = value; return this; } };
  await controller.create({ user: { uid: 'user-a' }, body: { name: 'Hero', classId: 'warrior', ownerId: 'user-b', attributes: { hp: 999999 }, cards: ['cheat'], equippedDeckId: 'fake' } }, res);
  assert.equal(res.statusCode, 201);
  assert.equal(res.body.ownerId, 'user-a');
  assert.equal(res.body.attributes.hp, 100);
  assert.notEqual(res.body.equippedDeckId, 'fake');
  assert.deepEqual(db.data(`decks/${res.body.equippedDeckId}`).cards, starterDecks.warrior.cards);
});

test('GET deck route uses actual auth middleware and controller, with no-store and proper errors', async () => {
  const db = await seeded();
  legacy(db);
  const authenticate = load('src/middleware/auth.middleware.js', {
    '../config/firebase': { auth: { async verifyIdToken(token) { if (token !== 'valid') throw new Error('invalid'); return { uid: 'user-a' }; } } },
  });
  const deckController = load('src/controllers/deck.controller.js', { '../config/firebase': { db } });
  const routes = [];
  load('src/routes/character.routes.js', {
    express: { Router: () => ({ get: (url, ...handlers) => routes.push({ url, handlers }), post() {} }) },
    '../middleware/auth.middleware': authenticate,
    '../controllers/character.controller': {},
    '../controllers/deck.controller': deckController,
  });
  const route = routes.find(route => route.url === '/characters/:id/deck');
  for (const authorization of [undefined, 'Bearer invalid', 'Bearer valid']) {
    const req = { headers: { authorization }, params: { id: 'old' } };
    const res = { statusCode: 200, headers: {}, set(key, value) { this.headers[key] = value; }, status(value) { this.statusCode = value; return this; }, json(value) { this.body = value; return this; } };
    let next = false;
    await route.handlers[0](req, res, () => { next = true; });
    if (next) await route.handlers[1](req, res);
    if (authorization === 'Bearer valid') {
      assert.equal(res.statusCode, 200);
      assert.equal(res.headers['Cache-Control'], 'no-store');
      assert.equal(res.body.deck.cards.length, 9);
      assert.equal(res.body.deck.ultimate.type, 'ultimate');
    } else {
      assert.equal(res.statusCode, 401);
      assert.equal(db.paths('decks').length, 0);
    }
  }
});
