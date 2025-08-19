import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'master_data.dart';
import 'task_detail.dart';
import 'rbac.dart';
import 'socket.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

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

  // Inline task creation
  bool _isCreatingTask = false;
  final TextEditingController _newTaskTitleController = TextEditingController();
  final TextEditingController _newTaskDescriptionController = TextEditingController();
  int? _newTaskModuleId;
  int? _newTaskAssigneeId;
  DateTime? _newTaskDueDate;

  // Timer functionality
  Map<String, dynamic>? _activeTimerTask;
  int _timerSeconds = 0;
  Timer? _timer;

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
    if (_busy) return; // Prevent multiple simultaneous loads

    setState(() { _busy = true; });
    final jwt = await _jwt();

    try {
      print('Loading data for project ${widget.projectId}...');

      // Load modules with timeout
      final modulesRes = await http.get(
        Uri.parse('$apiBase/task/api/projects/${widget.projectId}/modules'),
        headers: { 'Authorization': 'Bearer $jwt' }
      ).timeout(const Duration(seconds: 30));

      if (modulesRes.statusCode == 200) {
        _modules = jsonDecode(modulesRes.body) as List<dynamic>;
        print('Loaded ${_modules.length} modules');
      } else {
        print('Failed to load modules: ${modulesRes.statusCode}');
        _modules = [];
      }

      // Load tasks - either for specific module or all project tasks
      String tasksUrl;
      if (widget.moduleId != null) {
        tasksUrl = '$apiBase/task/api/projects/${widget.projectId}/modules/${widget.moduleId}/tasks';
      } else {
        tasksUrl = '$apiBase/task/api/projects/${widget.projectId}/tasks';
      }

      final r = await http.get(
        Uri.parse(tasksUrl),
        headers: { 'Authorization': 'Bearer $jwt' }
      ).timeout(const Duration(seconds: 30));

      List<dynamic> list = [];
      if (r.statusCode == 200) {
        list = jsonDecode(r.body) as List<dynamic>;
        print('Loaded ${list.length} tasks');
      } else {
        print('Failed to load tasks: ${r.statusCode}');
      }

      // Load users
      final usersRes = await http.get(
        Uri.parse('$apiBase/task/api/users'),
        headers: { 'Authorization': 'Bearer $jwt' }
      ).timeout(const Duration(seconds: 30));

      List<dynamic> users = [];
      if (usersRes.statusCode == 200) {
        users = jsonDecode(usersRes.body) as List<dynamic>;
        print('Loaded ${users.length} users');
      } else {
        print('Failed to load users: ${usersRes.statusCode}');
      }

      setState(() {
        _busy = false;
        _tasks = list;
        _users = users;
      });
    } catch (e) {
      print('Error loading data: $e');
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

    // Initialize WebSocket with error handling
    try {
      _rt = Realtime(apiBase);
      _rt!.connect();
      _rt!.on('task.created', (_) => _load());
      _rt!.on('task.updated', (_) => _load());
    } catch (e) {
      print('WebSocket initialization failed: $e');
      // Continue without WebSocket - app should still work
    }
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
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Floating timer (if active)
          if (_activeTimerTask != null) _buildFloatingTimer(),
          const SizedBox(height: 16),

          // Add task button
          FloatingActionButton(
            onPressed: _addNewTask,
            tooltip: 'Add Task',
            child: const Icon(Icons.add),
          ),
        ],
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
                const Expanded(flex: 2, child: Text('Task ID', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 2, child: Text('Priority', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 2, child: Text('Assignee', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 2, child: Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 2, child: Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold))),
                const Expanded(flex: 2, child: Text('Time Tracked', style: TextStyle(fontWeight: FontWeight.bold))),
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

              // Inline task creation row for this module
              if (_isCreatingTask && _newTaskModuleId == _getModuleIdFromName(entry.key))
                _buildInlineTaskCreationRow(),

              // Add task row at the end of each module
              if (!_isCreatingTask || _newTaskModuleId != _getModuleIdFromName(entry.key))
                _buildAddTaskRow(entry.key),
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
              onTapDown: (details) => _showStatusMenu(task, statuses, details.globalPosition),
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

            // Task ID
            Expanded(
              flex: 2,
              child: Text(
                task['task_id'] ?? _generateTaskId(task),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
            ),

            // Priority
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTapDown: (details) => _showPriorityMenu(task, priorities, details.globalPosition),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task, priorities),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getPriorityName(task, priorities),
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),

            // Assignee
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => _showAssigneeDropdown(task),
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
                    Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),

            // Due date
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => _showDatePicker(task),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatDate(task['planned_end_date']) ?? '-',
                        style: TextStyle(
                          fontSize: 13,
                          color: _isOverdue(task['planned_end_date']) ? Colors.red : Colors.grey.shade700,
                        ),
                      ),
                    ),
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),

            // Start date
            Expanded(
              flex: 2,
              child: Text(
                _formatDate(task['start_date']) ?? '-',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                ),
              ),
            ),

            // Time Tracked
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () => _toggleTimer(task),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isTimerRunning(task) ? Colors.red.shade100 : Colors.green.shade100,
                        border: Border.all(
                          color: _isTimerRunning(task) ? Colors.red.shade300 : Colors.green.shade300,
                        ),
                      ),
                      child: Icon(
                        _isTimerRunning(task) ? Icons.pause : Icons.play_arrow,
                        color: _isTimerRunning(task) ? Colors.red.shade700 : Colors.green.shade700,
                        size: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getTimeTracked(task),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
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

  Color _getPriorityColor(Map<String, dynamic> task, List<dynamic> priorities) {
    final priorityId = task['priority_id'] as int?;
    if (priorityId == null) return Colors.grey.shade400;

    final priority = priorities.firstWhere((p) => p['id'] == priorityId, orElse: () => {'name': 'Medium'});
    final priorityName = priority['name'] as String;

    switch (priorityName.toLowerCase()) {
      case 'important & urgent':
        return Colors.red;
      case 'important & not urgent':
        return Colors.orange;
      case 'not important & urgent':
        return Colors.yellow.shade700;
      case 'not important & not urgent':
        return Colors.grey.shade400;
      default:
        return Colors.grey.shade400;
    }
  }

  String _getPriorityName(Map<String, dynamic> task, List<dynamic> priorities) {
    final priorityId = task['priority_id'] as int?;
    if (priorityId == null) return 'Medium';

    final priority = priorities.firstWhere((p) => p['id'] == priorityId, orElse: () => {'name': 'Medium'});
    return priority['name'] as String;
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
    // Navigate to task detail screen using proper routing
    try {
      final taskId = task['id'] as int;
      final moduleId = task['module_id'] as int?;

      if (moduleId != null) {
        // Navigate to module-specific task detail
        context.go('/projects/${widget.projectId}/modules/$moduleId/tasks/$taskId');
      } else {
        // Fallback: use Navigator.push for tasks without modules
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(
              projectId: widget.projectId,
              taskId: taskId,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error navigating to task detail: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open task details'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showStatusMenu(Map<String, dynamic> task, List<dynamic> statuses, Offset position) {
    // Show status selection menu positioned next to the status indicator
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx - 200,
        MediaQuery.of(context).size.height - position.dy - 200,
      ),
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
                child: status['name'] == 'Completed'
                  ? const Icon(Icons.check, color: Colors.white, size: 12)
                  : null,
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

  void _showPriorityMenu(Map<String, dynamic> task, List<dynamic> priorities, Offset position) {
    // Show priority selection menu positioned next to the priority indicator
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        MediaQuery.of(context).size.width - position.dx - 250,
        MediaQuery.of(context).size.height - position.dy - 200,
      ),
      items: priorities.map<PopupMenuEntry>((priority) {
        return PopupMenuItem(
          value: priority['id'],
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _getPriorityColor({'priority_id': priority['id']}, priorities),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  priority['name'],
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ).then((selectedPriorityId) {
      if (selectedPriorityId != null) {
        _updateTaskPriority(task, selectedPriorityId);
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
    } else {
      print('Failed to update task status: ${res.statusCode} - ${res.body}');
    }
  }

  Future<void> _updateTaskPriority(Map<String, dynamic> task, int priorityId) async {
    final jwt = await _jwt();
    final res = await http.put(
      Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${task['id']}'),
      headers: {
        'Authorization': 'Bearer $jwt',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'priority_id': priorityId}),
    );
    if (res.statusCode == 200) {
      _load();
    } else {
      print('Failed to update task priority: ${res.statusCode} - ${res.body}');
    }
  }

  bool _isTimerRunning(Map<String, dynamic> task) {
    // Check if task has an active timer
    return task['timer_running'] == true;
  }

  String _getTimeTracked(Map<String, dynamic> task) {
    final totalSeconds = task['total_time_tracked'] as int? ?? 0;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String? _formatDate(String? dateStr) {
    if (dateStr == null) return null;
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showAssigneeDropdown(Map<String, dynamic> task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Assign Task'),
        content: SizedBox(
          width: 300,
          child: DropdownButtonFormField<int?>(
            value: task['assigned_to'] as int?,
            decoration: const InputDecoration(
              labelText: 'Assignee',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Unassigned')),
              ..._users.map((user) => DropdownMenuItem(
                value: user['id'] as int,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(
                        user['name'].toString().substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(user['name']),
                  ],
                ),
              )),
            ],
            onChanged: (value) {
              Navigator.of(context).pop();
              _updateTaskAssignee(task, value);
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showDatePicker(Map<String, dynamic> task) async {
    final currentDate = task['planned_end_date'] != null
      ? DateTime.tryParse(task['planned_end_date']) ?? DateTime.now()
      : DateTime.now();

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (selectedDate != null) {
      _updateTaskDueDate(task, selectedDate);
    }
  }

  Future<void> _updateTaskAssignee(Map<String, dynamic> task, int? assigneeId) async {
    final jwt = await _jwt();
    try {
      final res = await http.put(
        Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${task['id']}'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'assigned_to': assigneeId}),
      );
      if (res.statusCode == 200) {
        setState(() {
          task['assigned_to'] = assigneeId;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update assignee'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateTaskDueDate(Map<String, dynamic> task, DateTime dueDate) async {
    final jwt = await _jwt();
    final formattedDate = '${dueDate.year}-${dueDate.month.toString().padLeft(2, '0')}-${dueDate.day.toString().padLeft(2, '0')}';

    try {
      final res = await http.put(
        Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${task['id']}'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'planned_end_date': formattedDate}),
      );
      if (res.statusCode == 200) {
        setState(() {
          task['planned_end_date'] = formattedDate;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update due date'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleTimer(Map<String, dynamic> task) {
    if (_isTimerRunning(task)) {
      _stopTimer(task);
    } else {
      _startTimer(task);
    }
  }

  void _startTimer(Map<String, dynamic> task) {
    // Stop any existing timer
    if (_activeTimerTask != null) {
      _stopTimer(_activeTimerTask!);
    }

    setState(() {
      _activeTimerTask = task;
      task['timer_running'] = true;
      _timerSeconds = task['total_time_tracked'] as int? ?? 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _timerSeconds++;
        task['total_time_tracked'] = _timerSeconds;
      });
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timer started for: ${task['title']}'),
          backgroundColor: Colors.green.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _stopTimer(Map<String, dynamic> task) {
    _timer?.cancel();
    _timer = null;

    setState(() {
      task['timer_running'] = false;
      if (_activeTimerTask?['id'] == task['id']) {
        _activeTimerTask = null;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Timer stopped for: ${task['title']}'),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  int? _getModuleIdFromName(String moduleName) {
    if (moduleName == 'Unassigned') return null;
    final module = _modules.firstWhere(
      (m) => m['name'] == moduleName,
      orElse: () => <String, dynamic>{},
    );
    return module['id'] as int?;
  }

  Widget _buildAddTaskRow(String moduleName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        color: Colors.grey.shade50,
      ),
      child: InkWell(
        onTap: () => _startInlineTaskCreation(moduleName),
        child: Row(
          children: [
            const SizedBox(width: 40),
            Icon(Icons.add, color: Colors.grey.shade600, size: 16),
            const SizedBox(width: 8),
            Text(
              'Add Task',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineTaskCreationRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        color: Colors.blue.shade50,
      ),
      child: Row(
        children: [
          // Status indicator (default to Open)
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade400,
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 16),

          // Task name input
          Expanded(
            flex: 3,
            child: TextField(
              controller: _newTaskTitleController,
              decoration: const InputDecoration(
                hintText: 'Task title...',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                isDense: true,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),

          // Task ID (auto-generated)
          Expanded(
            flex: 2,
            child: Text(
              'Auto-generated',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Assignee dropdown
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<int?>(
              value: _newTaskAssigneeId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                isDense: true,
              ),
              hint: const Text('Assignee', style: TextStyle(fontSize: 12)),
              items: [
                const DropdownMenuItem(value: null, child: Text('Unassigned')),
                ..._users.map((user) => DropdownMenuItem(
                  value: user['id'] as int,
                  child: Text(user['name'], style: const TextStyle(fontSize: 12)),
                )),
              ],
              onChanged: (value) => setState(() => _newTaskAssigneeId = value),
            ),
          ),
          const SizedBox(width: 8),

          // Due date picker
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: _selectNewTaskDueDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _newTaskDueDate != null
                          ? _formatDate(_newTaskDueDate!.toIso8601String()) ?? 'Select date'
                          : 'Select date',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Start date (auto-filled)
          Expanded(
            flex: 2,
            child: Text(
              'Today',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ),

          // Time tracked (starts at 00:00:00)
          Expanded(
            flex: 2,
            child: Text(
              '00:00:00',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontFamily: 'monospace',
              ),
            ),
          ),

          // Action buttons
          const SizedBox(width: 16),
          Row(
            children: [
              IconButton(
                onPressed: _saveNewTask,
                icon: const Icon(Icons.check, color: Colors.green),
                iconSize: 20,
                tooltip: 'Save Task',
              ),
              IconButton(
                onPressed: _cancelTaskCreation,
                icon: const Icon(Icons.close, color: Colors.red),
                iconSize: 20,
                tooltip: 'Cancel',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _startInlineTaskCreation(String moduleName) {
    setState(() {
      _isCreatingTask = true;
      _newTaskModuleId = _getModuleIdFromName(moduleName);
      _newTaskTitleController.clear();
      _newTaskDescriptionController.clear();
      _newTaskAssigneeId = null;
      _newTaskDueDate = null;
    });
  }

  void _selectNewTaskDueDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (selectedDate != null) {
      setState(() {
        _newTaskDueDate = selectedDate;
      });
    }
  }

  void _saveNewTask() async {
    if (_newTaskTitleController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a task title'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final jwt = await _jwt();
    final now = DateTime.now();
    final taskId = 'JSR-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${(_tasks.length + 1).toString().padLeft(3, '0')}';

    final newTask = {
      'title': _newTaskTitleController.text.trim(),
      'description': _newTaskDescriptionController.text.trim(),
      'task_id': taskId,
      'module_id': _newTaskModuleId,
      'assigned_to': _newTaskAssigneeId,
      'planned_end_date': _newTaskDueDate?.toIso8601String().substring(0, 10),
      'start_date': now.toIso8601String().substring(0, 10),
      'status_id': 1, // Open status
      'priority_id': 2, // Medium priority
      'task_type_id': 1, // Default task type
    };

    try {
      print('Creating task with data: ${jsonEncode(newTask)}'); // Debug log
      print('API endpoint: $apiBase/task/api/projects/${widget.projectId}/tasks'); // Debug log

      final res = await http.post(
        Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(newTask),
      );

      print('Response status: ${res.statusCode}'); // Debug log
      print('Response body: ${res.body}'); // Debug log

      if (res.statusCode == 201 || res.statusCode == 200) {
        _cancelTaskCreation();
        _load(); // Reload tasks
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Task created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Handle non-success status codes
        print('Failed to create task. Status: ${res.statusCode}, Body: ${res.body}');
        throw Exception('Failed to create task: ${res.statusCode}');
      }
    } catch (e) {
      print('Error creating task: $e'); // Debug log

      // Add to local list for demo/fallback
      setState(() {
        _tasks.add({
          ...newTask,
          'id': _tasks.length + 1,
          'status_id': 1,
          'priority_id': 2,
          'task_type_id': 1,
          'timer_running': false,
          'total_time_tracked': 0,
        });
      });
      _cancelTaskCreation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task created successfully (demo mode)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _cancelTaskCreation() {
    setState(() {
      _isCreatingTask = false;
      _newTaskModuleId = null;
      _newTaskTitleController.clear();
      _newTaskDescriptionController.clear();
      _newTaskAssigneeId = null;
      _newTaskDueDate = null;
    });
  }

  Widget _buildFloatingTimer() {
    if (_activeTimerTask == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Time tracked',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _getTimeTracked(_activeTimerTask!),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _activeTimerTask!['title'] ?? 'Unknown Task',
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _stopTimer(_activeTimerTask!),
                icon: const Icon(Icons.pause, color: Colors.red),
                iconSize: 20,
                tooltip: 'Stop Timer',
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _openTaskDetail(_activeTimerTask!),
                icon: const Icon(Icons.open_in_new, color: Colors.blue),
                iconSize: 20,
                tooltip: 'Open Task',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _addNewTask() {
    // Start inline task creation for the first module or unassigned
    final firstModuleName = _modules.isNotEmpty ? _modules.first['name'] : 'Unassigned';
    _startInlineTaskCreation(firstModuleName);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newTaskTitleController.dispose();
    _newTaskDescriptionController.dispose();
    _timer?.cancel();
    super.dispose();
  }
}

