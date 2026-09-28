const assert = require('node:assert/strict');
const { test } = require('node:test');
const { fixture } = require('./helpers/battle-fixture');
const { cards } = require('../src/data/starter-cards');
const { enemies } = require('../src/data/enemies');
const Engine = require('../src/battle/BattleEngine');
const { calculateDamage } = require('../src/battle/DamageCalculator');
const { multiplier } = require('../src/battle/ElementResolver');

async function ready(classId, enemyId = 'goblin') {
  const context = await fixture({ classId });
  const response = await context.service.startBattle('user-a', { characterId: 'hero', enemyId });
  return { ...context, battle: response.battle, id: response.battle.id };
}
function arrange(context, hand, mutate = () => {}) {
  const battle = context.db.data(`battles/${context.id}`);
  const rest = [...battle.normalCardIds];
  for (const id of hand) rest.splice(rest.indexOf(id), 1);
  battle.player.hand = hand; battle.player.queue = rest;
  mutate(battle);
  context.db.set(`battles/${context.id}`, battle);
  return battle;
}
async function play(context, battle, cardId, ultimate = false) {
  const action = battle.playable[cardId];
  return context.service.command('user-a', context.id, ultimate ? 'play-ultimate' : 'play-card',
    { expectedVersion: battle.version, cardId, target: action.target });
}
const event = (result, type) => result.events.find(item => item.type === type);

test('all four classes and four enemies are selectable; Hunter starts with Wolf', async () => {
  for (const classId of ['warrior', 'mage', 'rogue', 'hunter']) {
    const context = await ready(classId);
    assert.equal(context.battle.classId, classId);
    assert.equal(context.battle.player.hand.length, 3);
    assert.equal(context.battle.player.queue.length, 6);
    assert.equal(!!context.battle.player.pet, classId === 'hunter');
    const selection = await context.service.listEnemies();
    assert.deepEqual(selection.supportedClassIds, ['warrior', 'mage', 'rogue', 'hunter']);
    assert.deepEqual(new Set(selection.enemies.map(enemy => enemy.id)), new Set(Object.keys(enemies)));
    assert.ok(selection.enemies.every(enemy => enemy.rewards.xp > 0 && enemy.rewards.gold > 0));
  }
});

test('all 40 existing descriptors execute without card-id branches', () => {
  for (const card of cards) {
    const classCards = cards.filter(item => item.classId === card.classId);
    const normals = classCards.filter(item => item.type !== 'ultimate');
    const ultimate = classCards.find(item => item.type === 'ultimate');
    const { battle } = Engine.startBattle({ ownerId: 'u', characterId: 'c', character: {
      name: 'Hero', classId: card.classId,
      attributes: { hp: 120, strength: 12, magicPower: 14, defense: 12, speed: 13, maxEnergy: 6 },
    }, enemyId: 'goblin', enemy: enemies.goblin, deck: { id: 'd', cards: normals, ultimate } }, max => max - 1);
    if (card.type === 'ultimate') battle.player.ultimate.charge = 100;
    else if (!battle.player.hand.includes(card.id)) {
      battle.player.hand = [card.id, ...normals.filter(item => item.id !== card.id).slice(0, 2).map(item => item.id)];
      battle.player.queue = normals.map(item => item.id).filter(id => !battle.player.hand.includes(id));
    }
    if (card.id === 'warrior_counter_attack') battle.player.statuses.guard = { remainingTurns: 1, parameters: { damageReduction: 0.5 } };
    const available = Engine.availability(battle, card, card.type === 'ultimate');
    assert.equal(available.canPlay, true, `${card.id}: ${available.reason}`);
    const events = Engine.playCard(battle, card, available.target, card.type === 'ultimate');
    assert.ok(events.some(item => item.type === (card.type === 'ultimate' ? 'ULTIMATE_USED' : 'CARD_USED')), card.id);
  }
});

test('element cycle, Slime exception, neutral and physical ice remain independent', () => {
  assert.equal(multiplier('fire', { element: 'ice' }), 1.25);
  assert.equal(multiplier('ice', { element: 'fire' }), 0.75);
  assert.equal(multiplier('earth', { element: 'electric' }), 1.25);
  assert.equal(multiplier('electric', { element: 'fire' }), 1.25);
  assert.equal(multiplier('neutral', { element: 'fire' }), 1);
  assert.equal(multiplier('ice', enemies.fire_slime), 1.25);
  assert.equal(multiplier('fire', enemies.fire_slime), 0.75);
  const source = { attributes: { strength: 20 } };
  const target = { attributes: { defense: 0 }, element: 'earth', guard: 0, statuses: {} };
  const damage = { scaling: 'strength', multiplier: 1, nature: 'physical', element: 'ice' };
  assert.equal(calculateDamage(source, target, damage).amount, 25);
  assert.equal(damage.nature, 'physical');
});

test('Mage burns, wets, freezes with Ice, and skips exactly one enemy action', async () => {
  const context = await ready('mage', 'fire_slime');
  arrange(context, ['mage_fireball', 'mage_soak', 'mage_ice_lance']);
  let battle = (await context.service.getBattle('user-a', context.id)).battle;
  let result = await play(context, battle, 'mage_fireball'); battle = result.battle;
  assert.ok(battle.enemy.statuses.burn);
  assert.ok(event(result, 'ELEMENT_RESISTED'));
  result = await play(context, battle, 'mage_soak'); battle = result.battle;
  assert.ok(battle.enemy.statuses.wet);
  result = await play(context, battle, 'mage_ice_lance'); battle = result.battle;
  assert.equal(event(result, 'ELEMENT_REACTION').reaction, 'freeze');
  assert.ok(event(result, 'ELEMENT_ADVANTAGE'));
  assert.ok(battle.enemy.statuses.frozen);
  result = await context.service.command('user-a', context.id, 'end-turn', { expectedVersion: battle.version });
  assert.ok(event(result, 'STATUS_TICK'));
  assert.ok(event(result, 'ACTION_SKIPPED'));
  assert.equal(result.battle.enemy.patternIndex, 1);
  assert.equal(result.battle.enemy.statuses.frozen, undefined);
});

test('Mage focus, energy restoration and shield are driven by descriptors', async () => {
  const context = await ready('mage');
  arrange(context, ['mage_focus', 'mage_channel', 'mage_arcane_barrier']);
  let battle = (await context.service.getBattle('user-a', context.id)).battle;
  battle = (await play(context, battle, 'mage_focus')).battle;
  assert.ok(battle.player.statuses.focused);
  battle = (await play(context, battle, 'mage_arcane_barrier')).battle;
  assert.equal(battle.player.statuses.shield.remainingHp, 5);
  let result = await play(context, battle, 'mage_channel'); battle = result.battle;
  assert.equal(event(result, 'ENERGY_RECOVERED').amount, 2);
  result = await context.service.command('user-a', context.id, 'end-turn', { expectedVersion: battle.version });
  assert.ok(event(result, 'SHIELD_ABSORBED'));
});

test('Rogue dodge grants Prepared, Backstab crit consumes it, Poison ticks', async () => {
  const context = await ready('rogue');
  arrange(context, ['rogue_dodge', 'rogue_backstab', 'rogue_poison']);
  let battle = (await context.service.getBattle('user-a', context.id)).battle;
  battle = (await play(context, battle, 'rogue_dodge')).battle;
  let result = await context.service.command('user-a', context.id, 'end-turn', { expectedVersion: battle.version });
  battle = result.battle;
  assert.ok(event(result, 'DODGE'));
  assert.equal(battle.player.hp, 120);
  assert.equal(battle.player.statuses.dodge, undefined);
  assert.ok(battle.player.statuses.prepared);
  result = await play(context, battle, 'rogue_backstab'); battle = result.battle;
  assert.ok(event(result, 'CRITICAL'));
  assert.equal(battle.player.statuses.prepared, undefined);
  battle = (await play(context, battle, 'rogue_poison')).battle;
  result = await context.service.command('user-a', context.id, 'end-turn', { expectedVersion: battle.version });
  assert.ok(result.events.some(item => item.type === 'STATUS_TICK' && item.status === 'poison'));
});

test('Rogue Bleed ticks, weakness and low-HP execution crit are conditional', async () => {
  const context = await ready('rogue');
  arrange(context, ['rogue_deep_cut', 'rogue_exploit_weakness', 'rogue_execute']);
  let battle = (await context.service.getBattle('user-a', context.id)).battle;
  battle = (await play(context, battle, 'rogue_deep_cut')).battle;
  assert.ok(battle.enemy.statuses.bleed);
  let result = await play(context, battle, 'rogue_exploit_weakness'); battle = result.battle;
  assert.ok(event(result, 'CRITICAL'));
  result = await context.service.command('user-a', context.id, 'end-turn', { expectedVersion: battle.version });
  assert.ok(result.events.some(item => item.type === 'STATUS_TICK' && item.status === 'bleed'));
  const saved = context.db.data(`battles/${context.id}`); saved.enemy.hp = 20; saved.player.energy = 6; context.db.set(`battles/${context.id}`, saved);
  battle = (await context.service.getBattle('user-a', context.id)).battle;
  result = await play(context, battle, 'rogue_execute');
  assert.ok(event(result, 'CRITICAL'));
  assert.equal(result.battle.status, 'victory');
  assert.deepEqual(result.battle.result.rewards, enemies.goblin.rewards);
});

test('Hunter marks, crits, commands Wolf and applies Bleed', async () => {
  const context = await ready('hunter');
  arrange(context, ['hunter_marking_shot', 'hunter_precise_shot', 'hunter_command_attack']);
  let battle = (await context.service.getBattle('user-a', context.id)).battle;
  assert.equal(battle.player.pet.name, 'Lobo');
  battle = (await play(context, battle, 'hunter_marking_shot')).battle;
  assert.ok(battle.enemy.statuses.marked);
  let result = await play(context, battle, 'hunter_precise_shot'); battle = result.battle;
  assert.ok(event(result, 'CRITICAL'));
  result = await play(context, battle, 'hunter_command_attack');
  assert.ok(event(result, 'PET_ATTACK'));
  assert.ok(result.battle.enemy.statuses.bleed);
});

test('Hunter trap fires once before enemy attack and Ultimate refreshes Wolf', async () => {
  const context = await ready('hunter');
  arrange(context, ['hunter_hunting_trap', 'hunter_quick_shot', 'hunter_retreat']);
  let battle = (await context.service.getBattle('user-a', context.id)).battle;
  battle = (await play(context, battle, 'hunter_hunting_trap')).battle;
  assert.equal(battle.player.traps.length, 1);
  let result = await context.service.command('user-a', context.id, 'end-turn', { expectedVersion: battle.version });
  assert.ok(event(result, 'TRAP_TRIGGERED'));
  assert.equal(result.battle.player.traps.length, 0);
  assert.ok(result.battle.enemy.statuses.rooted);
  const saved = context.db.data(`battles/${context.id}`); saved.player.energy = 6; saved.player.ultimate.charge = 100; context.db.set(`battles/${context.id}`, saved);
  battle = (await context.service.getBattle('user-a', context.id)).battle;
  result = await play(context, battle, battle.player.ultimate.id, true);
  assert.ok(event(result, 'PET_SUMMONED'));
  assert.equal(result.battle.player.pet.name, 'Lobo Alfa');
  assert.equal(result.battle.player.ultimate.charge, 0);
});

test('Mage and Rogue Ultimates stay separate from the card cycle', async () => {
  for (const classId of ['mage', 'rogue']) {
    const context = await ready(classId);
    const saved = context.db.data(`battles/${context.id}`);
    saved.player.ultimate.charge = 100;
    if (classId === 'rogue') saved.player.statuses.prepared = { remainingTurns: 2, appliedOnTurn: 0, parameters: {} };
    context.db.set(`battles/${context.id}`, saved);
    const before = (await context.service.getBattle('user-a', context.id)).battle;
    const result = await play(context, before, before.player.ultimate.id, true);
    assert.ok(event(result, 'ULTIMATE_USED'));
    assert.deepEqual(result.battle.player.hand, before.player.hand);
    assert.deepEqual(result.battle.player.queue, before.player.queue);
    assert.equal(result.battle.player.ultimate.charge, 0);
    if (classId === 'mage') assert.ok(result.battle.enemy.statuses.frozen);
    else { assert.ok(event(result, 'CRITICAL')); assert.equal(result.battle.player.statuses.prepared, undefined); }
  }
});

test('duplicate Hunter pet command uses expectedVersion and commits one attack', async () => {
  const context = await ready('hunter');
  arrange(context, ['hunter_command_attack', 'hunter_quick_shot', 'hunter_retreat']);
  const battle = (await context.service.getBattle('user-a', context.id)).battle;
  const results = await Promise.allSettled(Array.from({ length: 4 }, () => play(context, battle, 'hunter_command_attack')));
  assert.equal(results.filter(item => item.status === 'fulfilled').length, 1);
  assert.ok(results.filter(item => item.status === 'rejected').every(item => item.reason.code === 'STALE_BATTLE'));
  const stored = context.db.data(`battles/${context.id}`);
  assert.equal(stored.version, 2);
  assert.equal(stored.enemy.statuses.bleed.stacks, 1);
  assert.equal(stored.recentEvents.filter(item => item.type === 'PET_ATTACK').length, 1);
});

test('old battle documents without new fields remain readable and actionable', async () => {
  const context = await ready('warrior');
  const saved = context.db.data(`battles/${context.id}`);
  delete saved.player.pet; delete saved.player.traps; delete saved.player.elementModifiers;
  delete saved.enemy.element; delete saved.enemy.elementModifiers;
  context.db.set(`battles/${context.id}`, saved);
  assert.equal((await context.service.getBattle('user-a', context.id)).battle.id, context.id);
  const next = await context.service.command('user-a', context.id, 'end-turn', { expectedVersion: 1 });
  assert.equal(next.battle.version, 2);
});
