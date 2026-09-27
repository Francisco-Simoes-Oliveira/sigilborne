const express = require('express');
const authenticate = require('../middleware/auth.middleware');
const controller = require('../controllers/battle.controller');
const router = express.Router();

router.get('/enemies', authenticate, controller.enemies);
router.get('/characters/:id/latest-battle', authenticate, controller.latest);
router.post('/battles', authenticate, controller.start);
router.get('/battles/:id', authenticate, controller.get);
router.post('/battles/:id/play-card', authenticate, controller.play);
router.post('/battles/:id/play-ultimate', authenticate, controller.ultimate);
router.post('/battles/:id/end-turn', authenticate, controller.end);

module.exports = router;
