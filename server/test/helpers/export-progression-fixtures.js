// Regenerate Flutter response fixtures using complete battles in the real service.
// No Firebase access: fixture() supplies the transaction-aware in-memory database.
const fs = require('node:fs');
const path = require('node:path');
const { fixture } = require('./battle-fixture');
const { xpForNextLevel } = require('../../src/services/progression.service');

async function main() {
  for (const outcome of ['victory', 'defeat']) {
    const { db, service } = await fixture();
    db.set('characters/hero', { ...db.data('characters/hero'), level: 1, xp: 80, gold: 100, attributePoints: 0 });
    let response = await service.startBattle('user-a', { characterId: 'hero', enemyId: 'goblin' });
    for (let step = 0; step < 160 && response.battle.status === 'active'; step++) {
      const battle = response.battle;
      const playable = battle.cards.filter(card => card.type !== 'ultimate' && battle.playable[card.id].canPlay);
      const card = outcome === 'victory' ? playable.find(card => card.damage) ?? playable[0] : null;
      response = card
        ? await service.command('user-a', battle.id, 'play-card', { expectedVersion: battle.version, cardId: card.id, target: battle.playable[card.id].target })
        : await service.command('user-a', battle.id, 'end-turn', { expectedVersion: battle.version });
    }
    if (response.battle.status !== outcome) throw new Error(`Expected ${outcome}, got ${response.battle.status}`);
    const character = db.data('characters/hero');
    response.character = { ...character, id: 'hero', xpToNextLevel: xpForNextLevel(character.level) };
    fs.writeFileSync(path.join(__dirname, `../../../app/test/fixtures/battle_reward_${outcome}.json`), JSON.stringify(response, null, 2) + '\n');
    console.log(`Generated ${outcome} with ${response.battle.result.rewards.xp} XP and ${response.battle.result.rewards.gold} Gold.`);
  }
}
if (require.main === module) main().catch(error => { console.error(error.message); process.exitCode = 1; });
