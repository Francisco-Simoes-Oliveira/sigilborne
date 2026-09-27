const assert = require('node:assert/strict');

// Optimistic transaction simulation: atomic writes, read-before-write enforcement,
// and retries on conflicting reads. No Firebase credentials or network involved.
class FakeFirestore {
  constructor(initial = {}) {
    this.records = new Map(Object.entries(initial).map(([key, data]) => [key, { version: 1, data: structuredClone(data) }]));
    this.nextId = 0;
    this.commits = 0;
    this.retries = 0;
  }
  collection(name) { return { doc: id => this.doc(`${name}/${id ?? `auto_${++this.nextId}`}`) }; }
  doc(path) { return { path, id: path.split('/').at(-1) }; }
  data(path) { return structuredClone(this.records.get(path)?.data); }
  set(path, data) { this.records.set(path, { version: (this.records.get(path)?.version ?? 0) + 1, data: structuredClone(data) }); }
  paths(collection) { return [...this.records.keys()].filter(path => path.startsWith(`${collection}/`)); }
  async runTransaction(callback) {
    for (let attempt = 0; attempt < 12; attempt++) {
      const reads = new Map();
      const writes = [];
      const transaction = {
        get: async ref => {
          assert.equal(writes.length, 0, 'Firestore reads must precede all writes');
          const record = this.records.get(ref.path);
          reads.set(ref.path, record?.version ?? 0);
          const data = structuredClone(record?.data);
          await Promise.resolve();
          return { id: ref.id, exists: !!record, data: () => structuredClone(data) };
        },
        getAll: (...refs) => Promise.all(refs.map(ref => transaction.get(ref))),
        create: (ref, data) => writes.push({ type: 'create', ref, data: structuredClone(data) }),
        update: (ref, data) => writes.push({ type: 'update', ref, data: structuredClone(data) }),
      };
      const result = await callback(transaction);
      if ([...reads].some(([path, version]) => (this.records.get(path)?.version ?? 0) !== version)) { this.retries++; continue; }
      for (const write of writes) {
        assert.equal(this.records.has(write.ref.path), write.type === 'update', `Invalid ${write.type}: ${write.ref.path}`);
      }
      for (const write of writes) this.set(write.ref.path, write.type === 'update' ? { ...this.data(write.ref.path), ...write.data } : write.data);
      if (writes.length) this.commits++;
      return result;
    }
    throw new Error('Too much transaction contention');
  }
}
module.exports = FakeFirestore;
