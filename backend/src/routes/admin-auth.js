import express from 'express';
import jwt from 'jsonwebtoken';

const router = express.Router();

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';
const ADMIN_USERNAME = process.env.ADMIN_USERNAME || 'admin';
const ADMIN_PASSWORD = process.env.ADMIN_PASSWORD || 'admin123';

router.post('/login', async (req, res) => {
  try {
    const { username, password } = req.body;

    console.log('Admin login attempt:', { username, hasPassword: !!password });

    if (!username || !password) {
      return res.status(400).json({ error: 'Username and password required' });
    }

    // Check admin credentials
    console.log('Checking credentials against:', { ADMIN_USERNAME, ADMIN_PASSWORD: '***' });

    if (username === ADMIN_USERNAME && password === ADMIN_PASSWORD) {
      // Create admin JWT token
      const token = jwt.sign(
        {
          id: 0,
          uid: 'admin-user',
          email: ADMIN_USERNAME,
          role: 'admin',
          isAdmin: true
        },
        JWT_SECRET,
        { expiresIn: '8h' }
      );

      console.log('Admin login successful, token generated');

      res.json({
        token,
        user: {
          id: 0,
          email: ADMIN_USERNAME,
          role: 'admin',
          isAdmin: true
        }
      });
    } else {
      res.status(401).json({ error: 'Invalid admin credentials' });
    }
  } catch (err) {
    console.error('Admin auth error', err);
    res.status(500).json({ error: 'Authentication failed' });
  }
});

export default router;
