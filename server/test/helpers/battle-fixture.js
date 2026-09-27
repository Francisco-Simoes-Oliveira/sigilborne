const FakeFirestore = require('./fake-firestore');
const { seedCards } = require('../../scripts/seedCards');
const { seedEnemies } = require('../../scripts/seedEnemies');
const { createBattleService } = require('../../src/services/battle.service');

async function fixture({ classId = 'warrior', speed = 5 } = {}) {
  const attributes = { hp: 120, strength: 12, magicPower: 3, defense: 12, speed, maxEnergy: 6 };
  const db = new FakeFirestore(Object.fromEntries(['warrior', 'mage', 'rogue', 'hunter'].map(id => [`classes/${id}`, { name: id, baseAttributes: attributes }])));
  await seedCards(db); await seedEnemies(db);
  db.set('characters/hero', { name: 'Kael', ownerId: 'user-a', classId, equippedDeckId: null, attributes });
  const service = createBattleService(db, { choose: max => max - 1 });
  return { db, service, attributes };
}

async function started(options) {
  const context = await fixture(options);
  const response = await context.service.startBattle('user-a', { characterId: 'hero', enemyId: 'goblin' });
  return { ...context, response, id: response.battle.id };
}
module.exports = { fixture, started };
