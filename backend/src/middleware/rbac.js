import { knex } from '../db/index.js';

export async function getUserRoles(userId) {
  const rows = await knex('user_roles')
    .join('roles', 'user_roles.role_id', 'roles.id')
    .where('user_roles.user_id', userId)
    .select('roles.name');
  return rows.map(r => r.name);
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

