const { validateDeckIds, validateDeckCards } = require('../domain/card-schema');
const GameError = require('../domain/game-error');

async function resolveDeckCards(db, transaction, deck, classId) {
  try {
    validateDeckIds(deck);
    const ids = [...new Set([...deck.cards, deck.ultimateId])];
    const snapshots = await transaction.getAll(...ids.map(id => db.collection('cards').doc(id)));
    const byId = new Map(snapshots.filter(doc => doc.exists).map(doc => [doc.id, { ...doc.data(), id: doc.id }]));
    validateDeckCards(deck, classId, byId);
    return {
      cards: deck.cards.map(id => byId.get(id)),
      ultimate: byId.get(deck.ultimateId),
    };
  } catch (error) {
    // Do not turn transient Firestore failures into a permanent catalog error.
    if (error.code !== undefined) throw error;
    throw new GameError('INVALID_CARD_CATALOG', 503, 'O catálogo de cartas está incompleto ou inválido. Peça ao administrador para conferir o seed.');
  }
}

module.exports = { resolveDeckCards };
