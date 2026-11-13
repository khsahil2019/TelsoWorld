const jwt = require('jsonwebtoken');
const db = require('../db');

const JWT_SECRET = process.env.JWT_SECRET || 'telsoworld-super-secret-key-2026';

function generateToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '90d' });
}

// Required authentication
async function authRequired(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (!authHeader) {
    return res.status(401).json({
      status: false,
      message: 'Authentication token required (Bearer <token>)',
    });
  }

  const parts = authHeader.split(' ');
  const token = parts.length === 2 ? parts[1] : parts[0];

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await db.findUserById(decoded.id);
    if (!user) {
      return res.status(401).json({
        status: false,
        message: 'Invalid session: User not found',
      });
    }
    if (user.status === 'banned') {
      return res.status(403).json({
        status: false,
        message: 'Your account has been suspended by the administrator',
      });
    }
    req.user = user;
    next();
  } catch (err) {
    return res.status(401).json({
      status: false,
      message: 'Invalid or expired authentication token',
    });
  }
}

// Optional authentication: extracts user if token exists, but doesn't block guests
async function authOptional(req, res, next) {
  const authHeader = req.headers['authorization'];
  if (authHeader) {
    const parts = authHeader.split(' ');
    const token = parts.length === 2 ? parts[1] : parts[0];
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      req.user = await db.findUserById(decoded.id);
    } catch (_) {
      req.user = null;
    }
  } else {
    req.user = null;
  }
  next();
}

// Admin authentication middleware
function adminRequired(req, res, next) {
  const authHeader = req.headers['authorization'];
  const tokenFromQuery = req.query.admin_token;
  const token = tokenFromQuery || (authHeader ? (authHeader.split(' ')[1] || authHeader) : null);

  if (!token) {
    return res.status(401).json({ status: false, message: 'Admin authentication required' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    if (decoded.role !== 'admin') {
      return res.status(403).json({ status: false, message: 'Access denied: Admin privileges required' });
    }
    req.admin = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ status: false, message: 'Invalid or expired admin token' });
  }
}

module.exports = {
  JWT_SECRET,
  generateToken,
  authRequired,
  authOptional,
  adminRequired,
};

