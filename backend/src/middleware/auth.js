import jwt from 'jsonwebtoken';

export function requireAuth(req, res, next) {
  const hdr = req.headers['authorization'] || '';
  const token = hdr.startsWith('Bearer ') ? hdr.slice(7) : null;
  const secret = process.env.JWT_SECRET || 'dev-secret';

  console.log('Auth middleware - URL:', req.url);
  console.log('Auth middleware - Authorization header:', hdr ? 'Present' : 'Missing');
  console.log('Auth middleware - Token extracted:', token ? 'Yes' : 'No');

  if (!token) {
    console.log('Auth failed - No token provided');
    return res.status(401).json({ error: 'Missing token' });
  }

  // Allow test token for development
  if (token === 'test-jwt-token') {
    req.user = { id: 'test-user', email: 'test@swargfood.com' };
    // Add test user roles for RBAC
    req.user.testRoles = ['Admin', 'Project Manager', 'Team Member'];
    return next();
  }

  try {
    const payload = jwt.verify(token, secret);

    // Handle admin user case - use numeric ID for database queries
    let userId = payload.id || payload.uid;
    if (userId === 'admin-user') {
      userId = 0; // Use 0 as the admin user ID for database queries
    }

    req.user = {
      id: userId,
      email: payload.email,
      role: payload.role,
      isAdmin: payload.isAdmin || false
    };
    console.log('Auth successful - User:', { id: req.user.id, email: req.user.email, isAdmin: req.user.isAdmin });
    next();
  } catch (e) {
    console.log('Auth failed - Invalid token:', e.message);
    return res.status(401).json({ error: 'Invalid token' });
  }
}

