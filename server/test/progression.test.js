const assert = require('node:assert/strict');
const { test } = require('node:test');
const { fixture, started } = require('./helpers/battle-fixture');
const FakeFirestore = require('./helpers/fake-firestore');
const load = require('./helpers/load-module');
const { applyProgression, xpForNextLevel } = require('../src/services/progression.service');
const { validateEnemy } = require('../src/domain/enemy-schema');
const { enemies, legacyEnemies } = require('../src/data/enemies');
const { seedEnemies } = require('../scripts/seedEnemies');

async function ready(outcome = 'victory', progression = { level: 1, xp: 80, gold: 100, attributePoints: 3 }) {
  const context = await started();
  const { db, id } = context;
  db.set('characters/hero', { ...db.data('characters/hero'), ...progression });
  const battle = db.data(`battles/${id}`);
  battle[outcome === 'victory' ? 'enemy' : 'player'].hp = 1;
  db.set(`battles/${id}`, battle);
  return context;
}
const win = ({ service, id }) => service.command('user-a', id, 'play-card', { expectedVersion: 1, cardId: 'warrior_slash', target: 'enemy' });
const lose = ({ service, id }) => service.command('user-a', id, 'end-turn', { expectedVersion: 1 });

test('XP thresholds and overflow grant +2 points per level without changing attributes', () => {
  assert.deepEqual([1, 2, 3, 4].map(xpForNextLevel), [100, 150, 200, 250]);
  const character = { level: 1, xp: 80, attributePoints: 3, gold: 100, attributes: { hp: 120, maxEnergy: 6 } };
  const single = applyProgression(character, { xp: 40, gold: 25 });
  assert.deepEqual(single.updates, { level: 2, xp: 20, attributePoints: 5, gold: 125 });
  assert.equal(single.progression.attributePointsGained, 2);
  assert.equal(single.progression.leveledUp, true);
  const multiple = applyProgression(character, { xp: 500, gold: 25 });
  assert.deepEqual(multiple.updates, { level: 4, xp: 130, attributePoints: 9, gold: 125 });
  assert.equal(multiple.progression.attributePointsGained, 6);
  assert.deepEqual(character.attributes, { hp: 120, maxEnergy: 6 });
  assert.equal(character.xp, 80);
});

test('exact threshold advances once; small rewards retain XP inside the same level', () => {
  assert.deepEqual(applyProgression({ level: 2, xp: 110 }, { xp: 40, gold: 0 }).updates,
    { level: 3, xp: 0, gold: 0, attributePoints: 2 });
  const unchanged = applyProgression({ level: 1, xp: 0 }, { xp: 40, gold: 25 });
  assert.equal(unchanged.progression.leveledUp, false);
  assert.equal(unchanged.updates.xp, 40);
});

test('victory atomically adds XP/gold, levels up and persists an immutable result', async () => {
  const context = await ready();
  const { db, service, id } = context;
  const before = db.data('characters/hero');
  const result = (await win(context)).battle.result;
  const character = db.data('characters/hero');
  assert.deepEqual({ level: character.level, xp: character.xp, gold: character.gold, points: character.attributePoints },
    { level: 2, xp: 20, gold: 125, points: 5 });
  assert.deepEqual(character.attributes, before.attributes);
  assert.equal(character.equippedDeckId, before.equippedDeckId);
  assert.deepEqual(result.rewards, { xp: 40, gold: 25 });
  assert.equal(result.rewardsApplied, true);
  assert.equal(result.progression.levelBefore, 1);
  assert.equal(result.progression.levelAfter, 2);
  assert.equal(result.progression.xpBefore, 80);
  assert.equal(result.progression.xpAfter, 20);
  assert.equal(result.progression.attributePointsGained, 2);
  assert.equal(result.progression.xpToNextLevel, 150);
  assert.ok(result.appliedAt instanceof Date);
  const commits = db.commits;
  assert.deepEqual((await service.getBattle('user-a', id)).battle.result, result);
  assert.deepEqual((await service.latestBattle('user-a', 'hero')).battle.result, result);
  assert.equal(db.commits, commits, 'GETs must not write');
});

test('defeat records zero rewards and leaves all character progression unchanged', async () => {
  const context = await ready('defeat');
  const before = context.db.data('characters/hero');
  const { battle } = await lose(context);
  assert.equal(battle.status, 'defeat');
  assert.deepEqual(battle.result.rewards, { xp: 0, gold: 0 });
  assert.equal(battle.result.rewardsApplied, true);
  assert.equal(battle.result.progression.leveledUp, false);
  assert.deepEqual(context.db.data('characters/hero'), before);
});

test('characters without gold receive the first balance starting from zero', async () => {
  const context = await ready('victory', { level: 1, xp: 0, attributePoints: 0 });
  assert.equal(context.db.data('characters/hero').gold, undefined);
  const result = (await win(context)).battle.result;
  assert.equal(context.db.data('characters/hero').gold, 25);
  assert.equal(result.progression.goldBefore, 0);
  assert.equal(result.progression.goldAfter, 25);
});

test('enemy reward changes after start cannot change the battle reward snapshot', async () => {
  const context = await ready();
  context.db.set('enemies/goblin', { ...context.db.data('enemies/goblin'), rewards: { xp: 9999, gold: 9999 } });
  const { battle } = await win(context);
  assert.deepEqual(battle.rewards, { xp: 40, gold: 25 });
  assert.deepEqual(battle.result.rewards, { xp: 40, gold: 25 });
});

test('retries, repeated final requests and repeated reads never apply rewards twice', async () => {
  const context = await ready();
  await win(context);
  const before = context.db.data('characters/hero');
  await assert.rejects(win(context), error => error.code === 'STALE_BATTLE');
  await assert.rejects(context.service.command('user-a', context.id, 'end-turn', { expectedVersion: 2 }), error => error.code === 'BATTLE_FINISHED');
  for (let i = 0; i < 3; i++) await context.service.getBattle('user-a', context.id);
  assert.deepEqual(context.db.data('characters/hero'), before);
});

test('simultaneous winning commands commit one result and one reward', async () => {
  const context = await ready();
  const results = await Promise.allSettled(Array.from({ length: 6 }, () => win(context)));
  assert.equal(results.filter(result => result.status === 'fulfilled').length, 1);
  assert.ok(results.filter(result => result.status === 'rejected').every(result => result.reason.code === 'STALE_BATTLE'));
  assert.equal(context.db.data('characters/hero').gold, 125);
  assert.equal(context.db.data('characters/hero').xp, 20);
  assert.equal(context.db.data(`battles/${context.id}`).version, 2);
  assert.ok(context.db.retries > 0);
});

test('different battles finishing for the same character do not lose concurrent rewards', async () => {
  const context = await ready('victory', { level: 1, xp: 0, gold: 10, attributePoints: 0 });
  // Old deployments can contain multiple active documents; their shared balance must serialize too.
  context.db.set('battles/second', context.db.data(`battles/${context.id}`));
  await Promise.all([win(context), win({ ...context, id: 'second' })]);
  assert.equal(context.db.data('characters/hero').gold, 60);
  assert.equal(context.db.data('characters/hero').xp, 80);
});

test('a newly created battle after a victory grants its own reward exactly once', async () => {
  const context = await ready('victory', { level: 1, xp: 0, gold: 0, attributePoints: 0 });
  await win(context);
  const { battle } = await context.service.startBattle('user-a', { characterId: 'hero', enemyId: 'goblin' });
  assert.notEqual(battle.id, context.id);
  const stored = context.db.data(`battles/${battle.id}`);
  stored.enemy.hp = 1;
  context.db.set(`battles/${battle.id}`, stored);
  await win({ ...context, id: battle.id });
  assert.equal(context.db.data('characters/hero').gold, 50);
  assert.equal(context.db.data('characters/hero').xp, 80);
});

test('historical victory/defeat without rewards stay readable without any writes', async () => {
  for (const status of ['victory', 'defeat']) {
    const { db, service, id } = await started();
    const battle = db.data(`battles/${id}`);
    delete battle.rewards; delete battle.result;
    battle.status = status; battle.currentActor = 'none';
    db.set(`battles/${id}`, battle);
    const before = db.data('characters/hero');
    const commits = db.commits;
    assert.equal((await service.getBattle('user-a', id)).battle.result, undefined);
    assert.equal((await service.latestBattle('user-a', 'hero')).battle.status, status);
    await assert.rejects(service.command('user-a', id, 'end-turn', { expectedVersion: 1 }), error => error.code === 'BATTLE_FINISHED');
    assert.deepEqual(db.data('characters/hero'), before);
    assert.equal(db.commits, commits);
  }
});

test('old active battles without a reward snapshot finish with zero, without consulting current enemy rewards', async () => {
  const context = await ready();
  const battle = context.db.data(`battles/${context.id}`);
  delete battle.rewards; delete battle.result;
  context.db.set(`battles/${context.id}`, battle);
  const before = context.db.data('characters/hero');
  const result = (await win(context)).battle.result;
  assert.equal(result.legacy, true);
  assert.deepEqual(result.rewards, { xp: 0, gold: 0 });
  assert.deepEqual(context.db.data('characters/hero'), before);
});

test('reward validation or character ownership failure aborts the entire final action', async () => {
  for (const patch of [{ gold: -1 }, { ownerId: 'user-b' }]) {
    const context = await ready();
    context.db.set('characters/hero', { ...context.db.data('characters/hero'), ...patch });
    const original = context.db.data(`battles/${context.id}`);
    await assert.rejects(win(context), error => ['INVALID_PROGRESSION', 'FORBIDDEN'].includes(error.code));
    assert.deepEqual(context.db.data(`battles/${context.id}`), original);
  }
  const context = await ready();
  await assert.rejects(context.service.command('user-b', context.id, 'play-card', { expectedVersion: 1, cardId: 'warrior_slash', target: 'enemy' }), error => error.status === 403);
  assert.equal(context.db.data('characters/hero').gold, 100);
});

test('end-turn counterattack victory and faster-enemy initial defeat both persist results', async () => {
  const context = await ready();
  const battle = context.db.data(`battles/${context.id}`);
  battle.player.statuses.counterStance = { remainingTurns: 2, appliedOnTurn: 1, parameters: { damage: { scaling: 'strength', multiplier: 1, nature: 'physical', element: 'neutral', hits: 1 } } };
  context.db.set(`battles/${context.id}`, battle);
  assert.deepEqual((await lose(context)).battle.result.rewards, { xp: 40, gold: 25 });
  const fast = await fixture({ speed: 1 });
  fast.db.set('characters/hero', { ...fast.db.data('characters/hero'), attributes: { ...fast.attributes, hp: 1 } });
  const initial = await fast.service.startBattle('user-a', { characterId: 'hero', enemyId: 'goblin' });
  assert.equal(initial.battle.status, 'defeat');
  assert.deepEqual(initial.battle.result.rewards, { xp: 0, gold: 0 });
});

test('controller ignores XP, gold and reward values supplied by Flutter', async () => {
  const context = await ready();
  const controller = load('src/controllers/battle.controller.js', { '../config/firebase': { db: context.db } });
  const res = { set() {}, status(value) { this.statusCode = value; return this; }, json(value) { this.body = value; } };
  await controller.play({ user: { uid: 'user-a' }, params: { id: context.id }, body: { expectedVersion: 1, cardId: 'warrior_slash', target: 'enemy', ownerId: 'user-b', rewards: { xp: 999, gold: 999 }, gold: 999 } }, res);
  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.battle.result.rewards, { xp: 40, gold: 25 });
});

test('seed previews and explicitly migrates only the exact known v1 Goblin', async () => {
  const db = new FakeFirestore({ 'enemies/goblin': legacyEnemies.goblin });
  await assert.rejects(seedEnemies(db), /--migrate-rewards/);
  assert.deepEqual(await seedEnemies(db, { migrateRewards: true, check: true }), { wouldCreate: 3, wouldUpdate: 1, unchanged: 0 });
  assert.equal(db.commits, 0);
  assert.deepEqual(db.data('enemies/goblin'), legacyEnemies.goblin);
  assert.deepEqual(await seedEnemies(db, { migrateRewards: true }), { created: 3, updated: 1, unchanged: 0 });
  assert.deepEqual(db.data('enemies/goblin'), enemies.goblin);
  assert.deepEqual(await seedEnemies(db, { migrateRewards: true }), { created: 0, updated: 0, unchanged: 4 });
});

test('seed refuses divergent legacy or modern documents even with migration enabled', async () => {
  for (const enemy of [
    { ...legacyEnemies.goblin, name: 'Custom Goblin' },
    { ...legacyEnemies.goblin, extra: 'keep me' },
    { ...enemies.goblin, rewards: { xp: 90, gold: 10 } },
  ]) {
    const db = new FakeFirestore({ 'enemies/goblin': enemy });
    await assert.rejects(seedEnemies(db, { migrateRewards: true }), /dados diferentes/);
    assert.deepEqual(db.data('enemies/goblin'), enemy);
    assert.equal(db.commits, 0);
  }
});

test('new seed preview has no writes and enemy reward schema rejects invalid amounts', async () => {
  const db = new FakeFirestore();
  assert.deepEqual(await seedEnemies(db, { check: true }), { wouldCreate: 4, wouldUpdate: 0, unchanged: 0 });
  assert.equal(db.paths('enemies').length, 0);
  for (const rewards of [null, { xp: -1, gold: 25 }, { xp: 1.5, gold: 0 }, { xp: 40, gold: Infinity }]) {
    assert.throws(() => validateEnemy({ ...enemies.goblin, rewards }), error => error.code === 'INVALID_REWARDS');
  }
});

test('v1 enemies can still be listed but new battles require the reward migration', async () => {
  const context = await fixture();
  context.db.set('enemies/goblin', legacyEnemies.goblin);
  assert.equal((await context.service.listEnemies()).enemies[0].id, 'goblin');
  await assert.rejects(context.service.startBattle('user-a', { characterId: 'hero', enemyId: 'goblin' }), error => error.code === 'ENEMY_REWARDS_MISSING');
  assert.equal(context.db.paths('battles').length, 0);
});
