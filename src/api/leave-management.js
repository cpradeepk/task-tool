import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole, userHasRole } from '../middleware/rbac.js';

const router = express.Router();
router.use(requireAuth);

// Get all leaves (admin/manager) or user's own leaves
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { status, employee_id, start_date, end_date } = req.query;
    
    // Check if user has admin/manager access
    const hasAccess = await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
    
    let query = knex('leaves')
      .select(
        'leaves.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'leaves.employee_id', 'users.id')
      .leftJoin('users as approver', 'leaves.approved_by', 'approver.id')
      .orderBy('leaves.created_at', 'desc');
    
    // If not admin/manager, only show user's own leaves
    if (!hasAccess) {
      query = query.where('leaves.employee_id', userId);
    } else if (employee_id) {
      query = query.where('leaves.employee_id', employee_id);
    }
    
    // Apply filters
    if (status) {
      query = query.where('leaves.status', status);
    }
    
    if (start_date && end_date) {
      query = query.whereBetween('leaves.start_date', [start_date, end_date]);
    }
    
    const leaves = await query;
    res.json(leaves);
  } catch (err) {
    console.error('Error fetching leaves:', err);
    res.status(500).json({ error: 'Failed to fetch leaves' });
  }
});

// Get specific leave details
router.get('/:id', async (req, res) => {
  try {
    const leaveId = parseInt(req.params.id);
    const userId = req.user.id;
    
    const leave = await knex('leaves')
      .select(
        'leaves.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'leaves.employee_id', 'users.id')
      .leftJoin('users as approver', 'leaves.approved_by', 'approver.id')
      .where('leaves.id', leaveId)
      .first();
    
    if (!leave) {
      return res.status(404).json({ error: 'Leave not found' });
    }
    
    // Check if user can access this leave
    const hasAccess = leave.employee_id === userId || 
                     await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
    
    if (!hasAccess) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    res.json(leave);
  } catch (err) {
    console.error('Error fetching leave:', err);
    res.status(500).json({ error: 'Failed to fetch leave' });
  }
});

// Apply for leave
router.post('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { leave_type, start_date, end_date, reason } = req.body;
    
    // Validation
    if (!leave_type || !start_date || !end_date) {
      return res.status(400).json({ 
        error: 'Leave type, start date, and end date are required' 
      });
    }
    
    // Validate dates
    const startDate = new Date(start_date);
    const endDate = new Date(end_date);
    
    if (startDate >= endDate) {
      return res.status(400).json({ 
        error: 'End date must be after start date' 
      });
    }
    
    // Check for overlapping leaves
    const overlappingLeave = await knex('leaves')
      .where('employee_id', userId)
      .where('status', '!=', 'rejected')
      .where(function() {
        this.whereBetween('start_date', [start_date, end_date])
            .orWhereBetween('end_date', [start_date, end_date])
            .orWhere(function() {
              this.where('start_date', '<=', start_date)
                  .where('end_date', '>=', end_date);
            });
      })
      .first();
    
    if (overlappingLeave) {
      return res.status(400).json({ 
        error: 'You already have a leave request for overlapping dates' 
      });
    }
    
    const [leaveId] = await knex('leaves').insert({
      employee_id: userId,
      leave_type,
      start_date,
      end_date,
      reason,
      status: 'pending'
    }).returning('id');
    
    const newLeave = await knex('leaves')
      .select(
        'leaves.*',
        'users.email as employee_email',
        'users.name as employee_name'
      )
      .leftJoin('users', 'leaves.employee_id', 'users.id')
      .where('leaves.id', leaveId)
      .first();
    
    res.status(201).json(newLeave);
  } catch (err) {
    console.error('Error applying for leave:', err);
    res.status(500).json({ error: 'Failed to apply for leave' });
  }
});

// Approve leave request
router.put('/:id/approve', requireAnyRole(['Admin', 'Manager', 'Team Lead']), async (req, res) => {
  try {
    const leaveId = parseInt(req.params.id);
    const userId = req.user.id;
    const { comments } = req.body;
    
    const leave = await knex('leaves').where('id', leaveId).first();
    if (!leave) {
      return res.status(404).json({ error: 'Leave not found' });
    }
    
    if (leave.status !== 'pending') {
      return res.status(400).json({ 
        error: 'Leave request has already been processed' 
      });
    }
    
    await knex('leaves')
      .where('id', leaveId)
      .update({
        status: 'approved',
        approved_by: userId,
        approved_at: knex.fn.now(),
        comments
      });
    
    const updatedLeave = await knex('leaves')
      .select(
        'leaves.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'leaves.employee_id', 'users.id')
      .leftJoin('users as approver', 'leaves.approved_by', 'approver.id')
      .where('leaves.id', leaveId)
      .first();
    
    res.json(updatedLeave);
  } catch (err) {
    console.error('Error approving leave:', err);
    res.status(500).json({ error: 'Failed to approve leave' });
  }
});

// Reject leave request
router.put('/:id/reject', requireAnyRole(['Admin', 'Manager', 'Team Lead']), async (req, res) => {
  try {
    const leaveId = parseInt(req.params.id);
    const userId = req.user.id;
    const { comments } = req.body;
    
    const leave = await knex('leaves').where('id', leaveId).first();
    if (!leave) {
      return res.status(404).json({ error: 'Leave not found' });
    }
    
    if (leave.status !== 'pending') {
      return res.status(400).json({ 
        error: 'Leave request has already been processed' 
      });
    }
    
    await knex('leaves')
      .where('id', leaveId)
      .update({
        status: 'rejected',
        approved_by: userId,
        approved_at: knex.fn.now(),
        comments
      });
    
    const updatedLeave = await knex('leaves')
      .select(
        'leaves.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'leaves.employee_id', 'users.id')
      .leftJoin('users as approver', 'leaves.approved_by', 'approver.id')
      .where('leaves.id', leaveId)
      .first();
    
    res.json(updatedLeave);
  } catch (err) {
    console.error('Error rejecting leave:', err);
    res.status(500).json({ error: 'Failed to reject leave' });
  }
});

// Get user-specific leaves
router.get('/user/:employeeId', async (req, res) => {
  try {
    const employeeId = req.params.employeeId;
    const userId = req.user.id;
    
    // Check if user can access other user's leaves
    if (employeeId !== userId) {
      const hasAccess = await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }
    
    const leaves = await knex('leaves')
      .select(
        'leaves.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'leaves.employee_id', 'users.id')
      .leftJoin('users as approver', 'leaves.approved_by', 'approver.id')
      .where('leaves.employee_id', employeeId)
      .orderBy('leaves.created_at', 'desc');
    
    res.json(leaves);
  } catch (err) {
    console.error('Error fetching user leaves:', err);
    res.status(500).json({ error: 'Failed to fetch user leaves' });
  }
});

// Get leave statistics
router.get('/stats/summary', async (req, res) => {
  try {
    const userId = req.user.id;
    const { employee_id } = req.query;
    
    // Check if user has admin/manager access for other users
    if (employee_id && employee_id !== userId) {
      const hasAccess = await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }
    
    const targetUserId = employee_id || userId;
    const currentYear = new Date().getFullYear();
    
    // Get leave statistics for current year
    const [totalLeaves] = await knex('leaves')
      .where('employee_id', targetUserId)
      .whereRaw('EXTRACT(YEAR FROM start_date) = ?', [currentYear])
      .count('* as count');
    
    const [approvedLeaves] = await knex('leaves')
      .where('employee_id', targetUserId)
      .where('status', 'approved')
      .whereRaw('EXTRACT(YEAR FROM start_date) = ?', [currentYear])
      .count('* as count');
    
    const [pendingLeaves] = await knex('leaves')
      .where('employee_id', targetUserId)
      .where('status', 'pending')
      .whereRaw('EXTRACT(YEAR FROM start_date) = ?', [currentYear])
      .count('* as count');
    
    // Calculate total leave days taken
    const approvedLeaveDays = await knex('leaves')
      .where('employee_id', targetUserId)
      .where('status', 'approved')
      .whereRaw('EXTRACT(YEAR FROM start_date) = ?', [currentYear])
      .select('start_date', 'end_date');
    
    let totalDaysTaken = 0;
    approvedLeaveDays.forEach(leave => {
      const start = new Date(leave.start_date);
      const end = new Date(leave.end_date);
      const diffTime = Math.abs(end - start);
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24)) + 1;
      totalDaysTaken += diffDays;
    });
    
    res.json({
      year: currentYear,
      total_requests: parseInt(totalLeaves.count),
      approved_requests: parseInt(approvedLeaves.count),
      pending_requests: parseInt(pendingLeaves.count),
      total_days_taken: totalDaysTaken,
      remaining_days: Math.max(0, 30 - totalDaysTaken), // Assuming 30 days annual leave
    });
  } catch (err) {
    console.error('Error fetching leave statistics:', err);
    res.status(500).json({ error: 'Failed to fetch leave statistics' });
  }
});

export default router;
