const express = require('express');

const { db } = require('../config/firebase');
const authenticate =
    require('../middleware/auth.middleware');

const router = express.Router();

router.get(
  '/classes',
  authenticate,
  async (req, res) => {
    try {
      const snapshot =
          await db.collection('classes').get();

      const classes =
          snapshot.docs.map((doc) => ({
            id: doc.id,
            ...doc.data(),
          }));

      return res.json({
        classes,
      });
    } catch (error) {
      console.error(error);

      return res.status(500).json({
        error:
            'Erro ao buscar classes.',
      });
    }
  },
);

module.exports = router;