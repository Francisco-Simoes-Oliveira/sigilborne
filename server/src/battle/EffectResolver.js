const { calculateDamage } = require('./DamageCalculator');
const { applyStatus, removeStatus, supportedStatuses } = require('./StatusResolver');
const { conditionsSupported } = require('./ConditionResolver');

function targetFor(source, target) { return target === 'self' ? source : source === 'player' ? 'enemy' : 'player'; }

function dealDamage(battle, source, target, damage, modifiers, events) {
  for (let hit = 0; hit < (damage.hits ?? 1) && battle[target].hp > 0; hit++) {
    const result = calculateDamage(battle[source], battle[target], damage, modifiers);
    if ((modifiers?.criticalMultiplier ?? 1) > 1) events.push({ type: 'CRITICAL', source, target, multiplier: modifiers.criticalMultiplier });
    if (result.absorbed > 0) events.push({ type: 'GUARD_ABSORBED', target, amount: result.absorbed });
    const amount = Math.min(battle[target].hp, result.amount);
    battle[target].hp -= amount;
    if (amount > 0) battle[target].receivedDamageThisTurn = true;
    events.push({ type: 'DAMAGE', source, target, amount, nature: damage.nature, element: damage.element });
  }
}

function resolveEffect(battle, source, effect, events) {
  const target = targetFor(source, effect.target);
  const actor = battle[target];
  switch (effect.type) {
    case 'damage': dealDamage(battle, source, target, effect.damage, {}, events); break;
    case 'applyStatus': applyStatus(battle, target, effect, events); break;
    case 'gainGuard': applyStatus(battle, target, { status: 'guard', durationTurns: effect.durationTurns, parameters: { damageReduction: effect.reduction } }, events); break;
    case 'removeStatus': removeStatus(actor, effect.status); break;
    case 'heal':
    case 'restoreHealth': {
      const amount = Math.min(actor.maxHp - actor.hp, Math.max(0, Math.round(battle[source].attributes[effect.scaling] * effect.multiplier)));
      actor.hp += amount;
      events.push({ type: 'HEAL', source, target, amount });
      break;
    }
    case 'critical':
    case 'modifyDamage': break; // Resolved before the damage pass.
    default: throw new Error(`Unsupported effect: ${effect.type}`);
  }
}

function effectSupported(effect) {
  if (effect.type === 'applyStatus') return supportedStatuses.has(effect.status);
  return ['damage', 'gainGuard', 'heal', 'restoreHealth', 'critical', 'modifyDamage', 'removeStatus'].includes(effect.type);
}
function cardSupported(card) {
  return card.requirements.every(conditionsSupported) && card.effects.every(effectSupported)
    && card.conditionalEffects.every(item => conditionsSupported(item.condition) && item.effects.every(effectSupported));
}
module.exports = { dealDamage, resolveEffect, cardSupported };
