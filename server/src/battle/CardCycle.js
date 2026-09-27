const { randomInt } = require('node:crypto');
const rules = require('../data/game-rules');

function startCycle(ids, choose = max => randomInt(max)) {
  if (ids.length !== rules.normalCards) throw new Error('Expected 9 normal cards');
  const shuffled = [...ids];
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j = choose(i + 1);
    [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
  }
  return { hand: shuffled.slice(0, rules.handSize), queue: shuffled.slice(rules.handSize) };
}

function rotate(player, cardId) {
  const index = player.hand.indexOf(cardId);
  if (index < 0 || player.queue.length !== 6) throw new Error('Invalid card cycle');
  const drawn = player.queue.shift();
  player.hand.splice(index, 1);
  player.hand.push(drawn);
  player.queue.push(cardId);
  return drawn;
}
module.exports = { startCycle, rotate };
