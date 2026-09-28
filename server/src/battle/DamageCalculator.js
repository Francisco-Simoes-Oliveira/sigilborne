const ElementResolver = require('./ElementResolver');
function calculateDamage(source, target, damage, { criticalMultiplier = 1, damageMultiplier = 1 } = {}) {
  const speedFactor = damage.scaling === 'speed' ? (source.statuses?.chilled?.parameters.speedMultiplier ?? 1) : 1;
  const base = Math.max(0, source.attributes[damage.scaling] ?? 0) * speedFactor * damage.multiplier;
  const defense = Math.max(0, target.attributes.defense) * (1 - (damage.ignoreDefensePercent ?? 0) / 100);
  const elementMultiplier = ElementResolver.multiplier(damage.element, target);
  const natureMultiplier = target.natureModifiers?.[damage.nature] ?? 1;
  const vulnerability = target.statuses.vulnerable?.parameters.damageTakenMultiplier ?? 1;
  const beforeGuard = base * (100 / (100 + defense * 5)) * criticalMultiplier * damageMultiplier * elementMultiplier * natureMultiplier * vulnerability;
  const amount = Math.max(0, Math.round(beforeGuard * (1 - target.guard)));
  return { amount, absorbed: Math.max(0, Math.round(beforeGuard) - amount) };
}
module.exports = { calculateDamage };
