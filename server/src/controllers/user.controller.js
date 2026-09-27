const { db } = require('../config/firebase');

async function getMe(req, res) {
  try {
    const uid = req.user.uid;

    const document = await db
      .collection('users')
      .doc(uid)
      .get();

    if (!document.exists) {
      return res.status(404).json({
        error: 'Perfil do usuário não encontrado.',
      });
    }

    return res.json({
      uid,
      email: req.user.email,
      profile: document.data(),
    });
  } catch (error) {
    console.error('Erro ao buscar usuário:', error);

    return res.status(500).json({
      error: 'Erro interno do servidor.',
    });
  }
}

module.exports = {
  getMe,
};