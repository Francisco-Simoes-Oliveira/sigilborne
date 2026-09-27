const { validId } = require('./card-schema');
const GameError = require('./game-error');

function validateEnemy(enemy) {
  const attributes = ['hp', 'strength', 'magicPower', 'defense', 'speed', 'maxEnergy'];
  const valid = enemy && enemy.schemaVersion === 1 && typeof enemy.name === 'string'
    && attributes.every(key => Number.isFinite(enemy.attributes?.[key]) && enemy.attributes[key] >= 0)
    && enemy.attributes.hp > 0 && enemy.behavior?.type === 'pattern'
    && Array.isArray(enemy.behavior.actions) && enemy.behavior.actions.length > 0
    && enemy.behavior.actions.every(id => {
      const action = enemy.behavior.definitions?.[id];
      const damage = action?.damage;
      return validId(id) && typeof action?.name === 'string' && damage
        && ['strength', 'magicPower', 'defense', 'speed'].includes(damage.scaling)
        && Number.isFinite(damage.multiplier) && damage.multiplier > 0
        && ['physical', 'magical'].includes(damage.nature)
        && ['neutral', 'fire', 'ice', 'earth', 'electric'].includes(damage.element)
        && Number.isInteger(damage.hits) && damage.hits >= 1 && damage.hits <= 5;
    });
  if (!valid) throw new GameError('INVALID_ENEMY', 503, 'Os dados do inimigo estão inválidos. Confira o seed.');
}
module.exports = { validateEnemy };
