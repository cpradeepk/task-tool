import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class KanbanBoardScreen extends StatefulWidget {
  final int projectId;
  final int? moduleId;

  const KanbanBoardScreen({
    Key? key,
    required this.projectId,
    this.moduleId,
  }) : super(key: key);

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  List<dynamic> _tasks = [];
  List<dynamic> _statuses = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final jwt = await _getJwt();
      
      // Load tasks
      String tasksUrl;
      if (widget.moduleId != null) {
        tasksUrl = '$apiBase/task/api/projects/${widget.projectId}/modules/${widget.moduleId}/tasks';
      } else {
        tasksUrl = '$apiBase/task/api/projects/${widget.projectId}/tasks';
      }
      
      final tasksRes = await http.get(
        Uri.parse(tasksUrl),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      
      // Load statuses
      final statusesRes = await http.get(
        Uri.parse('$apiBase/task/api/statuses'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      
      setState(() {
        _tasks = jsonDecode(tasksRes.body) as List<dynamic>;
        _statuses = jsonDecode(statusesRes.body) as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      // Mock data for development
      _statuses = [
        {'id': 1, 'name': 'Open', 'color': '#9E9E9E'},
        {'id': 2, 'name': 'In Progress', 'color': '#FF9800'},
        {'id': 3, 'name': 'Completed', 'color': '#4CAF50'},
        {'id': 4, 'name': 'Cancelled', 'color': '#757575'},
        {'id': 5, 'name': 'Hold', 'color': '#795548'},
        {'id': 6, 'name': 'Delayed', 'color': '#F44336'},
      ];
      
      _tasks = [
        {
          'id': 1,
          'title': 'Implement user authentication',
          'description': 'Create login and registration functionality',
          'status_id': 2,
          'priority': 'High',
          'assigned_to': 'John Doe',
          'due_date': '2025-01-20',
        },
        {
          'id': 2,
          'title': 'Design dashboard layout',
          'description': 'Create responsive dashboard interface',
          'status_id': 1,
          'priority': 'Medium',
          'assigned_to': 'Jane Smith',
          'due_date': '2025-01-22',
        },
        {
          'id': 3,
          'title': 'Setup database schema',
          'description': 'Create tables and relationships',
          'status_id': 3,
          'priority': 'High',
          'assigned_to': 'Mike Johnson',
          'due_date': '2025-01-18',
        },
      ];
      
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Kanban Board - Project ${widget.projectId}'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.view_list),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Switch to List View',
          ),
        ],
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _statuses.map((status) => _buildKanbanColumn(status)).toList(),
        ),
      ),
    );
  }

  Widget _buildKanbanColumn(Map<String, dynamic> status) {
    final statusTasks = _tasks.where((task) => task['status_id'] == status['id']).toList();
    final statusColor = Color(int.parse(status['color'].substring(1), radix: 16) + 0xFF000000);

    return Container(
      width: 300,
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${statusTasks.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Tasks in this column
          Container(
            constraints: const BoxConstraints(minHeight: 400),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                ...statusTasks.map((task) => _buildTaskCard(task, statusColor)),
                
                // Add task button
                Container(
                  margin: const EdgeInsets.all(8),
                  child: InkWell(
                    onTap: () => _showAddTaskDialog(status['id']),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.grey.shade600),
                          const SizedBox(width: 8),
                          Text(
                            'Add Task',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, Color statusColor) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Draggable<Map<String, dynamic>>(
        data: task,
        feedback: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildTaskCardContent(task, statusColor),
          ),
        ),
        childWhenDragging: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
          ),
          child: _buildTaskCardContent(task, statusColor, isDragging: true),
        ),
        child: DragTarget<Map<String, dynamic>>(
          onAccept: (draggedTask) {
            if (draggedTask['id'] != task['id']) {
              _moveTask(draggedTask, task['status_id']);
            }
          },
          builder: (context, candidateData, rejectedData) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildTaskCardContent(task, statusColor),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTaskCardContent(Map<String, dynamic> task, Color statusColor, {bool isDragging = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task['title'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDragging ? Colors.grey : Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (task['description'] != null && task['description'].toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            task['description'],
            style: TextStyle(
              fontSize: 12,
              color: isDragging ? Colors.grey : Colors.grey.shade600,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            if (task['assigned_to'] != null) ...[
              CircleAvatar(
                radius: 12,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  task['assigned_to'].toString().substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue.shade800,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                task['due_date'] ?? '',
                style: TextStyle(
                  fontSize: 11,
                  color: isDragging ? Colors.grey : Colors.grey.shade600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getPriorityColor(task['priority']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                task['priority'] ?? 'Low',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _getPriorityColor(task['priority']),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _moveTask(Map<String, dynamic> task, int newStatusId) {
    // Update task status
    setState(() {
      task['status_id'] = newStatusId;
    });
    
    // TODO: Make API call to update task status
    _updateTaskStatus(task['id'], newStatusId);
  }

  Future<void> _updateTaskStatus(int taskId, int statusId) async {
    try {
      final jwt = await _getJwt();
      await http.put(
        Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/$taskId'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status_id': statusId}),
      );
    } catch (e) {
      // Handle error
      print('Error updating task status: $e');
    }
  }

  void _showAddTaskDialog(int statusId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Task'),
        content: const Text('Task creation functionality will be implemented here.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
