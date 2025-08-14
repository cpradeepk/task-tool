import express from 'express';
import { OAuth2Client } from 'google-auth-library';
import jwt from 'jsonwebtoken';
import { User } from '../models/User.js';
import { knex } from '../db/index.js';

const router = express.Router();

const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID;
const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

const client = new OAuth2Client(GOOGLE_CLIENT_ID);

router.post('/session', async (req, res) => {
  try {
    const { idToken } = req.body;
    if (!idToken) return res.status(400).json({ error: 'idToken required' });

    const ticket = await client.verifyIdToken({ idToken, audience: GOOGLE_CLIENT_ID });
    const payload = ticket.getPayload();

    const email = payload.email;
    const sub = payload.sub;

    let user = await User.query().findOne({ email });
    if (!user) {
      user = await User.query().insert({ email, google_sub: sub, active: true });
    }

    // Ensure default role assignment (Team Member) exists
    const teamRole = await knex('roles').where({ name: 'Team Member' }).first();
    if (teamRole) {
      const existing = await knex('user_roles').where({ user_id: user.id, role_id: teamRole.id }).first();
      if (!existing) {
        await knex('user_roles').insert({ user_id: user.id, role_id: teamRole.id });
      }
    }

    const token = jwt.sign({ uid: user.id, email: user.email }, JWT_SECRET, { expiresIn: '1h' });
    res.json({ token, user: { id: user.id, email: user.email } });
  } catch (err) {
    console.error('Auth error', err);
    res.status(401).json({ error: 'Invalid token' });
  }
});

export default router;

