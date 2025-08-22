import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';
import { requireAnyRole, userHasRole } from '../middleware/rbac.js';

const router = express.Router();
router.use(requireAuth);

// Get all WFH requests (admin/manager) or user's own requests
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { status, employee_id, date, start_date, end_date } = req.query;
    
    // Check if user has admin/manager access
    const hasAccess = await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
    
    let query = knex('wfh_requests')
      .select(
        'wfh_requests.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'wfh_requests.employee_id', 'users.id')
      .leftJoin('users as approver', 'wfh_requests.approved_by', 'approver.id')
      .orderBy('wfh_requests.created_at', 'desc');
    
    // If not admin/manager, only show user's own requests
    if (!hasAccess) {
      query = query.where('wfh_requests.employee_id', userId);
    } else if (employee_id) {
      query = query.where('wfh_requests.employee_id', employee_id);
    }
    
    // Apply filters
    if (status) {
      query = query.where('wfh_requests.status', status);
    }
    
    if (date) {
      query = query.where('wfh_requests.date', date);
    }
    
    if (start_date && end_date) {
      query = query.whereBetween('wfh_requests.date', [start_date, end_date]);
    }
    
    const wfhRequests = await query;
    res.json(wfhRequests);
  } catch (err) {
    console.error('Error fetching WFH requests:', err);
    res.status(500).json({ error: 'Failed to fetch WFH requests' });
  }
});

// Get specific WFH request details
router.get('/:id', async (req, res) => {
  try {
    const wfhId = parseInt(req.params.id);
    const userId = req.user.id;
    
    const wfhRequest = await knex('wfh_requests')
      .select(
        'wfh_requests.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'wfh_requests.employee_id', 'users.id')
      .leftJoin('users as approver', 'wfh_requests.approved_by', 'approver.id')
      .where('wfh_requests.id', wfhId)
      .first();
    
    if (!wfhRequest) {
      return res.status(404).json({ error: 'WFH request not found' });
    }
    
    // Check if user can access this request
    const hasAccess = wfhRequest.employee_id === userId || 
                     await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
    
    if (!hasAccess) {
      return res.status(403).json({ error: 'Access denied' });
    }
    
    res.json(wfhRequest);
  } catch (err) {
    console.error('Error fetching WFH request:', err);
    res.status(500).json({ error: 'Failed to fetch WFH request' });
  }
});

// Apply for WFH
router.post('/', async (req, res) => {
  try {
    const userId = req.user.id;
    const { date, reason } = req.body;
    
    // Validation
    if (!date) {
      return res.status(400).json({ error: 'Date is required' });
    }
    
    // Validate date is not in the past
    const requestDate = new Date(date);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    if (requestDate < today) {
      return res.status(400).json({ 
        error: 'Cannot request WFH for past dates' 
      });
    }
    
    // Check if user already has a WFH request for this date
    const existingRequest = await knex('wfh_requests')
      .where('employee_id', userId)
      .where('date', date)
      .where('status', '!=', 'rejected')
      .first();
    
    if (existingRequest) {
      return res.status(400).json({ 
        error: 'You already have a WFH request for this date' 
      });
    }
    
    const [wfhId] = await knex('wfh_requests').insert({
      employee_id: userId,
      date,
      reason,
      status: 'pending'
    }).returning('id');
    
    const newWfhRequest = await knex('wfh_requests')
      .select(
        'wfh_requests.*',
        'users.email as employee_email',
        'users.name as employee_name'
      )
      .leftJoin('users', 'wfh_requests.employee_id', 'users.id')
      .where('wfh_requests.id', wfhId)
      .first();
    
    res.status(201).json(newWfhRequest);
  } catch (err) {
    console.error('Error applying for WFH:', err);
    res.status(500).json({ error: 'Failed to apply for WFH' });
  }
});

// Approve WFH request
router.put('/:id/approve', requireAnyRole(['Admin', 'Manager', 'Team Lead']), async (req, res) => {
  try {
    const wfhId = parseInt(req.params.id);
    const userId = req.user.id;
    const { comments } = req.body;
    
    const wfhRequest = await knex('wfh_requests').where('id', wfhId).first();
    if (!wfhRequest) {
      return res.status(404).json({ error: 'WFH request not found' });
    }
    
    if (wfhRequest.status !== 'pending') {
      return res.status(400).json({ 
        error: 'WFH request has already been processed' 
      });
    }
    
    await knex('wfh_requests')
      .where('id', wfhId)
      .update({
        status: 'approved',
        approved_by: userId,
        approved_at: knex.fn.now(),
        comments
      });
    
    const updatedWfhRequest = await knex('wfh_requests')
      .select(
        'wfh_requests.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'wfh_requests.employee_id', 'users.id')
      .leftJoin('users as approver', 'wfh_requests.approved_by', 'approver.id')
      .where('wfh_requests.id', wfhId)
      .first();
    
    res.json(updatedWfhRequest);
  } catch (err) {
    console.error('Error approving WFH request:', err);
    res.status(500).json({ error: 'Failed to approve WFH request' });
  }
});

// Reject WFH request
router.put('/:id/reject', requireAnyRole(['Admin', 'Manager', 'Team Lead']), async (req, res) => {
  try {
    const wfhId = parseInt(req.params.id);
    const userId = req.user.id;
    const { comments } = req.body;
    
    const wfhRequest = await knex('wfh_requests').where('id', wfhId).first();
    if (!wfhRequest) {
      return res.status(404).json({ error: 'WFH request not found' });
    }
    
    if (wfhRequest.status !== 'pending') {
      return res.status(400).json({ 
        error: 'WFH request has already been processed' 
      });
    }
    
    await knex('wfh_requests')
      .where('id', wfhId)
      .update({
        status: 'rejected',
        approved_by: userId,
        approved_at: knex.fn.now(),
        comments
      });
    
    const updatedWfhRequest = await knex('wfh_requests')
      .select(
        'wfh_requests.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'wfh_requests.employee_id', 'users.id')
      .leftJoin('users as approver', 'wfh_requests.approved_by', 'approver.id')
      .where('wfh_requests.id', wfhId)
      .first();
    
    res.json(updatedWfhRequest);
  } catch (err) {
    console.error('Error rejecting WFH request:', err);
    res.status(500).json({ error: 'Failed to reject WFH request' });
  }
});

// Get user-specific WFH requests
router.get('/user/:employeeId', async (req, res) => {
  try {
    const employeeId = req.params.employeeId;
    const userId = req.user.id;
    
    // Check if user can access other user's requests
    if (employeeId !== userId) {
      const hasAccess = await userHasRole(userId, ['Admin', 'Manager', 'Team Lead']);
      if (!hasAccess) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }
    
    const wfhRequests = await knex('wfh_requests')
      .select(
        'wfh_requests.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'wfh_requests.employee_id', 'users.id')
      .leftJoin('users as approver', 'wfh_requests.approved_by', 'approver.id')
      .where('wfh_requests.employee_id', employeeId)
      .orderBy('wfh_requests.created_at', 'desc');
    
    res.json(wfhRequests);
  } catch (err) {
    console.error('Error fetching user WFH requests:', err);
    res.status(500).json({ error: 'Failed to fetch user WFH requests' });
  }
});

// Get WFH statistics
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
    const currentMonth = new Date().getMonth() + 1;
    const currentYear = new Date().getFullYear();
    
    // Get WFH statistics for current month
    const [totalRequests] = await knex('wfh_requests')
      .where('employee_id', targetUserId)
      .whereRaw('EXTRACT(MONTH FROM date) = ?', [currentMonth])
      .whereRaw('EXTRACT(YEAR FROM date) = ?', [currentYear])
      .count('* as count');
    
    const [approvedRequests] = await knex('wfh_requests')
      .where('employee_id', targetUserId)
      .where('status', 'approved')
      .whereRaw('EXTRACT(MONTH FROM date) = ?', [currentMonth])
      .whereRaw('EXTRACT(YEAR FROM date) = ?', [currentYear])
      .count('* as count');
    
    const [pendingRequests] = await knex('wfh_requests')
      .where('employee_id', targetUserId)
      .where('status', 'pending')
      .whereRaw('EXTRACT(MONTH FROM date) = ?', [currentMonth])
      .whereRaw('EXTRACT(YEAR FROM date) = ?', [currentYear])
      .count('* as count');
    
    // Get upcoming approved WFH days
    const upcomingWfh = await knex('wfh_requests')
      .where('employee_id', targetUserId)
      .where('status', 'approved')
      .where('date', '>=', knex.fn.now())
      .orderBy('date', 'asc')
      .limit(5);
    
    res.json({
      month: currentMonth,
      year: currentYear,
      total_requests: parseInt(totalRequests.count),
      approved_requests: parseInt(approvedRequests.count),
      pending_requests: parseInt(pendingRequests.count),
      upcoming_wfh_days: upcomingWfh,
    });
  } catch (err) {
    console.error('Error fetching WFH statistics:', err);
    res.status(500).json({ error: 'Failed to fetch WFH statistics' });
  }
});

// Bulk approve/reject WFH requests
router.put('/bulk/:action', requireAnyRole(['Admin', 'Manager', 'Team Lead']), async (req, res) => {
  try {
    const action = req.params.action; // 'approve' or 'reject'
    const userId = req.user.id;
    const { request_ids, comments } = req.body;
    
    if (!['approve', 'reject'].includes(action)) {
      return res.status(400).json({ error: 'Invalid action' });
    }
    
    if (!request_ids || !Array.isArray(request_ids) || request_ids.length === 0) {
      return res.status(400).json({ error: 'request_ids array is required' });
    }
    
    const status = action === 'approve' ? 'approved' : 'rejected';
    
    // Update all specified requests
    await knex('wfh_requests')
      .whereIn('id', request_ids)
      .where('status', 'pending')
      .update({
        status,
        approved_by: userId,
        approved_at: knex.fn.now(),
        comments
      });
    
    // Get updated requests
    const updatedRequests = await knex('wfh_requests')
      .select(
        'wfh_requests.*',
        'users.email as employee_email',
        'users.name as employee_name',
        'approver.email as approved_by_email',
        'approver.name as approved_by_name'
      )
      .leftJoin('users', 'wfh_requests.employee_id', 'users.id')
      .leftJoin('users as approver', 'wfh_requests.approved_by', 'approver.id')
      .whereIn('wfh_requests.id', request_ids);
    
    res.json({
      success: true,
      message: `${updatedRequests.length} WFH requests ${action}d successfully`,
      updated_requests: updatedRequests
    });
  } catch (err) {
    console.error(`Error bulk ${req.params.action}ing WFH requests:`, err);
    res.status(500).json({ error: `Failed to bulk ${req.params.action} WFH requests` });
  }
});

export default router;
