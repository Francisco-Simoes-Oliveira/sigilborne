function actorFor(battle, source, target) {
  return battle[target === 'self' ? source : source === 'player' ? 'enemy' : 'player'];
}

function matches(condition, battle, source = 'player') {
  if (condition.type === 'all') return condition.conditions.every(item => matches(item, battle, source));
  if (condition.type === 'any') return condition.conditions.some(item => matches(item, battle, source));
  const actor = actorFor(battle, source, condition.target);
  switch (condition.type) {
    case 'hasStatus': return !!actor.statuses[condition.status];
    case 'petActive': return !!actor.pet;
    case 'eventOccurred': return condition.event === 'damageReceived' && condition.window === 'currentTurn' && actor.receivedDamageThisTurn;
    case 'statCompare': {
      const actual = actor.hp * 100 / actor.maxHp;
      if (condition.stat !== 'hpPercent') return false;
      return ({ '<': actual < condition.value, '<=': actual <= condition.value, '==': actual === condition.value, '>=': actual >= condition.value, '>': actual > condition.value })[condition.operator] ?? false;
    }
    default: return false;
  }
}

function conditionsSupported(condition) {
  if (['all', 'any'].includes(condition.type)) return condition.conditions.every(conditionsSupported);
  return ['hasStatus', 'petActive', 'eventOccurred', 'statCompare'].includes(condition.type);
}

module.exports = { actorFor, matches, conditionsSupported };
