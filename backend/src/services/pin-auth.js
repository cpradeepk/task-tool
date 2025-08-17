import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import knex from '../db/index.js';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';
const MAX_PIN_ATTEMPTS = 5;
const LOCKOUT_DURATION = 15 * 60 * 1000; // 15 minutes

export async function createUserWithPin(email, pin) {
  const pinHash = await bcrypt.hash(pin, 10);
  
  const [user] = await knex('users')
    .insert({
      email,
      pin_hash: pinHash,
      pin_created_at: new Date(),
      created_at: new Date(),
      updated_at: new Date()
    })
    .returning('*');
    
  return user;
}

export async function authenticateWithPin(email, pin) {
  const user = await knex('users')
    .where({ email })
    .first();
    
  if (!user || !user.pin_hash) {
    throw new Error('User not found or PIN not set');
  }
  
  // Check if account is locked
  if (user.pin_locked_until && new Date() < new Date(user.pin_locked_until)) {
    const lockoutMinutes = Math.ceil((new Date(user.pin_locked_until) - new Date()) / 60000);
    throw new Error(`Account locked. Try again in ${lockoutMinutes} minutes`);
  }
  
  // Verify PIN
  const isValidPin = await bcrypt.compare(pin, user.pin_hash);
  
  if (!isValidPin) {
    // Increment failed attempts
    const attempts = (user.pin_attempts || 0) + 1;
    const updateData = { pin_attempts: attempts };
    
    // Lock account if max attempts reached
    if (attempts >= MAX_PIN_ATTEMPTS) {
      updateData.pin_locked_until = new Date(Date.now() + LOCKOUT_DURATION);
    }
    
    await knex('users')
      .where({ id: user.id })
      .update(updateData);
      
    if (attempts >= MAX_PIN_ATTEMPTS) {
      throw new Error('Account locked due to too many failed attempts');
    }
    
    throw new Error(`Invalid PIN. ${MAX_PIN_ATTEMPTS - attempts} attempts remaining`);
  }
  
  // Reset attempts on successful login
  await knex('users')
    .where({ id: user.id })
    .update({
      pin_attempts: 0,
      pin_locked_until: null,
      pin_last_used: new Date()
    });
    
  // Generate JWT token
  const token = jwt.sign(
    { uid: user.id, email: user.email },
    JWT_SECRET,
    { expiresIn: '24h' }
  );
  
  return { token, user: { id: user.id, email: user.email } };
}

export async function updateUserPin(userId, newPin) {
  const pinHash = await bcrypt.hash(newPin, 10);
  
  await knex('users')
    .where({ id: userId })
    .update({
      pin_hash: pinHash,
      pin_created_at: new Date(),
      pin_attempts: 0,
      pin_locked_until: null,
      updated_at: new Date()
    });
    
  return true;
}

export async function hasPin(email) {
  const user = await knex('users')
    .where({ email })
    .select('pin_hash')
    .first();
    
  return !!(user && user.pin_hash);
}
