import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'master_data.dart';
import 'task_detail.dart';
import 'rbac.dart';
import 'socket.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class TasksScreen extends StatefulWidget {
  final int projectId;
  final int? moduleId;
  const TasksScreen({super.key, required this.projectId, this.moduleId});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  Realtime? _rt;
  List<dynamic> _tasks = [];
  List<dynamic> _modules = [];
  List<dynamic> _users = [];
  Map<String, dynamic>? _md;
  int? _moduleFilter;
  bool _busy = false;
  List<String> _roles = const [];
  final TextEditingController _searchController = TextEditingController();

  Future<String?> _jwt() async => (await SharedPreferences.getInstance()).getString('jwt');

  Future<void> _loadMD() async {
    final md = await fetchMasterData();
    setState(() { _md = md; });
  }

  Future<void> _loadRoles() async {
    final roles = await RBAC.roles();
    setState(() { _roles = roles; });
  }

  Future<void> _load() async {
    setState(() { _busy = true; });
    final jwt = await _jwt();

    try {
      // Load modules
      final modulesRes = await http.get(
        Uri.parse('$apiBase/task/api/projects/${widget.projectId}/modules'),
        headers: { 'Authorization': 'Bearer $jwt' }
      );
      _modules = jsonDecode(modulesRes.body) as List<dynamic>;

      // Load tasks - either for specific module or all project tasks
      String tasksUrl;
      if (widget.moduleId != null) {
        tasksUrl = '$apiBase/task/api/projects/${widget.projectId}/modules/${widget.moduleId}/tasks';
      } else {
        tasksUrl = '$apiBase/task/api/projects/${widget.projectId}/tasks';
      }

      final r = await http.get(Uri.parse(tasksUrl), headers: { 'Authorization': 'Bearer $jwt' });
      final list = jsonDecode(r.body) as List<dynamic>;

      // Load users
      final usersRes = await http.get(
        Uri.parse('$apiBase/task/api/users'),
        headers: { 'Authorization': 'Bearer $jwt' }
      );
      final users = jsonDecode(usersRes.body) as List<dynamic>;

      setState(() {
        _busy = false;
        _tasks = list;
        _users = users;
      });
    } catch (e) {
      // Use mock data for development
      _modules = [
        {'id': 1, 'name': 'Authentication Module'},
        {'id': 2, 'name': 'Dashboard Module'},
        {'id': 3, 'name': 'UI Design System'},
      ];

      final mockTasks = [
        {
          'id': 1,
          'task_id': 'JSR-20250117-001',
          'title': 'Implement user authentication',
          'description': 'Create login and registration functionality',
          'status': 'In Progress',
          'priority': 'Important & Urgent',
          'due_date': '2025-01-20',
          'assigned_to': 'John Doe',
          'module_id': widget.moduleId ?? 1,
          'estimated_hours': 8,
        },
        {
          'id': 2,
          'task_id': 'JSR-20250117-002',
          'title': 'Design dashboard layout',
          'description': 'Create responsive dashboard interface',
          'status': 'Open',
          'priority': 'Important & Not Urgent',
          'due_date': '2025-01-22',
          'assigned_to': 'Jane Smith',
          'module_id': widget.moduleId ?? 2,
          'estimated_hours': 6,
        },
        {
          'id': 3,
          'task_id': 'JSR-20250117-003',
          'title': 'Setup database schema',
          'description': 'Create and configure database tables',
          'status': 'Completed',
          'priority': 'Important & Urgent',
          'due_date': '2025-01-18',
          'assigned_to': 'Mike Johnson',
          'module_id': widget.moduleId ?? 1,
          'estimated_hours': 4,
        },
      ];

      // Filter tasks by module if moduleId is specified
      if (widget.moduleId != null) {
        _tasks = mockTasks.where((task) => task['module_id'] == widget.moduleId).toList();
      } else {
        _tasks = mockTasks;
      }

      _users = [
        {'id': 1, 'name': 'John Doe'},
        {'id': 2, 'name': 'Jane Smith'},
        {'id': 3, 'name': 'Mike Johnson'},
        {'id': 4, 'name': 'Sarah Wilson'},
      ];

      setState(() { _busy = false; });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMD();
    _load();
    _loadRoles();
    _rt = Realtime(apiBase);
    _rt!.connect();
    _rt!.on('task.created', (_) => _load());
    _rt!.on('task.updated', (_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final statuses = _md?['statuses'] as List<dynamic>? ?? [];
    final priorities = _md?['priorities'] as List<dynamic>? ?? [];
    final taskTypes = _md?['task_types'] as List<dynamic>? ?? [];

    List<dynamic> filtered = _tasks.where((t) => _moduleFilter == null || t['module_id'] == _moduleFilter).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Tasks - Project ${widget.projectId}${widget.moduleId != null ? ' / Module ${widget.moduleId}' : ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.view_kanban),
            onPressed: () {
              if (widget.moduleId != null) {
                context.go('/projects/${widget.projectId}/modules/${widget.moduleId}/kanban');
              } else {
                context.go('/projects/${widget.projectId}/kanban');
              }
            },
            tooltip: 'Switch to Kanban View',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Search and filters row
          Row(children: [
            // Search bar
            Expanded(
              flex: 2,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search tasks...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
            const SizedBox(width: 16),

            // Module filter
            const Text('Module:'),
            const SizedBox(width: 8),
            DropdownButton<int?>(
              value: _moduleFilter,
              items: [const DropdownMenuItem(value: null, child: Text('All')), ..._modules.map((m) => DropdownMenuItem(value: m['id'] as int, child: Text(m['name'])))],
              onChanged: (v) => setState(() => _moduleFilter = v),
            ),
          ]),
          const Divider(),
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: _buildTaskTable())
        ]),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTask,
        child: const Icon(Icons.add),
        tooltip: 'Add Task',
      ),
    );
  }

  Widget _buildTaskTable() {
    final statuses = _md?['statuses'] as List<dynamic>? ?? [];
    final priorities = _md?['priorities'] as List<dynamic>? ?? [];
    final taskTypes = _md?['task_types'] as List<dynamic>? ?? [];

    List<dynamic> filtered = _tasks.where((t) {
      // Module filter
      final matchesModule = _moduleFilter == null || t['module_id'] == _moduleFilter;

      // Search filter
      final searchTerm = _searchController.text.toLowerCase();
      final matchesSearch = searchTerm.isEmpty ||
          (t['title']?.toString().toLowerCase().contains(searchTerm) ?? false) ||
          (t['description']?.toString().toLowerCase().contains(searchTerm) ?? false);

      return matchesModule && matchesSearch;
    }).toList();

    // Group tasks by module
    Map<String, List<dynamic>> tasksByModule = {};
    for (final task in filtered) {
      final moduleId = task['module_id']?.toString() ?? 'unassigned';
      final moduleName = _modules.firstWhere(
        (m) => m['id'].toString() == moduleId,
        orElse: () => {'name': 'Unassigned'}
      )['name'] as String;

      if (!tasksByModule.containsKey(moduleName)) {
        tasksByModule[moduleName] = [];
      }
      tasksByModule[moduleName]!.add(task);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 40), // Space for status indicator
                const Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 2, child: Text('Feature ID', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 2, child: Text('Assignee', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 1, child: Text('Task ID', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 2, child: Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 40), // Space for actions
              ],
            ),
          ),

          // Task rows grouped by module
          ...tasksByModule.entries.map((entry) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Module header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder, color: Colors.blue.shade600, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Tasks in this module
              ...entry.value.map((task) => _buildTaskRow(task, statuses, priorities, taskTypes)),
            ],
          )),
        ],
      ),
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> task, List<dynamic> statuses, List<dynamic> priorities, List<dynamic> taskTypes) {
    final status = statuses.firstWhere((s) => s['id'] == task['status_id'], orElse: () => {'name': 'Open', 'id': 1});
    final assignedUser = _users.firstWhere((u) => u['id'] == task['assigned_to'], orElse: () => {'name': 'Unassigned'});

    return InkWell(
      onTap: () => _openTaskDetail(task),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          color: Colors.white,
        ),
        child: Row(
          children: [
            // Status indicator
            GestureDetector(
              onTap: () => _showStatusMenu(task, statuses),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(status['name']),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: status['name'] == 'Completed'
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
              ),
            ),
            const SizedBox(width: 16),

            // Task name
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task['description'] != null && task['description'].toString().isNotEmpty)
                    Text(
                      task['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Feature ID
            Expanded(
              flex: 2,
              child: Text(
                _generateTaskId(task),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Assignee
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  if (assignedUser['name'] != 'Unassigned') ...[
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        assignedUser['name'].toString().substring(0, 1).toUpperCase(),
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
                      assignedUser['name'],
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Due date
            Expanded(
              flex: 2,
              child: Text(
                task['planned_end_date'] ?? '-',
                style: TextStyle(
                  fontSize: 13,
                  color: _isOverdue(task['planned_end_date']) ? Colors.red : Colors.grey.shade700,
                ),
              ),
            ),

            // Status
            Expanded(
              flex: 1,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status['name']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(status['name']).withOpacity(0.3)),
                ),
                child: Text(
                  status['name'].toString().toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _getStatusColor(status['name']),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Task ID
            Expanded(
              flex: 1,
              child: Text(
                '#${task['id']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Start date
            Expanded(
              flex: 2,
              child: Text(
                task['start_date'] ?? '-',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

            // Timer button
            const SizedBox(width: 16),
            GestureDetector(
              onTap: () => _toggleTimer(task),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.shade100,
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Icon(
                  Icons.play_arrow,
                  color: Colors.green.shade700,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String statusName) {
    switch (statusName.toLowerCase()) {
      case 'open':
        return Colors.grey.shade400;
      case 'in progress':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.grey;
      case 'hold':
        return Colors.brown;
      case 'delayed':
        return Colors.red;
      default:
        return Colors.grey.shade400;
    }
  }

  String _generateTaskId(Map<String, dynamic> task) {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final taskNum = (task['id'] as int).toString().padLeft(3, '0');
    return 'JSR-$dateStr-$taskNum';
  }

  bool _isOverdue(String? dueDate) {
    if (dueDate == null) return false;
    try {
      final due = DateTime.parse(dueDate);
      return due.isBefore(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  void _openTaskDetail(Map<String, dynamic> task) {
    // Navigate to task detail screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          projectId: widget.projectId,
          taskId: task['id'] as int,
        ),
      ),
    );
  }

  void _showStatusMenu(Map<String, dynamic> task, List<dynamic> statuses) {
    // Show status selection menu
    showMenu(
      context: context,
      position: const RelativeRect.fromLTRB(100, 100, 0, 0),
      items: statuses.map<PopupMenuEntry>((status) {
        return PopupMenuItem(
          value: status['id'],
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getStatusColor(status['name']),
                ),
              ),
              const SizedBox(width: 8),
              Text(status['name']),
            ],
          ),
        );
      }).toList(),
    ).then((selectedStatusId) {
      if (selectedStatusId != null) {
        _updateTaskStatus(task, selectedStatusId);
      }
    });
  }

  Future<void> _updateTaskStatus(Map<String, dynamic> task, int statusId) async {
    final jwt = await _jwt();
    final res = await http.put(
      Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${task['id']}'),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status_id': statusId}),
    );
    if (res.statusCode == 200) {
      _load();
    }
  }

  void _toggleTimer(Map<String, dynamic> task) async {
    final jwt = await _jwt();
    final taskId = task['id'] as int;

    try {
      // Check if there's an active timer for this task
      final activeTimerRes = await http.get(
        Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/$taskId/active-timer'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (activeTimerRes.statusCode == 200) {
        final activeTimer = jsonDecode(activeTimerRes.body);
        if (activeTimer != null) {
          // Stop the active timer
          await http.put(
            Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/$taskId/time-entries/stop'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'Content-Type': 'application/json',
            },
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Timer stopped for: ${task['title']}'),
                backgroundColor: Colors.red.shade600,
              ),
            );
          }
        } else {
          // Start a new timer
          await http.post(
            Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/$taskId/time-entries'),
            headers: {
              'Authorization': 'Bearer $jwt',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'start': DateTime.now().toIso8601String()}),
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Timer started for: ${task['title']}'),
                backgroundColor: Colors.green.shade600,
              ),
            );
          }
        }
      }

      // Reload tasks to update timer states
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timer functionality not available in demo mode'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _addNewTask() {
    // Navigate to add new task screen or show dialog
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

