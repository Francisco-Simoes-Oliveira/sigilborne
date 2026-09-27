const supportedStatuses = new Set(['guard', 'stunned', 'vulnerable', 'taunted', 'counterStance']);

function applyStatus(battle, target, effect, events) {
  const actor = battle[target];
  actor.statuses[effect.status] = {
    remainingTurns: effect.durationTurns,
    appliedOnTurn: battle.turn,
    parameters: structuredClone(effect.parameters ?? {}),
  };
  if (effect.status === 'guard') {
    actor.guard = Math.max(0, Math.min(1, effect.parameters.damageReduction));
    events.push({ type: 'GUARD_GAINED', target, reduction: actor.guard });
  } else {
    events.push({ type: 'STATUS_APPLIED', target, status: effect.status, turns: effect.durationTurns });
  }
}

function removeStatus(actor, name) {
  delete actor.statuses[name];
  if (name === 'guard') actor.guard = 0;
}

function endActorTurn(battle, target, events) {
  const actor = battle[target];
  for (const [name, status] of Object.entries(actor.statuses)) {
    // A self buff survives the turn in which it was played and the enemy reply.
    if (target === 'player' && status.appliedOnTurn === battle.turn) continue;
    status.remainingTurns--;
    if (status.remainingTurns <= 0) {
      removeStatus(actor, name);
      events.push({ type: 'STATUS_EXPIRED', target, status: name });
    }
  }
}

module.exports = { supportedStatuses, applyStatus, removeStatus, endActorTurn };
