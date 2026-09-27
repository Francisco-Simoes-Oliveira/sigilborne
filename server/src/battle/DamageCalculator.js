function calculateDamage(source, target, damage, { criticalMultiplier = 1, damageMultiplier = 1 } = {}) {
  const base = Math.max(0, source.attributes[damage.scaling] ?? 0) * damage.multiplier;
  const defense = Math.max(0, target.attributes.defense) * (1 - (damage.ignoreDefensePercent ?? 0) / 100);
  const elementMultiplier = target.elementModifiers?.[damage.element] ?? 1;
  const vulnerability = target.statuses.vulnerable?.parameters.damageTakenMultiplier ?? 1;
  const beforeGuard = base * (100 / (100 + defense * 5)) * criticalMultiplier * damageMultiplier * elementMultiplier * vulnerability;
  const amount = Math.max(0, Math.round(beforeGuard * (1 - target.guard)));
  return { amount, absorbed: Math.max(0, Math.round(beforeGuard) - amount) };
}
module.exports = { calculateDamage };
