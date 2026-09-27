const { db } = require('../config/firebase');

async function createCharacter({
  ownerId,
  name,
  classId,
}) {
  const classDoc = await db
    .collection('classes')
    .doc(classId)
    .get();

  if (!classDoc.exists) {
    throw new Error('CLASS_NOT_FOUND');
  }

  const classData = classDoc.data();

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

    equippedDeckId: null,

    createdAt: new Date(),
  };

  const reference = await db
    .collection('characters')
    .add(characterData);

  return {
    id: reference.id,
    ...characterData,
  };
}

async function getCharactersByOwner(ownerId) {
  const snapshot = await db
    .collection('characters')
    .where('ownerId', '==', ownerId)
    .get();

  return snapshot.docs.map((doc) => ({
    id: doc.id,
    ...doc.data(),
  }));
}

module.exports = {
  createCharacter,
  getCharactersByOwner,
};