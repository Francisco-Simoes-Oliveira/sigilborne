const advantage = { fire: 'ice', ice: 'earth', earth: 'electric', electric: 'fire' };

function multiplier(element, target) {
  if (!element || element === 'neutral') return 1;
  const override = target.elementModifiers?.[element];
  if (override !== undefined) return override;
  const defending = target.element ?? 'neutral';
  if (defending === 'neutral') return 1;
  if (advantage[element] === defending) return 1.25;
  if (advantage[defending] === element) return 0.75;
  return 1;
}

function reaction(element, target) {
  if (!target.statuses?.wet) return null;
  if (element === 'electric') return 'conductive';
  if (element === 'ice') return 'freeze';
  return null;
}

module.exports = { multiplier, reaction };
