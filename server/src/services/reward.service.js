const { validateRewards } = require('../domain/enemy-schema');
const { applyProgression, characterProgression, xpForNextLevel } = require('./progression.service');

// Pure calculation. The caller commits the character and battle together.
// Never called by GET: historical results cannot issue new rewards.
function finalizeRewards(battle, character, appliedAt) {
  if (battle.status === 'active' || battle.result?.rewardsApplied === true) return null;
  const legacy = battle.rewards == null;
  if (!legacy) validateRewards(battle.rewards);
  const rewards = battle.status === 'victory' && !legacy
    ? { ...battle.rewards } : { xp: 0, gold: 0 };
  const before = characterProgression(character);
  // Defeat and old in-flight battles cannot even normalize stored progression.
  const calculation = battle.status === 'victory' && !legacy
    ? applyProgression(character, rewards)
    : {
      updates: null,
      progression: {
        levelBefore: before.level, levelAfter: before.level,
        xpBefore: before.xp, xpAfter: before.xp, xpToNextLevel: xpForNextLevel(before.level),
        goldBefore: before.gold, goldAfter: before.gold,
        attributePointsBefore: before.attributePoints, attributePointsAfter: before.attributePoints,
        attributePointsGained: 0, leveledUp: false,
      },
    };
  return {
    characterUpdates: calculation.updates,
    result: { rewardsApplied: true, legacy, rewards, progression: calculation.progression, appliedAt },
  };
}

module.exports = { finalizeRewards };
