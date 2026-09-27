const { db } = require('../config/firebase');
const { createDeckService } = require('./deck.service');

async function createCharacter({
  ownerId,
  name,
  classId,
}) {
  const characterRef = db.collection('characters').doc();
  const deckRef = db.collection('decks').doc();
  const deckService = createDeckService(db);
  return db.runTransaction(async transaction => {
    const classDoc = await transaction.get(db.collection('classes').doc(classId));

    if (!classDoc.exists) {
      throw new Error('CLASS_NOT_FOUND');
    }

    const classData = classDoc.data();
    const { starter } = await deckService.readStarterDeck(transaction, classId);

    const characterData = {
      ownerId,
      name: name.trim(),
      classId,

      level: 1,
      xp: 0,

      attributePoints: 0,

      attributes: {
        ...classData.baseAttributes,
      },

      equipment: {
        weapon: null,
        armor: null,
        accessory1: null,
        accessory2: null,
      },

      equippedDeckId: deckRef.id,

      createdAt: new Date(),
    };

    transaction.create(characterRef, characterData);
    transaction.create(deckRef, deckService.starterDeckData(ownerId, characterRef.id, starter));

    return {
      id: characterRef.id,
      ...characterData,
    };
  });
}

async function getCharactersByOwner(ownerId) {
  const snapshot = await db
    .collection('characters')
    .where('ownerId', '==', ownerId)
    .get();

  return snapshot.docs.map((doc) => ({
    ...doc.data(),
    id: doc.id,
  }));
}

module.exports = {
  createCharacter,
  getCharactersByOwner,
};
