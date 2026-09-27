const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const { test } = require('node:test');

// Load the real handlers with a fake Firebase boundary; no credentials or live writes.
function load(relativePath, dependencies) {
  const filename = path.join(__dirname, '..', relativePath);
  const module = { exports: {} };
  vm.runInNewContext(fs.readFileSync(filename, 'utf8'), {
    module,
    exports: module.exports,
    require(name) {
      assert.ok(Object.hasOwn(dependencies, name), `Unexpected dependency: ${name}`);
      return dependencies[name];
    },
    console: { error() {} },
    Date,
  }, { filename });
  return module.exports;
}

function fixture() {
  const records = [
    { id: 'doc-a', data: { id: 'untrusted-field', ownerId: 'user-a', name: 'Kael' } },
    { id: 'doc-b', data: { ownerId: 'user-b', name: 'Lyra' } },
  ];
  const queries = [];
  const service = load('src/services/character.service.js', {
    './deck.service': require('../src/services/deck.service'),
    './progression.service': require('../src/services/progression.service'),
    '../config/firebase': {
      db: {
        collection(name) {
          assert.equal(name, 'characters');
          return {
            where(field, operator, ownerId) {
              queries.push({ field, operator, ownerId });
              return {
                async get() {
                  return { docs: records.filter(record => record.data.ownerId === ownerId)
                    .map(record => ({ id: record.id, data: () => record.data })) };
                },
              };
            },
          };
        },
      },
    },
  });
  const controller = load('src/controllers/character.controller.js', {
    '../services/character.service': service,
    '../domain/card-schema': require('../src/domain/card-schema'),
  });
  const authenticate = load('src/middleware/auth.middleware.js', {
    '../config/firebase': {
      auth: {
        async verifyIdToken(token) {
          if (!['user-a', 'user-b', 'empty-user'].includes(token)) throw new Error('invalid token');
          return { uid: token };
        },
      },
    },
  });
  const routes = [];
  load('src/routes/character.routes.js', {
    express: { Router: () => ({
      get: (url, ...handlers) => routes.push({ method: 'GET', url, handlers }),
      post: (url, ...handlers) => routes.push({ method: 'POST', url, handlers }),
    }) },
    '../middleware/auth.middleware': authenticate,
    '../controllers/character.controller': controller,
    '../controllers/deck.controller': { getDeck() {} },
  });

  async function list(authorization, query = {}) {
    const req = { headers: { authorization }, query };
    const res = {
      statusCode: 200,
      status(code) { this.statusCode = code; return this; },
      json(body) { this.body = JSON.parse(JSON.stringify(body)); return this; },
    };
    const route = routes.find(route => route.method === 'GET' && route.url === '/characters');
    assert.equal(route.handlers.length, 2);
    let authenticated = false;
    await route.handlers[0](req, res, () => { authenticated = true; });
    if (authenticated) await route.handlers[1](req, res);
    return res;
  }

  return { list, queries, routes, authenticate, controller };
}

test('GET /characters isolates owners and ignores a forged query ownerId', async () => {
  const { list, queries } = fixture();
  const response = await list('Bearer user-a', { ownerId: 'user-b' });
  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body.characters, [{ id: 'doc-a', ownerId: 'user-a', name: 'Kael', gold: 0, xpToNextLevel: 100 }]);
  assert.deepEqual(queries, [{ field: 'ownerId', operator: '==', ownerId: 'user-a' }]);
});

test('another authenticated user receives only their own character', async () => {
  const response = await fixture().list('Bearer user-b');
  assert.deepEqual(response.body, { characters: [{ id: 'doc-b', ownerId: 'user-b', name: 'Lyra', gold: 0, xpToNextLevel: 100 }] });
});

test('an account without characters receives an empty array', async () => {
  const response = await fixture().list('Bearer empty-user');
  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, { characters: [] });
});

for (const authorization of [undefined, 'Basic user-a', 'Bearer expired', 'Bearer ']) {
  test(`unauthenticated listing is rejected before querying Firestore: ${authorization}`, async () => {
    const { list, queries } = fixture();
    const response = await list(authorization);
    assert.equal(response.statusCode, 401);
    assert.equal(queries.length, 0);
  });
}

test('all character routes require authentication', () => {
  const { routes, authenticate } = fixture();
  assert.equal(routes.length, 3);
  assert.ok(routes.every(route => route.handlers[0] === authenticate));
});

test('Firestore failures return an error instead of an empty account', async () => {
  const controller = load('src/controllers/character.controller.js', {
    '../domain/card-schema': require('../src/domain/card-schema'),
    '../services/character.service': {
      async getCharactersByOwner() { throw new Error('unavailable'); },
    },
  });
  const res = { status(code) { this.code = code; return this; }, json(body) { this.body = body; } };
  await controller.listMine({ user: { uid: 'user-a' } }, res);
  assert.equal(res.code, 500);
  assert.equal(res.body.error, 'Erro interno do servidor.');
});
