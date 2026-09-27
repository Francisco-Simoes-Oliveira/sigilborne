const rules = require('../data/game-rules');
const classIds = ['warrior', 'mage', 'rogue', 'hunter'];
const statuses = ['guard', 'stunned', 'vulnerable', 'taunted', 'counterStance', 'burn', 'chilled', 'shield', 'wet', 'focused', 'frozen', 'dodge', 'prepared', 'poison', 'bleed', 'marked', 'rooted'];
const targets = ['self', 'enemy'];
const scalings = ['strength', 'magicPower', 'defense', 'speed'];
function check(condition, message) { if (!condition) throw new Error(message); }
const positive = value => typeof value === 'number' && Number.isFinite(value) && value > 0;
const validId = value => typeof value === 'string' && /^[a-zA-Z0-9_-]{1,128}$/.test(value);
const text = value => typeof value === 'string' && value.trim().length > 0;

function validateDamage(value) {
  check(value && scalings.includes(value.scaling), 'Escala de dano inválida.');
  check(positive(value.multiplier), 'Multiplicador de dano inválido.');
  check(['physical', 'magical'].includes(value.nature), 'Natureza de dano inválida.');
  check(rules.elements.includes(value.element), 'Elemento inválido.');
  check(Number.isInteger(value.hits) && value.hits > 0, 'Número de acertos inválido.');
  if (value.ignoreDefensePercent !== undefined) check(Number.isFinite(value.ignoreDefensePercent) && value.ignoreDefensePercent >= 0 && value.ignoreDefensePercent <= 100, 'Penetração inválida.');
}

function validateCondition(condition) {
  check(condition && typeof condition === 'object', 'Condição inválida.');
  if (['all', 'any'].includes(condition.type)) {
    check(Array.isArray(condition.conditions) && condition.conditions.length > 0, 'Grupo de condições vazio.');
    condition.conditions.forEach(validateCondition);
    return;
  }
  check(targets.includes(condition.target), 'Alvo da condição inválido.');
  switch (condition.type) {
    case 'hasStatus': check(statuses.includes(condition.status), 'Status desconhecido.'); break;
    case 'petActive': break;
    case 'eventOccurred':
      check(condition.event === 'damageReceived' && condition.window === 'currentTurn', 'Evento inválido.'); break;
    case 'statCompare':
      check(condition.stat === 'hpPercent' && ['<', '<=', '==', '>=', '>'].includes(condition.operator) && Number.isFinite(condition.value) && condition.value >= 0 && condition.value <= 100, 'Comparação inválida.'); break;
    default: throw new Error(`Condição desconhecida: ${condition.type}`);
  }
}

function validateEffect(effect) {
  check(effect && typeof effect === 'object', 'Efeito inválido.');
  if (['critical', 'modifyDamage'].includes(effect.type)) {
    check(positive(effect.multiplier), 'Multiplicador de efeito inválido.');
    return;
  }
  check(targets.includes(effect.target), 'Alvo do efeito inválido.');
  switch (effect.type) {
    case 'applyStatus':
      check(statuses.includes(effect.status), 'Status desconhecido.');
      check(Number.isInteger(effect.durationTurns) && effect.durationTurns > 0 && Number.isInteger(effect.stacks) && effect.stacks > 0, 'Duração ou pilhas inválidas.');
      check(effect.parameters && typeof effect.parameters === 'object' && !Array.isArray(effect.parameters), 'Parâmetros de status inválidos.');
      if (effect.parameters.damage) validateDamage(effect.parameters.damage);
      break;
    case 'removeStatus': check(statuses.includes(effect.status), 'Status desconhecido.'); break;
    case 'restoreHealth': check(scalings.includes(effect.scaling) && positive(effect.multiplier), 'Cura inválida.'); break;
    case 'restoreEnergy': check(Number.isInteger(effect.amount) && effect.amount > 0, 'Energia inválida.'); break;
    case 'petAttack': check(positive(effect.multiplier), 'Ataque de pet inválido.'); break;
    case 'damage': validateDamage(effect.damage); break;
    case 'summonPet':
      check(Number.isInteger(effect.durationTurns) && effect.durationTurns > 0 && text(effect.pet?.name), 'Pet inválido.');
      validateDamage(effect.pet.damage); break;
    case 'setTrap':
      check(effect.trigger === 'beforeEnemyAttack' && Number.isInteger(effect.durationTurns) && effect.durationTurns > 0 && effect.charges === 1, 'Armadilha inválida.');
      check(Array.isArray(effect.effects) && effect.effects.length > 0, 'Armadilha sem efeitos.');
      effect.effects.forEach(validateEffect); break;
    default: throw new Error(`Efeito desconhecido: ${effect.type}`);
  }
}

function validateCard(card) {
  check(card && validId(card.id) && classIds.includes(card.classId), 'ID ou classe da carta inválido.');
  check(card.schemaVersion === 1 && text(card.name) && text(card.description), 'Metadados da carta inválidos.');
  check(!Object.hasOwn(card, 'level'), 'Cartas não possuem nível próprio.');
  check(Number.isInteger(card.cost) && card.cost >= 0 && card.cost <= rules.initialMaxEnergy, 'Custo inválido.');
  check(['attack', 'defense', 'skill', 'ultimate'].includes(card.type), 'Tipo de carta inválido.');
  check(Array.isArray(card.tags) && card.tags.every(text), 'Tags inválidas.');
  if (card.damage !== null) validateDamage(card.damage);
  check(Array.isArray(card.effects) && Array.isArray(card.conditionalEffects) && Array.isArray(card.requirements), 'Listas de efeitos inválidas.');
  card.effects.forEach(validateEffect);
  card.requirements.forEach(validateCondition);
  for (const entry of card.conditionalEffects) {
    validateCondition(entry.condition);
    check(Array.isArray(entry.effects) && entry.effects.length > 0, 'Efeito condicional vazio.');
    entry.effects.forEach(validateEffect);
  }
}

function validateDeckIds(deck) {
  check(deck && Array.isArray(deck.cards) && deck.cards.length === rules.normalCards, 'O deck precisa de exatamente 9 cartas normais.');
  check(deck.cards.every(validId) && validId(deck.ultimateId), 'ID de carta inválido.');
  check(!deck.cards.includes(deck.ultimateId), 'Ultimate não pode estar no ciclo de cartas normais.');
  const counts = new Map();
  for (const id of deck.cards) {
    counts.set(id, (counts.get(id) ?? 0) + 1);
    check(counts.get(id) <= rules.maxCopies, 'O deck excede 3 cópias da mesma carta.');
  }
}

function validateDeckCards(deck, classId, byId) {
  validateDeckIds(deck);
  for (const id of [...new Set([...deck.cards, deck.ultimateId])]) {
    const card = byId.get(id);
    check(card, `Carta ausente no catálogo: ${id}`);
    validateCard(card);
    check(card.classId === classId, 'Carta não pertence à classe do personagem.');
    check((card.type === 'ultimate') === (id === deck.ultimateId), 'Tipo de carta incompatível com seu lugar no deck.');
  }
}

function validateCatalog(cards, starterDecks) {
  check(cards.length === 40, 'O catálogo inicial precisa de 40 cartas.');
  cards.forEach(validateCard);
  const byId = new Map(cards.map(card => [card.id, card]));
  check(byId.size === cards.length, 'IDs duplicados no catálogo.');
  check(Object.keys(starterDecks).length === 4, 'São necessários 4 modelos de deck.');
  for (const classId of classIds) {
    const deck = starterDecks[classId];
    check(deck?.classId === classId && deck.schemaVersion === 1, 'Modelo de deck inválido.');
    validateDeckCards(deck, classId, byId);
    check(new Set(deck.cards).size === 9, 'O deck inicial precisa de 9 cartas distintas.');
    check(cards.filter(card => card.classId === classId && card.type === 'ultimate').length === 1, 'Cada classe precisa de uma Ultimate.');
    check(cards.filter(card => card.classId === classId && card.type !== 'ultimate').length === 9, 'Cada classe precisa de 9 cartas normais.');
  }
}

module.exports = { classIds, validId, validateCard, validateDeckIds, validateDeckCards, validateCatalog };
