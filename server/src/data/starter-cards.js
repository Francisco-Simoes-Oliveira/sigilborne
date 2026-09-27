// These helpers only construct JSON data. They do not execute combat logic.
const damage = (scaling, multiplier, element = 'neutral', extra = {}) => ({
  scaling, multiplier, nature: scaling === 'magicPower' ? 'magical' : 'physical',
  element, hits: 1, ...extra,
});
const status = (target, name, durationTurns, parameters = {}) => ({
  type: 'applyStatus', target, status: name, durationTurns, stacks: 1, parameters,
});
const hasStatus = (target, name) => ({ type: 'hasStatus', target, status: name });
const conditional = (condition, ...effects) => ({ condition, effects });
const critical = (multiplier = 1.5) => ({ type: 'critical', multiplier });
const removeStatus = (target, name) => ({ type: 'removeStatus', target, status: name });
const anyStatus = (target, statuses) => ({ type: 'any', conditions: statuses.map(name => hasStatus(target, name)) });
const card = (classId, slug, name, cost, type, description, details = {}) => ({
  id: `${classId}_${slug}`, schemaVersion: 1, name, classId, description, cost, type,
  tags: [type], damage: null, effects: [], conditionalEffects: [], requirements: [], ...details,
});

const cards = [
  card('warrior', 'slash', 'Corte', 1, 'attack', 'Causa dano físico igual a 100% da Força.', {
    tags: ['attack', 'physical', 'melee'], damage: damage('strength', 1),
  }),
  card('warrior', 'heavy_strike', 'Golpe Pesado', 3, 'attack', 'Causa dano físico igual a 180% da Força.', {
    tags: ['attack', 'physical', 'melee'], damage: damage('strength', 1.8),
  }),
  card('warrior', 'block', 'Bloqueio', 1, 'defense', 'Recebe Guarda por 1 turno: reduz o dano recebido em 50%.', {
    tags: ['defense', 'guard'], effects: [status('self', 'guard', 1, { damageReduction: 0.5 })],
  }),
  card('warrior', 'shield_bash', 'Golpe de Escudo', 2, 'attack', 'Causa dano físico de 120% da Defesa. Com Guarda, atordoa o alvo por 1 turno.', {
    tags: ['attack', 'physical', 'melee'], damage: damage('defense', 1.2),
    conditionalEffects: [conditional(hasStatus('self', 'guard'), status('enemy', 'stunned', 1))],
  }),
  card('warrior', 'counter_attack', 'Contra-Ataque', 2, 'attack', 'Requer Guarda. Causa 120% da Força; é crítico (1,5×) se recebeu dano neste turno.', {
    tags: ['attack', 'physical', 'counter'], damage: damage('strength', 1.2),
    requirements: [hasStatus('self', 'guard')],
    conditionalEffects: [conditional({ type: 'eventOccurred', target: 'self', event: 'damageReceived', window: 'currentTurn' }, critical())],
  }),
  card('warrior', 'charge', 'Investida', 2, 'attack', 'Causa 120% da Força e deixa o alvo Vulnerável por 1 turno (+20% de dano recebido).', {
    tags: ['attack', 'physical', 'melee'], damage: damage('strength', 1.2),
    effects: [status('enemy', 'vulnerable', 1, { damageTakenMultiplier: 1.2 })],
  }),
  card('warrior', 'taunt', 'Provocar', 1, 'skill', 'Provoca o alvo por 2 turnos, direcionando seus ataques ao usuário. Recebe Guarda de 30% por 1 turno.', {
    tags: ['control', 'guard'], effects: [status('enemy', 'taunted', 2), status('self', 'guard', 1, { damageReduction: 0.3 })],
  }),
  card('warrior', 'second_wind', 'Segundo Fôlego', 2, 'skill', 'Recupera vida igual a 200% da Defesa, sem ultrapassar a vida máxima.', {
    tags: ['heal'], effects: [{ type: 'restoreHealth', target: 'self', scaling: 'defense', multiplier: 2 }],
  }),
  card('warrior', 'double_strike', 'Golpe Duplo', 2, 'attack', 'Ataca duas vezes, causando 65% da Força por acerto.', {
    tags: ['attack', 'physical', 'melee', 'multiHit'], damage: damage('strength', 0.65, 'neutral', { hits: 2 }),
  }),
  card('warrior', 'unbreakable_wall', 'Muralha Inquebrável', 6, 'ultimate', 'Por 2 turnos, recebe Guarda de 80% e contra-ataca após cada ataque recebido com 80% da Força.', {
    tags: ['ultimate', 'guard', 'counter'], effects: [
      status('self', 'guard', 2, { damageReduction: 0.8 }),
      status('self', 'counterStance', 2, { trigger: 'afterIncomingAttack', damage: damage('strength', 0.8), allowTriggeredChains: false }),
    ],
  }),

  card('mage', 'arcane_missile', 'Míssil Arcano', 1, 'attack', 'Causa dano mágico neutro igual a 100% do Poder Mágico.', {
    tags: ['attack', 'magical'], damage: damage('magicPower', 1),
  }),
  card('mage', 'fireball', 'Bola de Fogo', 2, 'attack', 'Causa 130% do Poder Mágico em fogo e Queimadura de 4 de dano por turno, por 2 turnos.', {
    tags: ['attack', 'magical', 'fire'], damage: damage('magicPower', 1.3, 'fire'),
    effects: [status('enemy', 'burn', 2, { damagePerTurn: 4, nature: 'magical', element: 'fire' })],
  }),
  card('mage', 'ice_lance', 'Lança de Gelo', 2, 'attack', 'Causa 110% do Poder Mágico em gelo e Resfriado por 2 turnos (-30% de velocidade).', {
    tags: ['attack', 'magical', 'ice'], damage: damage('magicPower', 1.1, 'ice'),
    effects: [status('enemy', 'chilled', 2, { speedMultiplier: 0.7 })],
  }),
  card('mage', 'spark', 'Faísca', 1, 'attack', 'Causa 80% do Poder Mágico em eletricidade. Contra Encharcado, é crítico (1,5×) e atordoa por 1 turno.', {
    tags: ['attack', 'magical', 'electric'], damage: damage('magicPower', 0.8, 'electric'),
    conditionalEffects: [conditional(hasStatus('enemy', 'wet'), critical(), status('enemy', 'stunned', 1))],
  }),
  card('mage', 'arcane_barrier', 'Barreira Arcana', 2, 'defense', 'Cria um escudo que absorve 150% do Poder Mágico em dano por até 2 turnos.', {
    tags: ['defense', 'magical'], effects: [status('self', 'shield', 2, { scaling: 'magicPower', multiplier: 1.5 })],
  }),
  card('mage', 'channel', 'Canalizar', 0, 'skill', 'Recupera 2 de energia, sem ultrapassar a energia máxima.', {
    tags: ['energy'], effects: [{ type: 'restoreEnergy', target: 'self', amount: 2 }],
  }),
  card('mage', 'soak', 'Encharcar', 1, 'skill', 'Aplica Encharcado por 2 turnos, preparando combos de gelo e eletricidade.', {
    tags: ['status', 'setup'], effects: [status('enemy', 'wet', 2)],
  }),
  card('mage', 'elemental_burst', 'Explosão Elemental', 3, 'attack', 'Causa 160% do Poder Mágico em fogo. Contra Queimadura, Resfriado ou Encharcado, causa 50% a mais de dano.', {
    tags: ['attack', 'magical', 'fire', 'combo'], damage: damage('magicPower', 1.6, 'fire'),
    conditionalEffects: [conditional(anyStatus('enemy', ['burn', 'chilled', 'wet']), { type: 'modifyDamage', multiplier: 1.5 })],
  }),
  card('mage', 'focus', 'Concentração', 1, 'skill', 'O próximo ataque mágico em até 2 turnos causa 30% a mais de dano.', {
    tags: ['setup', 'magical'], effects: [status('self', 'focused', 2, { damageMultiplier: 1.3, damageNature: 'magical', charges: 1 })],
  }),
  card('mage', 'absolute_zero', 'Zero Absoluto', 6, 'ultimate', 'Causa 220% do Poder Mágico em gelo e Congelado por 1 turno. Contra Encharcado, causa 50% a mais de dano.', {
    tags: ['ultimate', 'magical', 'ice'], damage: damage('magicPower', 2.2, 'ice'), effects: [status('enemy', 'frozen', 1)],
    conditionalEffects: [conditional(hasStatus('enemy', 'wet'), { type: 'modifyDamage', multiplier: 1.5 })],
  }),

  card('rogue', 'quick_slash', 'Corte Rápido', 1, 'attack', 'Causa dano físico igual a 100% da Velocidade.', {
    tags: ['attack', 'physical', 'melee'], damage: damage('speed', 1),
  }),
  card('rogue', 'dodge', 'Esquiva', 1, 'defense', 'Evita o próximo ataque recebido em até 1 turno.', {
    tags: ['defense', 'dodge'], effects: [status('self', 'dodge', 1, { charges: 1 })],
  }),
  card('rogue', 'backstab', 'Ataque pelas Costas', 2, 'attack', 'Causa 120% da Força. Se estiver Preparado, é crítico (1,5×) e consome Preparado.', {
    tags: ['attack', 'physical', 'melee', 'conditionalCritical'], damage: damage('strength', 1.2),
    conditionalEffects: [conditional(hasStatus('self', 'prepared'), critical(), removeStatus('self', 'prepared'))],
  }),
  card('rogue', 'poison', 'Veneno', 1, 'skill', 'Aplica Veneno: 4 de dano físico neutro por turno durante 3 turnos.', {
    tags: ['status', 'poison'], effects: [status('enemy', 'poison', 3, { damagePerTurn: 4, nature: 'physical', element: 'neutral' })],
  }),
  card('rogue', 'deep_cut', 'Corte Profundo', 2, 'attack', 'Causa 100% da Força e Sangramento: 3 de dano físico por turno durante 3 turnos.', {
    tags: ['attack', 'physical', 'bleed'], damage: damage('strength', 1),
    effects: [status('enemy', 'bleed', 3, { damagePerTurn: 3, nature: 'physical', element: 'neutral' })],
  }),
  card('rogue', 'prepare', 'Preparação', 0, 'skill', 'Recebe Preparado por 2 turnos, habilitando críticos condicionais.', {
    tags: ['setup', 'prepared'], effects: [status('self', 'prepared', 2)],
  }),
  card('rogue', 'double_strike', 'Golpe Duplo', 2, 'attack', 'Ataca duas vezes, causando 65% da Força por acerto.', {
    tags: ['attack', 'physical', 'multiHit'], damage: damage('strength', 0.65, 'neutral', { hits: 2 }),
  }),
  card('rogue', 'exploit_weakness', 'Explorar Fraqueza', 2, 'attack', 'Causa 110% da Força. Contra Veneno, Sangramento ou Vulnerável, é crítico (1,5×).', {
    tags: ['attack', 'physical', 'conditionalCritical'], damage: damage('strength', 1.1),
    conditionalEffects: [conditional(anyStatus('enemy', ['poison', 'bleed', 'vulnerable']), critical())],
  }),
  card('rogue', 'execute', 'Execução', 3, 'attack', 'Causa 150% da Força. Contra alvos com até 30% da vida, é crítico (1,5×).', {
    tags: ['attack', 'physical', 'finisher'], damage: damage('strength', 1.5),
    conditionalEffects: [conditional({ type: 'statCompare', target: 'enemy', stat: 'hpPercent', operator: '<=', value: 30 }, critical())],
  }),
  card('rogue', 'perfect_execution', 'Execução Perfeita', 6, 'ultimate', 'Causa 250% da Força. Se estiver Preparado, é crítico (2×) e consome Preparado.', {
    tags: ['ultimate', 'physical', 'finisher'], damage: damage('strength', 2.5),
    conditionalEffects: [conditional(hasStatus('self', 'prepared'), critical(2), removeStatus('self', 'prepared'))],
  }),

  card('hunter', 'quick_shot', 'Tiro Rápido', 1, 'attack', 'Causa dano físico à distância igual a 100% da Força.', {
    tags: ['attack', 'physical', 'ranged'], damage: damage('strength', 1),
  }),
  card('hunter', 'marking_shot', 'Tiro Marcador', 1, 'attack', 'Causa 70% da Força e aplica Marcado por 3 turnos.', {
    tags: ['attack', 'physical', 'ranged', 'mark'], damage: damage('strength', 0.7), effects: [status('enemy', 'marked', 3)],
  }),
  card('hunter', 'precise_shot', 'Tiro Preciso', 2, 'attack', 'Causa 130% da Força. Contra Marcado, é crítico (1,5×).', {
    tags: ['attack', 'physical', 'ranged', 'conditionalCritical'], damage: damage('strength', 1.3),
    conditionalEffects: [conditional(hasStatus('enemy', 'marked'), critical())],
  }),
  card('hunter', 'command_attack', 'Comando: Atacar', 1, 'skill', 'Requer pet ativo. Ordena um ataque com 100% do dano do pet.', {
    tags: ['pet', 'attack'], requirements: [{ type: 'petActive', target: 'self' }], effects: [{ type: 'petAttack', target: 'enemy', multiplier: 1 }],
  }),
  card('hunter', 'hunting_trap', 'Armadilha de Caça', 2, 'skill', 'Arma uma armadilha por 2 turnos: no próximo ataque inimigo, causa 80% da Força e Imobilizado por 1 turno.', {
    tags: ['trap', 'control'], effects: [{ type: 'setTrap', target: 'enemy', trigger: 'beforeEnemyAttack', durationTurns: 2, charges: 1,
      effects: [{ type: 'damage', target: 'enemy', damage: damage('strength', 0.8) }, status('enemy', 'rooted', 1)] }],
  }),
  card('hunter', 'retreat', 'Recuar', 1, 'defense', 'Evita o próximo ataque recebido em até 1 turno.', {
    tags: ['defense', 'dodge'], effects: [status('self', 'dodge', 1, { charges: 1 })],
  }),
  card('hunter', 'piercing_arrow', 'Flecha Perfurante', 3, 'attack', 'Causa 150% da Força e ignora 50% da Defesa do alvo.', {
    tags: ['attack', 'physical', 'ranged', 'piercing'], damage: damage('strength', 1.5, 'neutral', { ignoreDefensePercent: 50 }),
  }),
  card('hunter', 'predator_instinct', 'Instinto Predador', 2, 'skill', 'Invoca um lobo por 3 turnos (dano de 60% da Força do Hunter) e aplica Marcado por 2 turnos.', {
    tags: ['pet', 'setup'], effects: [{ type: 'summonPet', target: 'self', durationTurns: 3, pet: { name: 'Lobo', damage: damage('strength', 0.6) } }, status('enemy', 'marked', 2)],
  }),
  card('hunter', 'double_shot', 'Disparo Duplo', 2, 'attack', 'Dispara duas vezes, causando 65% da Força por acerto.', {
    tags: ['attack', 'physical', 'ranged', 'multiHit'], damage: damage('strength', 0.65, 'neutral', { hits: 2 }),
  }),
  card('hunter', 'hunt_begins', 'A Caçada Começou', 6, 'ultimate', 'Aplica Marcado por 3 turnos, invoca um lobo de 80% da Força por 3 turnos e causa 200% da Força à distância.', {
    tags: ['ultimate', 'physical', 'ranged', 'pet'], damage: damage('strength', 2),
    effects: [status('enemy', 'marked', 3), { type: 'summonPet', target: 'self', durationTurns: 3, pet: { name: 'Lobo Alfa', damage: damage('strength', 0.8) } }],
  }),
];

const starterDecks = Object.fromEntries(['warrior', 'mage', 'rogue', 'hunter'].map(classId => [classId, {
  schemaVersion: 1, classId, name: 'Deck Inicial',
  cards: cards.filter(card => card.classId === classId && card.type !== 'ultimate').map(card => card.id),
  ultimateId: cards.find(card => card.classId === classId && card.type === 'ultimate').id,
}]));

module.exports = { cards, starterDecks };
