import express from 'express';
import { requireAuth } from '../middleware/auth.js';
import { knex } from '../db/index.js';

const router = express.Router();

// All routes require authentication
router.use(requireAuth);

// Get all WFH requests
router.get('/', async (req, res) => {
  try {
    const { status, user_id } = req.query;
    
    let query = knex('wfh_requests')
      .leftJoin('users', 'wfh_requests.user_id', 'users.id')
      .select(
        'wfh_requests.*',
        'users.name as user_name',
        'users.email as user_email'
      )
      .orderBy('wfh_requests.created_at', 'desc');
    
    if (status) {
      query = query.where('wfh_requests.status', status);
    }
    
    if (user_id) {
      query = query.where('wfh_requests.user_id', user_id);
    }
    
    const wfhRequests = await query;
    res.json(wfhRequests);
  } catch (err) {
    console.error('Get WFH requests error:', err);
    res.status(500).json({ error: 'Failed to fetch WFH requests' });
  }
});

// Get WFH request by ID
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const wfhRequest = await knex('wfh_requests')
      .leftJoin('users', 'wfh_requests.user_id', 'users.id')
      .where('wfh_requests.id', id)
      .select(
        'wfh_requests.*',
        'users.name as user_name',
        'users.email as user_email'
      )
      .first();
    
    if (!wfhRequest) {
      return res.status(404).json({ error: 'WFH request not found' });
    }
    
    res.json(wfhRequest);
  } catch (err) {
    console.error('Get WFH request error:', err);
    res.status(500).json({ error: 'Failed to fetch WFH request' });
  }
});

// Create WFH request
router.post('/', async (req, res) => {
  try {
    const { date, reason, is_full_day, start_time, end_time } = req.body;
    const userId = req.user.id;
    
    if (!date) {
      return res.status(400).json({ error: 'Date is required' });
    }
    
    if (!is_full_day && (!start_time || !end_time)) {
      return res.status(400).json({ error: 'Start time and end time are required for partial day WFH' });
    }
    
    const [wfhRequest] = await knex('wfh_requests')
      .insert({
        user_id: userId,
        date,
        reason,
        is_full_day: is_full_day || false,
        start_time: is_full_day ? null : start_time,
        end_time: is_full_day ? null : end_time,
        status: 'pending',
        created_at: new Date()
      })
      .returning('*');
    
    res.status(201).json(wfhRequest);
  } catch (err) {
    console.error('Create WFH request error:', err);
    res.status(500).json({ error: 'Failed to create WFH request' });
  }
});

// Update WFH request status
router.put('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, admin_comments } = req.body;
    const adminId = req.user.id;
    
    if (!['approved', 'rejected'].includes(status)) {
      return res.status(400).json({ error: 'Status must be approved or rejected' });
    }
    
    const [wfhRequest] = await knex('wfh_requests')
      .where('id', id)
      .update({
        status,
        admin_comments,
        approved_by: adminId,
        approved_at: new Date(),
        updated_at: new Date()
      })
      .returning('*');
    
    if (!wfhRequest) {
      return res.status(404).json({ error: 'WFH request not found' });
    }
    
    res.json(wfhRequest);
  } catch (err) {
    console.error('Update WFH request status error:', err);
    res.status(500).json({ error: 'Failed to update WFH request status' });
  }
});

// Delete WFH request
router.delete('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id;
    
    // Users can only delete their own pending requests
    const wfhRequest = await knex('wfh_requests')
      .where('id', id)
      .first();
    
    if (!wfhRequest) {
      return res.status(404).json({ error: 'WFH request not found' });
    }
    
    if (wfhRequest.user_id !== userId && !req.user.isAdmin) {
      return res.status(403).json({ error: 'Not authorized to delete this WFH request' });
    }
    
    if (wfhRequest.status !== 'pending') {
      return res.status(400).json({ error: 'Can only delete pending WFH requests' });
    }
    
    await knex('wfh_requests')
      .where('id', id)
      .del();
    
    res.json({ message: 'WFH request deleted successfully' });
  } catch (err) {
    console.error('Delete WFH request error:', err);
    res.status(500).json({ error: 'Failed to delete WFH request' });
  }
});

export default router;
