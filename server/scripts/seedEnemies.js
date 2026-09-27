const { isDeepStrictEqual } = require('node:util');
const { enemies } = require('../src/data/enemies');
const { validateEnemy } = require('../src/domain/enemy-schema');

async function seedEnemies(db) {
  Object.values(enemies).forEach(validateEnemy);
  return db.runTransaction(async transaction => {
    const entries = Object.entries(enemies);
    const refs = entries.map(([id]) => db.collection('enemies').doc(id));
    const docs = await transaction.getAll(...refs);
    docs.forEach((doc, index) => {
      if (doc.exists && !isDeepStrictEqual(doc.data(), entries[index][1])) throw new Error(`enemies/${doc.id} já existe com dados diferentes. Nenhuma alteração foi feita.`);
    });
    let created = 0;
    docs.forEach((doc, index) => { if (!doc.exists) { transaction.create(refs[index], entries[index][1]); created++; } });
    return { created, unchanged: entries.length - created };
  });
}
async function main() {
  Object.values(enemies).forEach(validateEnemy);
  if (process.argv.includes('--dry-run')) { console.log('Seed válido: 1 inimigo (Goblin), padrão normal / normal / pesado. Sem acesso ao Firestore.'); return; }
  const { db } = require('../src/config/firebase');
  try { console.log(JSON.stringify(await seedEnemies(db), null, 2)); }
  finally { await db.terminate(); }
}
if (require.main === module) main().catch(error => { console.error('Falha no seed:', error.message); process.exitCode = 1; });
module.exports = { seedEnemies };
