const express = require('express');

const authenticate = require('../middleware/auth.middleware');
const {
  getMe,
} = require('../controllers/user.controller');

const router = express.Router();

router.get(
  '/me',
  authenticate,
  getMe,
);

module.exports = router;