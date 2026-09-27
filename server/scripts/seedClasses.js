const { db } = require('../src/config/firebase');

const classes = {
  warrior: {
    name: 'Guerreiro',
    description: 'Especialista em defesa, guarda e contra-ataques.',

    baseAttributes: {
      hp: 120,
      strength: 12,
      magicPower: 3,
      defense: 12,
      speed: 5,
      maxEnergy: 6,
    },

    affinities: {
      physical: 0.90,
      magical: 1.10,
    },
  },

  mage: {
    name: 'Mago',
    description: 'Especialista em magia, elementos e reações.',

    baseAttributes: {
      hp: 85,
      strength: 3,
      magicPower: 14,
      defense: 6,
      speed: 7,
      maxEnergy: 6,
    },

    affinities: {
      physical: 1.10,
      magical: 0.90,
    },
  },

  rogue: {
    name: 'Ladino',
    description: 'Especialista em velocidade, preparação e críticos.',

    baseAttributes: {
      hp: 95,
      strength: 10,
      magicPower: 4,
      defense: 7,
      speed: 13,
      maxEnergy: 6,
    },

    affinities: {
      physical: 1.00,
      magical: 1.00,
    },
  },

  hunter: {
    name: 'Hunter',
    description: 'Especialista em ataques à distância, marcas e pets.',

    baseAttributes: {
      hp: 100,
      strength: 11,
      magicPower: 3,
      defense: 8,
      speed: 10,
      maxEnergy: 6,
    },

    affinities: {
      physical: 0.95,
      magical: 1.05,
    },
  },
};

async function seed() {
  console.log('Criando classes...');

  for (const [id, data] of Object.entries(classes)) {
    await db.collection('classes').doc(id).set(data);

    console.log(`Classe criada: ${id}`);
  }

  console.log('Classes criadas com sucesso.');

  process.exit(0);
}

seed().catch((error) => {
  console.error('Erro ao criar classes:', error);
  process.exit(1);
});