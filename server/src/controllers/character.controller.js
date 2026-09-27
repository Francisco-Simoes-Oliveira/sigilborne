const {
  createCharacter,
  getCharactersByOwner,
} = require('../services/character.service');

async function create(req, res) {
  try {
    const uid = req.user.uid;

    const {
      name,
      classId,
    } = req.body;

    if (!name || name.trim().length < 3) {
      return res.status(400).json({
        error:
            'O personagem precisa ter um nome com pelo menos 3 caracteres.',
      });
    }

    if (!classId) {
      return res.status(400).json({
        error: 'Classe não informada.',
      });
    }

    const character = await createCharacter({
      ownerId: uid,
      name,
      classId,
    });

    return res.status(201).json(character);
  } catch (error) {
    if (error.message === 'CLASS_NOT_FOUND') {
      return res.status(400).json({
        error: 'Classe inválida.',
      });
    }

    console.error(
      'Erro ao criar personagem:',
      error,
    );

    return res.status(500).json({
      error: 'Erro interno do servidor.',
    });
  }
}

async function listMine(req, res) {
  try {
    const uid = req.user.uid;

    const characters =
        await getCharactersByOwner(uid);

    return res.json({
      characters,
    });
  } catch (error) {
    console.error(
      'Erro ao buscar personagens:',
      error,
    );

    return res.status(500).json({
      error: 'Erro interno do servidor.',
    });
  }
}

module.exports = {
  create,
  listMine,
};