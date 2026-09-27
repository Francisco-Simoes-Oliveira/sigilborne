const { isDeepStrictEqual } = require('node:util');
const { enemies, legacyEnemies } = require('../src/data/enemies');
const { validateEnemy } = require('../src/domain/enemy-schema');

async function seedEnemies(db, { migrateRewards = false, check = false } = {}) {
  Object.values(enemies).forEach(validateEnemy);
  return db.runTransaction(async transaction => {
    const entries = Object.entries(enemies);
    const refs = entries.map(([id]) => db.collection('enemies').doc(id));
    const docs = await transaction.getAll(...refs);
    const actions = docs.map((doc, index) => {
      if (!doc.exists) return 'create';
      if (isDeepStrictEqual(doc.data(), entries[index][1])) return 'unchanged';
      if (isDeepStrictEqual(doc.data(), legacyEnemies[doc.id])) {
        if (migrateRewards) return 'update';
        throw new Error(`enemies/${doc.id} está no formato antigo. Valide com --migrate-rewards --check e aplique com --migrate-rewards. Nenhuma alteração foi feita.`);
      }
      throw new Error(`enemies/${doc.id} já existe com dados diferentes. Nenhuma alteração foi feita, mesmo com --migrate-rewards.`);
    });
    const created = actions.filter(action => action === 'create').length;
    const updated = actions.filter(action => action === 'update').length;
    const unchanged = entries.length - created - updated;
    if (check) return { wouldCreate: created, wouldUpdate: updated, unchanged };
    actions.forEach((action, index) => {
      if (action === 'create') transaction.create(refs[index], entries[index][1]);
      if (action === 'update') transaction.update(refs[index], { schemaVersion: 2, rewards: entries[index][1].rewards });
    });
    return { created, updated, unchanged };
  });
}
async function main() {
  Object.values(enemies).forEach(validateEnemy);
  const args = process.argv.slice(2);
  if (args.some(arg => !['--dry-run', '--check', '--migrate-rewards'].includes(arg))) throw new Error('Opção desconhecida. Use --dry-run, --check e/ou --migrate-rewards.');
  if (args.includes('--dry-run') && args.includes('--check')) throw new Error('Use --dry-run para validação local ou --check para consultar o Firestore.');
  if (args.includes('--dry-run')) { console.log('Seed válido: Goblin v2, 40 XP e 25 Gold. Sem acesso ao Firestore.'); return; }
  const { db } = require('../src/config/firebase');
  try { console.log(JSON.stringify(await seedEnemies(db, { migrateRewards: args.includes('--migrate-rewards'), check: args.includes('--check') }), null, 2)); }
  finally { await db.terminate(); }
}
if (require.main === module) main().catch(error => { console.error('Falha no seed:', error.message); process.exitCode = 1; });
module.exports = { seedEnemies };
