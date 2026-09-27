const { db } = require('../config/firebase');
const { createBattleService } = require('../services/battle.service');
const service = createBattleService(db);

function handler(operation, status = 200) {
  return async (req, res) => {
    res.set('Cache-Control', 'no-store');
    try { return res.status(status).json(await operation(req)); }
    catch (error) {
      if (error.status) return res.status(error.status).json({ error: error.message, code: error.code });
      console.error('Erro na batalha:', error.message);
      return res.status(500).json({ error: 'Não foi possível processar a batalha. Atualize o estado e tente novamente.' });
    }
  };
}
module.exports = {
  enemies: handler(() => service.listEnemies()),
  start: handler(req => service.startBattle(req.user.uid, { characterId: req.body?.characterId, enemyId: req.body?.enemyId }), 201),
  get: handler(req => service.getBattle(req.user.uid, req.params.id)),
  latest: handler(req => service.latestBattle(req.user.uid, req.params.id)),
  play: handler(req => service.command(req.user.uid, req.params.id, 'play-card', { expectedVersion: req.body?.expectedVersion, cardId: req.body?.cardId, target: req.body?.target })),
  ultimate: handler(req => service.command(req.user.uid, req.params.id, 'play-ultimate', { expectedVersion: req.body?.expectedVersion, target: req.body?.target })),
  end: handler(req => service.command(req.user.uid, req.params.id, 'end-turn', { expectedVersion: req.body?.expectedVersion })),
};
