const { validId, validateDeckIds } = require('../domain/card-schema');
const { resolveDeckCards } = require('./card.service');
const GameError = require('../domain/game-error');

function createDeckService(db) {
  async function readStarterDeck(transaction, classId) {
    if (!validId(classId)) throw new GameError('CLASS_NOT_FOUND', 400, 'Classe inválida.');
    const snapshot = await transaction.get(db.collection('starterDecks').doc(classId));
    if (!snapshot.exists) throw new GameError('STARTER_DECK_NOT_FOUND', 503, 'O deck inicial desta classe ainda não foi cadastrado. Execute o seed de cartas no servidor.');
    const starter = snapshot.data();
    try {
      validateDeckIds(starter);
      if (starter.schemaVersion !== 1 || starter.classId !== classId || new Set(starter.cards).size !== 9) throw new Error('Invalid starter');
    } catch (_) {
      throw new GameError('INVALID_STARTER_DECK', 503, 'O modelo de deck inicial está inválido. Confira o seed de cartas.');
    }
    const resolved = await resolveDeckCards(db, transaction, starter, classId);
    return { starter, resolved };
  }

  function starterDeckData(ownerId, characterId, starter) {
    return {
      ownerId, characterId, name: 'Deck Inicial', cards: [...starter.cards],
      ultimateId: starter.ultimateId, createdAt: new Date(),
    };
  }

  async function getCharacterDeck(ownerId, characterId) {
    if (!validId(characterId)) throw new GameError('CHARACTER_NOT_FOUND', 404, 'Personagem não encontrado.');
    const characterRef = db.collection('characters').doc(characterId);
    // Stable across retries; only one caller can attach its deck to this character.
    const newDeckRef = db.collection('decks').doc();
    return db.runTransaction(async transaction => {
      const characterDoc = await transaction.get(characterRef);
      if (!characterDoc.exists) throw new GameError('CHARACTER_NOT_FOUND', 404, 'Personagem não encontrado.');
      const character = characterDoc.data();
      if (character.ownerId !== ownerId) throw new GameError('CHARACTER_FORBIDDEN', 403, 'Este personagem não pertence à sua conta.');

      if (character.equippedDeckId == null) {
        const { starter, resolved } = await readStarterDeck(transaction, character.classId);
        const deck = starterDeckData(ownerId, characterId, starter);
        // All reads precede writes, and both writes commit together.
        transaction.create(newDeckRef, deck);
        transaction.update(characterRef, { equippedDeckId: newDeckRef.id });
        return { ...deck, id: newDeckRef.id, ...resolved };
      }

      if (!validId(character.equippedDeckId)) throw new GameError('INVALID_DECK_LINK', 409, 'O vínculo do deck está inválido. Peça ao administrador para conferir o personagem.');
      const deckDoc = await transaction.get(db.collection('decks').doc(character.equippedDeckId));
      if (!deckDoc.exists) throw new GameError('DECK_NOT_FOUND', 409, 'O deck equipado não foi encontrado. Peça ao administrador para conferir o vínculo.');
      const deck = deckDoc.data();
      if (deck.ownerId !== ownerId || deck.characterId !== characterId) throw new GameError('DECK_FORBIDDEN', 403, 'O deck não pertence a este personagem e à sua conta.');
      const resolved = await resolveDeckCards(db, transaction, deck, character.classId);
      return { ...deck, id: deckDoc.id, ...resolved };
    });
  }

  return { readStarterDeck, starterDeckData, getCharacterDeck };
}

module.exports = { createDeckService };
