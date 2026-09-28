// Combat defaults apply to the class, never to a particular card id.
const hunterPet = {
  name: 'Lobo',
  damage: { scaling: 'strength', multiplier: 0.6, nature: 'physical', element: 'neutral', hits: 1 },
  onHitEffects: [{ type: 'applyStatus', target: 'enemy', status: 'bleed', durationTurns: 2, stacks: 1,
    parameters: { damagePerTurn: 2, nature: 'physical', element: 'neutral' } }],
  remainingTurns: null,
};

module.exports = { hunterPet };
