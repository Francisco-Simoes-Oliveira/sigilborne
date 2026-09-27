// Declarative rules for deck validation and the future battle engine.
module.exports = Object.freeze({
  normalCards: 9,
  ultimates: 1,
  totalCards: 10,
  maxCopies: 3,
  handSize: 3,
  ultimateInHandCycle: false,
  initialMaxEnergy: 6,
  energyPerTurn: 3,
  capEnergyAtMaximum: true,
  resetEnergyAtTurnEnd: false,
  randomCriticals: false,
  elements: ['neutral', 'fire', 'ice', 'earth', 'electric'],
});
