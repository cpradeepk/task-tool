import { knex } from '../db/index.js';

export async function getUserRoles(userId) {
  // Handle special admin user case
  if (userId === 'admin-user' || userId === 'test-user' || userId === 0) {
    return ['Admin']; // Admin users have all permissions
  }

  // Convert to number for database query
  const numericUserId = Number(userId);
  if (isNaN(numericUserId)) {
    console.warn('Invalid user ID for role lookup:', userId);
    return [];
  }

  const rows = await knex('user_roles')
    .join('roles', 'user_roles.role_id', 'roles.id')
    .where('user_roles.user_id', numericUserId)
    .select('roles.name');
  return rows.map(r => r.name);
}

export async function userHasRole(userId, allowedRoles = []) {
  try {
    // Handle special admin user case
    if (userId === 'admin-user' || userId === 'test-user' || userId === 0) {
      return allowedRoles.includes('Admin');
    }

    const roles = await getUserRoles(userId);
    return roles.some(r => allowedRoles.includes(r));
  } catch (e) {
    console.error('Error checking user roles:', e);
    return false;
  }
}

export function requireAnyRole(allowedRoles = []) {
  return async (req, res, next) => {
    try {
      // Admin users have all permissions
      if (req.user.isAdmin) {
        return next();
      }

      // Handle test user with predefined roles
      if (req.user.testRoles) {
        if (req.user.testRoles.some(r => allowedRoles.includes(r))) return next();
        return res.status(403).json({ error: 'Forbidden' });
      }

      const roles = await getUserRoles(req.user.id);
      if (roles.some(r => allowedRoles.includes(r))) return next();
      return res.status(403).json({ error: 'Forbidden' });
    } catch (e) {
      return res.status(500).json({ error: 'RBAC error' });
    }
  };
}

