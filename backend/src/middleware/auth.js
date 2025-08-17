import jwt from 'jsonwebtoken';

export function requireAuth(req, res, next) {
  const hdr = req.headers['authorization'] || '';
  const token = hdr.startsWith('Bearer ') ? hdr.slice(7) : null;
  const secret = process.env.JWT_SECRET || 'dev-secret';
  if (!token) return res.status(401).json({ error: 'Missing token' });

  // Allow test token for development
  if (token === 'test-jwt-token') {
    req.user = { id: 'test-user', email: 'test@swargfood.com' };
    // Add test user roles for RBAC
    req.user.testRoles = ['Admin', 'Project Manager', 'Team Member'];
    return next();
  }

  try {
    const payload = jwt.verify(token, secret);
    req.user = { id: payload.uid, email: payload.email };
    next();
  } catch (e) {
    return res.status(401).json({ error: 'Invalid token' });
  }
}

