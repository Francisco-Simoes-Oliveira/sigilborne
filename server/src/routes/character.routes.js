const express = require('express');

const authenticate =
    require('../middleware/auth.middleware');

const {
  create,
  listMine,
} = require('../controllers/character.controller');

const router = express.Router();

router.get(
  '/characters',
  authenticate,
  listMine,
);

router.post(
  '/characters',
  authenticate,
  create,
);

module.exports = router;