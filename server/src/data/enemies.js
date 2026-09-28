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
  fire_slime: {
    schemaVersion: 2, name: 'Slime de Fogo', description: 'Criatura flamejante: resiste a fogo e é fraca contra gelo.',
    element: 'fire', elementModifiers: { fire: 0.75, ice: 1.25 },
    attributes: { hp: 72, strength: 5, magicPower: 9, defense: 4, speed: 3, maxEnergy: 0 },
    behavior: { type: 'pattern', actions: ['flame', 'flame', 'flare'], definitions: {
      flame: { name: 'Chama', damage: { scaling: 'magicPower', multiplier: 1, nature: 'magical', element: 'fire', hits: 1 } },
      flare: { name: 'Explosão de brasas', damage: { scaling: 'magicPower', multiplier: 1.2, nature: 'magical', element: 'fire', hits: 1 },
        effects: [{ type: 'applyStatus', target: 'enemy', status: 'burn', durationTurns: 2, stacks: 1,
          parameters: { damagePerTurn: 3, nature: 'magical', element: 'fire' } }] },
    } }, rewards: { xp: 45, gold: 30 },
  },
  skeleton_guard: {
    schemaVersion: 2, name: 'Guardião Esqueleto', description: 'Resistente e lento; alterna golpes de espada e escudo.',
    element: 'earth',
    attributes: { hp: 105, strength: 10, magicPower: 0, defense: 14, speed: 2, maxEnergy: 0 },
    behavior: { type: 'pattern', actions: ['sword', 'shield_strike', 'sword'], definitions: {
      sword: { name: 'Espadada', damage: { scaling: 'strength', multiplier: 1, nature: 'physical', element: 'neutral', hits: 1 } },
      shield_strike: { name: 'Golpe de escudo', damage: { scaling: 'strength', multiplier: 1.3, nature: 'physical', element: 'earth', hits: 1 } },
    } }, rewards: { xp: 55, gold: 35 },
  },
  goblin_shaman: {
    schemaVersion: 2, name: 'Xamã Goblin', description: 'Usa eletricidade e atordoamento em um padrão previsível.',
    element: 'electric',
    attributes: { hp: 68, strength: 4, magicPower: 12, defense: 5, speed: 8, maxEnergy: 0 },
    behavior: { type: 'pattern', actions: ['spark', 'hex', 'spark'], definitions: {
      spark: { name: 'Faísca xamânica', damage: { scaling: 'magicPower', multiplier: 1, nature: 'magical', element: 'electric', hits: 1 } },
      hex: { name: 'Maldição elétrica', damage: { scaling: 'magicPower', multiplier: 0.8, nature: 'magical', element: 'electric', hits: 1 },
        effects: [{ type: 'applyStatus', target: 'enemy', status: 'stunned', durationTurns: 1, stacks: 1, parameters: {} }] },
    } }, rewards: { xp: 60, gold: 40 },
  },
};
module.exports = { enemies, legacyEnemies };
