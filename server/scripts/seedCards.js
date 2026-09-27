const { isDeepStrictEqual } = require('node:util');
const { cards, starterDecks } = require('../src/data/starter-cards');
const { classIds, validateCatalog } = require('../src/domain/card-schema');

async function seedCards(db) {
  validateCatalog(cards, starterDecks);
  const entries = [
    ...cards.map(({ id, ...data }) => ({ path: `cards/${id}`, data })),
    ...Object.entries(starterDecks).map(([id, data]) => ({ path: `starterDecks/${id}`, data })),
  ];
  return db.runTransaction(async transaction => {
    const classes = await transaction.getAll(...classIds.map(id => db.collection('classes').doc(id)));
    if (classes.some(doc => !doc.exists)) throw new Error('As quatro classes precisam existir. Execute scripts/seedClasses.js primeiro se ainda não as cadastrou.');
    const refs = entries.map(entry => db.doc(entry.path));
    const snapshots = await transaction.getAll(...refs);
    // Never overwrite edited or unrelated catalog data. A conflict aborts all writes.
    snapshots.forEach((doc, index) => {
      if (doc.exists && !isDeepStrictEqual(doc.data(), entries[index].data)) {
        throw new Error(`O documento ${entries[index].path} já existe com dados diferentes. Nada foi alterado. Revise o catálogo antes de continuar.`);
      }
    });
    let created = 0;
    snapshots.forEach((doc, index) => {
      if (!doc.exists) { transaction.create(refs[index], entries[index].data); created++; }
    });
    return { created, unchanged: entries.length - created, normalCards: 36, ultimates: 4, starterDecks: 4 };
  });
}

async function main() {
  validateCatalog(cards, starterDecks);
  if (process.argv.includes('--dry-run')) {
    console.log('Catálogo local válido: 36 cartas normais + 4 Ultimates; 4 decks com 9 cartas + 1 Ultimate. Nenhuma conexão com o Firestore.');
    return;
  }
  const { db } = require('../src/config/firebase');
  try {
    const result = await seedCards(db);
    console.log(JSON.stringify(result, null, 2));
  } finally {
    await db.terminate();
  }
}

if (require.main === module) {
  main().catch(error => {
    console.error('Falha no seed de cartas:', error.message);
    process.exitCode = 1;
  });
}

module.exports = { seedCards };
