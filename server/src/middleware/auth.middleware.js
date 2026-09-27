const { auth } = require('../config/firebase');

async function authenticate(req, res, next) {
  try {
    const authorization = req.headers.authorization;

    if (!authorization) {
      return res.status(401).json({
        error: 'Token de autenticação não informado.',
      });
    }

    if (!authorization.startsWith('Bearer ')) {
      return res.status(401).json({
        error: 'Formato de autenticação inválido.',
      });
    }

    const token = authorization.substring(7);

    const decodedToken = await auth.verifyIdToken(token);

    req.user = decodedToken;

    next();
  } catch (error) {
    console.error('Erro de autenticação:', error.message);

    return res.status(401).json({
      error: 'Token inválido ou expirado.',
    });
  }
}

module.exports = authenticate;