// Frozen migration baseline: keep this v1 definition unchanged in future seeds.
const legacyEnemies = {
  goblin: {
    schemaVersion: 1,
    name: 'Goblin',
    description: 'Dois ataques rápidos, seguidos de um golpe pesado. O padrão se repete.',
    attributes: { hp: 80, strength: 8, magicPower: 0, defense: 5, speed: 4, maxEnergy: 0 },
    behavior: {
      type: 'pattern',
      actions: ['basic_attack', 'basic_attack', 'heavy_attack'],
      definitions: {
        basic_attack: { name: 'Ataque normal', damage: { scaling: 'strength', multiplier: 1, nature: 'physical', element: 'neutral', hits: 1 } },
        heavy_attack: { name: 'Ataque pesado', damage: { scaling: 'strength', multiplier: 1.8, nature: 'physical', element: 'neutral', hits: 1 } },
      },
    },
  },
};
const enemies = {
  goblin: { ...legacyEnemies.goblin, schemaVersion: 2, rewards: { xp: 40, gold: 25 } },
};
module.exports = { enemies, legacyEnemies };
