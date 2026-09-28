const assert = require('node:assert/strict');
const { test } = require('node:test');
const { fixture, started } = require('./helpers/battle-fixture');
const FakeFirestore = require('./helpers/fake-firestore');
const load = require('./helpers/load-module');
const { seedEnemies } = require('../scripts/seedEnemies');
const { startCycle, rotate } = require('../src/battle/CardCycle');
const { calculateDamage } = require('../src/battle/DamageCalculator');
const Engine = require('../src/battle/BattleEngine');
const { cards } = require('../src/data/starter-cards');
const errorCode = value => error => error.code === value;

function arrange(db, id, hand, updates = {}) {
  const battle = db.data(`battles/${id}`);
  const rest = [...battle.normalCardIds];
  for (const card of hand) rest.splice(rest.indexOf(card), 1);
  battle.player.hand = hand;
  battle.player.queue = rest;
  Object.assign(battle.player, updates);
  db.set(`battles/${id}`, battle);
  return battle;
}

test('enemy seed supports dry data, repeat and conflict without overwrite', async () => {
  const db = new FakeFirestore();
  assert.deepEqual(await seedEnemies(db), { created: 4, updated: 0, unchanged: 0 });
  assert.deepEqual(await seedEnemies(db), { created: 0, updated: 0, unchanged: 4 });
  db.set('enemies/goblin', { name: 'Custom Goblin' });
  await assert.rejects(seedEnemies(db), /dados diferentes/);
  assert.equal(db.data('enemies/goblin').name, 'Custom Goblin');
});

test('start creates a full snapshot, 3+6 cycle, separate Ultimate, and recovers a legacy deck', async () => {
  const { db, response, id } = await started();
  const battle = response.battle;
  assert.equal(battle.player.hand.length, 3);
  assert.equal(battle.player.queue.length, 6);
  assert.equal(battle.player.energy, 6);
  assert.equal(battle.player.ultimate.charge, 0);
  assert.equal(battle.currentActor, 'player');
  assert.equal(battle.turn, 1);
  assert.equal(battle.version, 1);
  assert.equal(battle.enemy.hp, 80);
  assert.ok(response.events.some(event => event.type === 'BATTLE_STARTED'));
  const stored = db.data(`battles/${id}`);
  assert.equal(stored.cards, undefined);
  assert.equal(stored.playable, undefined);
  assert.equal(stored.player.hand.includes(stored.player.ultimate.id), false);
  assert.ok(db.data('characters/hero').equippedDeckId);
  assert.equal(db.data('characters/hero').lastBattleId, id);
  assert.deepEqual(db.data(`decks/${battle.deckId}`).cards, stored.normalCardIds);
});

test('enemies can be selected, latest fight can be reopened, and faster enemy acts first', async () => {
  const { service, response } = await started({ speed: 1 });
  assert.equal((await service.listEnemies()).enemies[0].id, 'goblin');
  assert.equal(response.battle.player.hp, 115);
  assert.equal(response.battle.enemy.patternIndex, 1);
  assert.equal(response.battle.currentActor, 'player');
  assert.equal((await service.latestBattle('user-a', 'hero')).battle.id, response.battle.id);
});

test('foreign character/battle are blocked and mage can start', async () => {
  const { db, service, id } = await started();
  await assert.rejects(service.startBattle('user-b', { characterId: 'hero', enemyId: 'goblin' }), error => error.status === 403);
  await assert.rejects(service.getBattle('user-b', id), error => error.status === 403);
  await assert.rejects(service.latestBattle('user-b', 'hero'), error => error.status === 403);
  await assert.rejects(service.command('user-b', id, 'end-turn', { expectedVersion: 1 }), error => error.status === 403);
  await assert.rejects(service.getBattle('user-a', 'absent'), error => error.status === 404);
  assert.equal(db.data(`battles/${id}`).version, 1);
  const mage = await fixture({ classId: 'mage' });
  const mageBattle = await mage.service.startBattle('user-a', { characterId: 'hero', enemyId: 'goblin' });
  assert.equal(mageBattle.battle.classId, 'mage');
  assert.equal(mage.db.paths('battles').length, 1);
});

test('missing enemy and invalid deck cannot start a battle', async () => {
  const { db, service } = await fixture();
  await assert.rejects(service.startBattle('user-a', { characterId: 'hero', enemyId: 'missing' }), errorCode('ENEMY_NOT_FOUND'));
  db.records.delete('cards/warrior_slash');
  await assert.rejects(service.startBattle('user-a', { characterId: 'hero', enemyId: 'goblin' }), errorCode('INVALID_CARD_CATALOG'));
  assert.equal(db.paths('battles').length, 0);
});

test('playing a normal card spends energy, damages, rotates exactly once, and charges Ultimate', async () => {
  const { db, service, response, id } = await started();
  const before = response.battle;
  const result = await service.command('user-a', id, 'play-card', { expectedVersion: 1, cardId: 'warrior_slash', target: 'enemy', damage: 99999, energy: 9999 });
  assert.equal(result.battle.player.energy, 5);
  assert.equal(result.battle.enemy.hp, 70);
  assert.deepEqual(result.battle.player.hand, [...before.player.hand.slice(1), before.player.queue[0]]);
  assert.deepEqual(result.battle.player.queue, [...before.player.queue.slice(1), 'warrior_slash']);
  assert.equal(result.battle.player.ultimate.charge, 25);
  assert.equal(result.battle.version, 2);
  assert.ok(result.events.some(event => event.type === 'DAMAGE' && event.amount === 10));
  assert.deepEqual(db.data(`decks/${before.deckId}`).cards, before.normalCardIds);
});

test('cycle handles duplicate copies, preserves counts and does not shuffle again', () => {
  const ids = ['a', 'a', 'a', 'b', 'c', 'd', 'e', 'f', 'g'];
  let calls = 0;
  const player = startCycle(ids, max => { calls++; return max - 1; });
  for (let step = 0; step < 30; step++) {
    rotate(player, player.hand[0]);
    assert.equal(player.hand.length, 3); assert.equal(player.queue.length, 6);
    assert.deepEqual([...player.hand, ...player.queue].sort(), [...ids].sort());
  }
  assert.equal(calls, 8);
});

test('invalid card, target, requirement, actor, energy and missing version cannot mutate state', async () => {
  const { db, service, id } = await started();
  const cases = [
    [{ expectedVersion: 1, cardId: 'warrior_charge', target: 'enemy' }, 'CARD_NOT_IN_HAND'],
    [{ expectedVersion: 1, cardId: 'warrior_slash', target: 'self' }, 'INVALID_TARGET'],
    [{ cardId: 'warrior_slash', target: 'enemy' }, 'VERSION_REQUIRED'],
  ];
  for (const [body, code] of cases) await assert.rejects(service.command('user-a', id, 'play-card', body), errorCode(code));
  arrange(db, id, ['warrior_counter_attack', 'warrior_slash', 'warrior_block']);
  await assert.rejects(service.command('user-a', id, 'play-card', { expectedVersion: 1, cardId: 'warrior_counter_attack', target: 'enemy' }), errorCode('REQUIREMENTS_NOT_MET'));
  const b = db.data(`battles/${id}`); b.player.energy = 0; db.set(`battles/${id}`, b);
  await assert.rejects(service.command('user-a', id, 'play-card', { expectedVersion: 1, cardId: 'warrior_slash', target: 'enemy' }), errorCode('NOT_ENOUGH_ENERGY'));
  b.currentActor = 'enemy'; db.set(`battles/${id}`, b);
  await assert.rejects(service.command('user-a', id, 'end-turn', { expectedVersion: 1 }), errorCode('NOT_PLAYER_TURN'));
  assert.equal(db.data(`battles/${id}`).version, 1);
});

test('end turn runs normal/normal/heavy pattern and restores only 3 energy with a cap', async () => {
  const { db, service, id } = await started();
  const original = db.data(`battles/${id}`); original.player.energy = 1; db.set(`battles/${id}`, original);
  const damages = [];
  for (let version = 1; version <= 3; version++) {
    const result = await service.command('user-a', id, 'end-turn', { expectedVersion: version });
    damages.push(result.events.find(event => event.type === 'DAMAGE').amount);
    assert.equal(result.battle.turn, version + 1);
    assert.equal(result.battle.player.energy, version === 1 ? 4 : 6);
    assert.equal(result.battle.currentActor, 'player');
  }
  assert.deepEqual(damages, [5, 5, 9]);
  assert.equal(db.data(`battles/${id}`).enemy.patternIndex, 0);
});

test('guard survives the enemy reply, enables counter critical, and expires on the next player end', async () => {
  const { db, service, id } = await started();
  arrange(db, id, ['warrior_block', 'warrior_counter_attack', 'warrior_slash']);
  let r = await service.command('user-a', id, 'play-card', { expectedVersion: 1, cardId: 'warrior_block', target: 'self' });
  r = await service.command('user-a', id, 'end-turn', { expectedVersion: r.battle.version });
  assert.equal(r.battle.player.hp, 117);
  assert.ok(r.battle.player.statuses.guard);
  r = await service.command('user-a', id, 'play-card', { expectedVersion: r.battle.version, cardId: 'warrior_counter_attack', target: 'enemy' });
  assert.ok(r.events.some(event => event.type === 'CRITICAL'));
  r = await service.command('user-a', id, 'end-turn', { expectedVersion: r.battle.version });
  assert.equal(r.battle.player.guard, 0);
  assert.equal(r.battle.player.hp, 112);
});

test('shield-bash stun skips exactly one enemy opportunity; heal caps at maximum', async () => {
  const { db, service, id } = await started();
  arrange(db, id, ['warrior_block', 'warrior_shield_bash', 'warrior_second_wind'], { hp: 115 });
  let r = await service.command('user-a', id, 'play-card', { expectedVersion: 1, cardId: 'warrior_block', target: 'self' });
  r = await service.command('user-a', id, 'play-card', { expectedVersion: r.battle.version, cardId: 'warrior_shield_bash', target: 'enemy' });
  r = await service.command('user-a', id, 'play-card', { expectedVersion: r.battle.version, cardId: 'warrior_second_wind', target: 'self' });
  assert.equal(r.battle.player.hp, 120);
  assert.equal(r.events.find(event => event.type === 'HEAL').amount, 5);
  r = await service.command('user-a', id, 'end-turn', { expectedVersion: r.battle.version });
  assert.ok(r.events.some(event => event.type === 'ACTION_SKIPPED'));
  assert.equal(r.battle.enemy.statuses.stunned, undefined);
  r = await service.command('user-a', id, 'end-turn', { expectedVersion: r.battle.version });
  assert.ok(r.events.some(event => event.type === 'ENEMY_ACTION'));
});

test('charged warrior Ultimate spends energy without entering the cycle and counterattacks', async () => {
  const { db, service, id } = await started();
  await assert.rejects(service.command('user-a', id, 'play-ultimate', { expectedVersion: 1, target: 'self' }), errorCode('ULTIMATE_NOT_READY'));
  const original = db.data(`battles/${id}`); original.player.ultimate.charge = 100; db.set(`battles/${id}`, original);
  let r = await service.command('user-a', id, 'play-ultimate', { expectedVersion: 1, target: 'self' });
  assert.deepEqual(r.battle.player.hand, original.player.hand);
  assert.deepEqual(r.battle.player.queue, original.player.queue);
  assert.equal(r.battle.player.ultimate.charge, 0);
  assert.equal(r.battle.player.energy, 0);
  r = await service.command('user-a', id, 'end-turn', { expectedVersion: 2 });
  assert.ok(r.events.some(event => event.type === 'COUNTER_ATTACK'));
  assert.equal(r.battle.player.hp, 119);
  assert.ok(r.battle.enemy.hp < 80);
});

test('damage scales physical/magical, critical and defense without negative values', () => {
  const source = { attributes: { strength: 12, magicPower: 20 } };
  const target = { attributes: { defense: 5 }, guard: 0, statuses: {} };
  assert.equal(calculateDamage(source, target, { scaling: 'strength', multiplier: 1, element: 'neutral' }).amount, 10);
  assert.equal(calculateDamage(source, target, { scaling: 'magicPower', multiplier: 1, element: 'fire' }, { criticalMultiplier: 1.5 }).amount, 24);
  target.attributes.defense = 1e6;
  assert.ok(calculateDamage(source, target, { scaling: 'strength', multiplier: 1, element: 'neutral' }).amount >= 0);
});

test('concurrent play/end commands with one version accept only one and reject stale retries', async () => {
  for (const action of ['play-card', 'end-turn']) {
    const { db, service, id } = await started();
    const command = { expectedVersion: 1, cardId: 'warrior_slash', target: 'enemy' };
    const results = await Promise.allSettled(Array.from({ length: 5 }, () => service.command('user-a', id, action, command)));
    assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
    assert.ok(results.filter(result => result.status === 'rejected').every(result => result.reason.code === 'STALE_BATTLE'));
    const stored = db.data(`battles/${id}`);
    assert.equal(stored.version, 2);
    assert.equal(stored.player.energy, action === 'play-card' ? 5 : 6);
    assert.equal(stored.turn, action === 'play-card' ? 1 : 2);
  }
});

test('concurrent starts resume a single active fight instead of creating duplicates', async () => {
  const { db, service } = await fixture();
  const results = await Promise.all(Array.from({ length: 5 }, () => service.startBattle('user-a', { characterId: 'hero', enemyId: 'goblin' })));
  assert.equal(new Set(results.map(result => result.battle.id)).size, 1);
  assert.equal(db.paths('battles').length, 1);
});

test('battle attributes stay snapshotted and catalog changes block actions but preserve readback', async () => {
  const { db, service, id } = await started();
  db.set('characters/hero', { ...db.data('characters/hero'), attributes: { hp: 99999, strength: 99999 } });
  let r = await service.command('user-a', id, 'play-card', { expectedVersion: 1, cardId: 'warrior_slash', target: 'enemy' });
  assert.equal(r.battle.enemy.hp, 70);
  assert.equal(r.battle.player.maxHp, 120);
  db.set('cards/warrior_slash', { ...db.data('cards/warrior_slash'), cost: 0 });
  await assert.rejects(service.command('user-a', id, 'end-turn', { expectedVersion: 2 }), errorCode('CATALOG_CHANGED'));
  r = await service.getBattle('user-a', id);
  assert.equal(r.battle.catalogChanged, true);
  assert.equal(r.battle.canEndTurn, false);
  assert.equal(r.battle.version, 2);
  db.set('cards/warrior_slash', { cost: 'invalid' });
  r = await service.getBattle('user-a', id);
  const placeholder = r.battle.cards.find(card => card.id === 'warrior_slash');
  assert.equal(placeholder.name, 'Carta indisponível');
  assert.equal(placeholder.cost, 0);
  assert.equal(r.battle.playable.warrior_slash.canPlay, false);
});

for (const outcome of ['victory', 'defeat']) {
  test(`full playable battle reaches ${outcome}, persists it and rejects further actions`, async () => {
    const { db, service, response, id } = await started();
    let battle = response.battle;
    for (let step = 0; step < 160 && battle.status === 'active'; step++) {
      const card = outcome === 'victory' ? battle.cards.find(card => battle.playable[card.id].canPlay && card.type !== 'ultimate' && card.damage) : null;
      const result = card
        ? await service.command('user-a', id, 'play-card', { expectedVersion: battle.version, cardId: card.id, target: battle.playable[card.id].target })
        : await service.command('user-a', id, 'end-turn', { expectedVersion: battle.version });
      battle = result.battle;
      if (outcome === 'victory' && !card && battle.status === 'active') {
        const rotateCard = battle.cards.find(card => card.type !== 'ultimate' && battle.playable[card.id].canPlay);
        if (rotateCard) battle = (await service.command('user-a', id, 'play-card', { expectedVersion: battle.version, cardId: rotateCard.id, target: battle.playable[rotateCard.id].target })).battle;
      }
    }
    assert.equal(battle.status, outcome);
    assert.equal(battle[outcome === 'victory' ? 'enemy' : 'player'].hp, 0);
    assert.equal((await service.getBattle('user-a', id)).battle.status, outcome);
    assert.equal((await service.latestBattle('user-a', 'hero')).battle.status, outcome);
    assert.ok(battle.recentEvents.some(event => event.type === outcome.toUpperCase()));
    assert.ok(battle.recentEvents.length <= 40);
    await assert.rejects(service.command('user-a', id, 'end-turn', { expectedVersion: battle.version }), errorCode('BATTLE_FINISHED'));
    assert.equal(db.data('characters/hero').attributes.hp, 120);
  });
}

test('all battle routes require actual authentication and ignore client HP, damage and owner', async () => {
  const { db } = await fixture();
  const controller = load('src/controllers/battle.controller.js', { '../config/firebase': { db } });
  const authenticate = load('src/middleware/auth.middleware.js', { '../config/firebase': { auth: { async verifyIdToken(token) { if (token !== 'valid') throw new Error('invalid'); return { uid: 'user-a' }; } } } });
  const routes = [];
  load('src/routes/battle.routes.js', {
    express: { Router: () => ({ get: (url, ...handlers) => routes.push({ method: 'GET', url, handlers }), post: (url, ...handlers) => routes.push({ method: 'POST', url, handlers }) }) },
    '../middleware/auth.middleware': authenticate, '../controllers/battle.controller': controller,
  });
  assert.equal(routes.length, 7);
  assert.ok(routes.every(route => route.handlers[0] === authenticate));
  for (const token of [undefined, 'Bearer bad', 'Bearer valid']) {
    const req = { headers: { authorization: token }, body: { characterId: 'hero', enemyId: 'goblin', ownerId: 'user-b', hp: 99999, energy: 99999 } };
    const res = { statusCode: 200, set() {}, status(code) { this.statusCode = code; return this; }, json(data) { this.body = data; return this; } };
    let next = false;
    await authenticate(req, res, () => { next = true; });
    if (next) await controller.start(req, res);
    if (token === 'Bearer valid') { assert.equal(res.statusCode, 201); assert.equal(res.body.battle.ownerId, 'user-a'); assert.equal(res.body.battle.player.hp, 120); }
    else assert.equal(res.statusCode, 401);
  }
});
