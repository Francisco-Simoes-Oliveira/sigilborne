const GameError = require('../domain/game-error');

function integer(value, minimum = 0) {
  if (!Number.isSafeInteger(value) || value < minimum) {
    throw new GameError('INVALID_PROGRESSION', 409, 'Os dados de progressão do personagem estão inválidos.');
  }
  return value;
}

function xpForNextLevel(level) {
  return integer(100 + (integer(level, 1) - 1) * 50, 1);
}

function characterProgression(character) {
  return {
    level: integer(character.level ?? 1, 1),
    xp: integer(character.xp ?? 0),
    attributePoints: integer(character.attributePoints ?? 0),
    gold: integer(character.gold ?? 0),
  };
}

function applyProgression(character, rewards) {
  const before = characterProgression(character);
  let level = before.level;
  let xp = integer(before.xp + integer(rewards.xp));
  const gold = integer(before.gold + integer(rewards.gold));
  // XP is the remainder inside the current level, never lifetime XP.
  while (xp >= xpForNextLevel(level)) {
    xp -= xpForNextLevel(level);
    level = integer(level + 1, 1);
  }
  const attributePointsGained = integer((level - before.level) * 2);
  return {
    updates: { level, xp, gold, attributePoints: integer(before.attributePoints + attributePointsGained) },
    progression: {
      levelBefore: before.level, levelAfter: level,
      xpBefore: before.xp, xpAfter: xp, xpToNextLevel: xpForNextLevel(level),
      goldBefore: before.gold, goldAfter: gold,
      attributePointsBefore: before.attributePoints,
      attributePointsAfter: before.attributePoints + attributePointsGained,
      attributePointsGained, leveledUp: level > before.level,
    },
  };
}

module.exports = { xpForNextLevel, characterProgression, applyProgression };
