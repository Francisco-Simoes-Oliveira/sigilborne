const { db } = require('../config/firebase');
const { createDeckService } = require('../services/deck.service');
const deckService = createDeckService(db);

async function getDeck(req, res) {
  // This GET can attach a starter deck to a legacy character. Never cache it.
  res.set('Cache-Control', 'no-store');
  try {
    const deck = await deckService.getCharacterDeck(req.user.uid, req.params.id);
    return res.json({ deck });
  } catch (error) {
    if (error.status) {
      return res.status(error.status).json({ error: error.message, code: error.code });
    }
    console.error('Erro ao buscar deck:', error.message);
    return res.status(500).json({ error: 'Não foi possível carregar o deck. Tente novamente.' });
  }
}

module.exports = { getDeck };
