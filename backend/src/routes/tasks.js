const express = require('express');
const { authenticateToken } = require('../middleware/auth');
const taskController = require('../controllers/taskController');

const router = express.Router();

// Task CRUD routes
router.get('/', authenticateToken, taskController.getTasks);
router.post('/', authenticateToken, taskController.createTask);
router.get('/:id', authenticateToken, taskController.getTask);
router.put('/:id', authenticateToken, taskController.updateTask);
router.delete('/:id', authenticateToken, taskController.deleteTask);

// Task dependency routes
router.post('/:id/dependencies', authenticateToken, taskController.addTaskDependency);
router.delete('/:id/dependencies/:dependencyId', authenticateToken, taskController.removeTaskDependency);

// Task comment routes
router.post('/:id/comments', authenticateToken, taskController.addComment);

// Task time tracking routes
router.post('/:id/time-entries', authenticateToken, taskController.addTimeEntry);

module.exports = router;
