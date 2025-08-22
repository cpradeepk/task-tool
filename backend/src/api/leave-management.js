import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();

// All routes require authentication
router.use(requireAuth);

// Get all leave requests
router.get('/', async (req, res) => {
  try {
    const { status, user_id } = req.query;
    
    let query = knex('leave_requests')
      .leftJoin('users', 'leave_requests.user_id', 'users.id')
      .select(
        'leave_requests.*',
        'users.name as user_name',
        'users.email as user_email'
      )
      .orderBy('leave_requests.created_at', 'desc');
    
    if (status) {
      query = query.where('leave_requests.status', status);
    }
    
    if (user_id) {
      query = query.where('leave_requests.user_id', user_id);
    }
    
    const leaves = await query;
    res.json(leaves);
  } catch (err) {
    console.error('Get leave requests error:', err);
    res.status(500).json({ error: 'Failed to fetch leave requests' });
  }
});

// Get leave request by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const leave = await knex('leave_requests')
      .leftJoin('users', 'leave_requests.user_id', 'users.id')
      .where('leave_requests.id', id)
      .select(
        'leave_requests.*',
        'users.name as user_name',
        'users.email as user_email'
      )
      .first();
    
    if (!leave) {
      return res.status(404).json({ error: 'Leave request not found' });
    }
    
    res.json(leave);
  } catch (err) {
    console.error('Get leave request error:', err);
    res.status(500).json({ error: 'Failed to fetch leave request' });
  }
});

// Create leave request
router.post('/', async (req, res) => {
  try {
    const { start_date, end_date, leave_type, reason } = req.body;
    const userId = req.user.id;
    
    if (!start_date || !end_date || !leave_type) {
      return res.status(400).json({ error: 'Start date, end date, and leave type are required' });
    }
    
    const [leave] = await knex('leave_requests')
      .insert({
        user_id: userId,
        start_date,
        end_date,
        leave_type,
        reason,
        status: 'pending',
        created_at: new Date()
      })
      .returning('*');
    
    res.status(201).json(leave);
  } catch (err) {
    console.error('Create leave request error:', err);
    res.status(500).json({ error: 'Failed to create leave request' });
  }
});

// Update leave request status
router.put('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, admin_comments } = req.body;
    const adminId = req.user.id;
    
    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'Status must be approved or rejected' });
    }
    
    const [leave] = await knex('leave_requests')
      .where('id', id)
      .update({
        status,
        admin_comments,
        approved_by: adminId,
        approved_at: new Date(),
        updated_at: new Date()
      })
      .returning('*');
    
    if (!leave) {
      return res.status(404).json({ error: 'Leave request not found' });
    }
    
    res.json(leave);
  } catch (err) {
    console.error('Update leave request status error:', err);
    res.status(500).json({ error: 'Failed to update leave request status' });
  }
});

// Delete leave request
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    
    // Users can only delete their own pending requests
    const leave = await knex('leave_requests')
      .where('id', id)
      .first();
    
    if (!leave) {
      return res.status(404).json({ error: 'Leave request not found' });
    }
    
    if (leave.user_id !== userId && !req.user.isAdmin) {
      return res.status(403).json({ error: 'Not authorized to delete this leave request' });
    }
    
    if (leave.status !== 'pending') {
      return res.status(400).json({ error: 'Can only delete pending leave requests' });
    }
    
    await knex('leave_requests')
      .where('id', id)
      .del();
    
    res.json({ message: 'Leave request deleted successfully' });
  } catch (err) {
    console.error('Delete leave request error:', err);
    res.status(500).json({ error: 'Failed to delete leave request' });
  }
});

export default router;
