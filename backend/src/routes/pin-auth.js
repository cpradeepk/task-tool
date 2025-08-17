import express from 'express';
import { authenticateWithPin, createUserWithPin, hasPin, updateUserPin } from '../services/pin-auth.js';
import { requireAuth } from '../middleware/auth.js';

const router = express.Router();

// Check if user has PIN set up
router.post('/check', async (req, res) => {
  try {
    const { email } = req.body;
    
    if (!email) {
      return res.status(400).json({ error: 'Email required' });
    }
    
    const hasPinSet = await hasPin(email);
    res.json({ hasPin: hasPinSet });
  } catch (err) {
    console.error('PIN check error:', err);
    res.status(500).json({ error: 'Failed to check PIN status' });
  }
});

// Login with email and PIN
router.post('/login', async (req, res) => {
  try {
    const { email, pin } = req.body;
    
    if (!email || !pin) {
      return res.status(400).json({ error: 'Email and PIN required' });
    }
    
    if (!/^\d{4,6}$/.test(pin)) {
      return res.status(400).json({ error: 'PIN must be 4-6 digits' });
    }
    
    const result = await authenticateWithPin(email, pin);
    res.json(result);
  } catch (err) {
    console.error('PIN login error:', err);
    res.status(401).json({ error: err.message });
  }
});

// Register new user with PIN
router.post('/register', async (req, res) => {
  try {
    const { email, pin } = req.body;
    
    if (!email || !pin) {
      return res.status(400).json({ error: 'Email and PIN required' });
    }
    
    if (!/^\d{4,6}$/.test(pin)) {
      return res.status(400).json({ error: 'PIN must be 4-6 digits' });
    }
    
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return res.status(400).json({ error: 'Invalid email format' });
    }
    
    // Check if user already exists
    const existingPin = await hasPin(email);
    if (existingPin) {
      return res.status(409).json({ error: 'User already exists with PIN' });
    }
    
    const user = await createUserWithPin(email, pin);
    
    // Generate token for immediate login
    const result = await authenticateWithPin(email, pin);
    res.status(201).json(result);
  } catch (err) {
    console.error('PIN registration error:', err);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// Update PIN (requires authentication)
router.post('/update', requireAuth, async (req, res) => {
  try {
    const { newPin } = req.body;
    
    if (!newPin || !/^\d{4,6}$/.test(newPin)) {
      return res.status(400).json({ error: 'New PIN must be 4-6 digits' });
    }
    
    await updateUserPin(req.user.id, newPin);
    res.json({ message: 'PIN updated successfully' });
  } catch (err) {
    console.error('PIN update error:', err);
    res.status(500).json({ error: 'Failed to update PIN' });
  }
});

export default router;
