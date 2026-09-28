const supportedStatuses = new Set(['guard', 'stunned', 'vulnerable', 'taunted', 'counterStance', 'burn', 'chilled', 'shield', 'wet', 'focused', 'frozen', 'dodge', 'prepared', 'poison', 'bleed', 'marked', 'rooted']);
const dots = new Set(['burn', 'poison', 'bleed']);

function applyStatus(battle, target, effect, events, source = target) {
  const actor = battle[target];
  const parameters = structuredClone(effect.parameters ?? {});
  const previous = actor.statuses[effect.status];
  const status = { remainingTurns: effect.durationTurns, appliedOnTurn: battle.turn, appliedDuring: battle.currentActor, parameters, source,
    stacks: dots.has(effect.status) ? Math.min(9, (previous?.stacks ?? 0) + (effect.stacks ?? 1)) : (effect.stacks ?? 1) };
  if (effect.status === 'shield') status.remainingHp = Math.max(0, Math.round((battle[source].attributes[parameters.scaling] ?? 0) * parameters.multiplier));
  actor.statuses[effect.status] = status;
  if (effect.status === 'guard') {
    actor.guard = Math.max(0, Math.min(1, parameters.damageReduction));
    events.push({ type: 'GUARD_GAINED', target, reduction: actor.guard });
  } else events.push({ type: 'STATUS_APPLIED', target, status: effect.status, turns: effect.durationTurns });
}
function removeStatus(actor, name, events, target) {
  if (!actor.statuses[name]) return;
  delete actor.statuses[name];
  if (name === 'guard') actor.guard = 0;
  if (events) events.push({ type: 'STATUS_REMOVED', target, status: name });
}
function startActorTurn(battle, target, events) {
  const actor = battle[target];
  for (const [name, status] of Object.entries(actor.statuses)) {
    if (!dots.has(name) || actor.hp <= 0) continue;
    let amount = Math.max(0, Math.round((status.parameters.damagePerTurn ?? 0) * (status.stacks ?? 1)));
    if (!amount) continue;
    const shield = actor.statuses.shield;
    if (shield && shield.remainingHp > 0) {
      const absorbed = Math.min(amount, shield.remainingHp);
      shield.remainingHp -= absorbed; amount -= absorbed;
      events.push({ type: 'SHIELD_ABSORBED', target, amount: absorbed });
      if (shield.remainingHp <= 0) removeStatus(actor, 'shield', events, target);
    }
    amount = Math.min(actor.hp, amount);
    if (!amount) continue;
    actor.hp -= amount;
    actor.receivedDamageThisTurn = true;
    events.push({ type: 'STATUS_TICK', target, status: name, amount },
      { type: 'DAMAGE', source: status.source ?? (target === 'player' ? 'enemy' : 'player'), target,
        amount, nature: status.parameters.nature ?? 'physical', element: status.parameters.element ?? 'neutral', status: name });
  }
}
function endActorTurn(battle, target, events) {
  const actor = battle[target];
  for (const [name, status] of Object.entries(actor.statuses)) {
    if (status.appliedDuring === target && status.appliedOnTurn === battle.turn) continue;
    status.remainingTurns--;
    if (status.remainingTurns <= 0) {
      removeStatus(actor, name);
      events.push({ type: 'STATUS_EXPIRED', target, status: name }, { type: 'STATUS_REMOVED', target, status: name });
    }
  }
  if (target === 'player') {
    for (const trap of actor.traps ?? []) if (trap.appliedOnTurn !== battle.turn) trap.remainingTurns--;
    actor.traps = (actor.traps ?? []).filter(trap => {
      if (trap.remainingTurns > 0 && trap.charges > 0) return true;
      events.push({ type: 'TRAP_EXPIRED' }); return false;
    });
    if (actor.pet && actor.pet.remainingTurns != null) {
      if (actor.pet.appliedOnTurn !== battle.turn) actor.pet.remainingTurns--;
      if (actor.pet.remainingTurns <= 0) {
        events.push({ type: 'PET_EXPIRED', name: actor.pet.name }); actor.pet = null;
      }
    }
  }
}
module.exports = { supportedStatuses, applyStatus, removeStatus, startActorTurn, endActorTurn };
