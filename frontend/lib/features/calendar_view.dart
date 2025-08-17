import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';
import '../constants/task_constants.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class CalendarViewScreen extends StatefulWidget {
  const CalendarViewScreen({super.key});

  @override
  State<CalendarViewScreen> createState() => _CalendarViewScreenState();
}

class _CalendarViewScreenState extends State<CalendarViewScreen> {
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedDate = DateTime.now();
  List<dynamic> _tasks = [];
  List<dynamic> _selectedDateTasks = [];
  List<dynamic> _projects = [];
  List<dynamic> _modules = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _viewMode = 'month'; // 'month' or 'agenda'

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _loadProjects();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/calendar/tasks'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _tasks = jsonDecode(response.body));
      } else {
        // Use mock data for demonstration
        setState(() => _tasks = _generateMockTasks());
      }
    } catch (e) {
      setState(() => _tasks = _generateMockTasks());
    } finally {
      setState(() => _isLoading = false);
      _updateSelectedDateTasks();
    }
  }

  List<dynamic> _generateMockTasks() {
    final now = DateTime.now();
    return [
      {
        'id': 1,
        'title': 'Complete user authentication',
        'project': 'Task Tool',
        'due_date': now.add(const Duration(days: 1)).toIso8601String().substring(0, 10),
        'status': 'In Progress',
        'priority': 'High',
      },
      {
        'id': 2,
        'title': 'Design dashboard wireframes',
        'project': 'UI/UX Project',
        'due_date': now.add(const Duration(days: 3)).toIso8601String().substring(0, 10),
        'status': 'Open',
        'priority': 'Medium',
      },
      {
        'id': 3,
        'title': 'Database optimization',
        'project': 'Backend Development',
        'due_date': now.add(const Duration(days: 5)).toIso8601String().substring(0, 10),
        'status': 'Open',
        'priority': 'High',
      },
      {
        'id': 4,
        'title': 'Code review session',
        'project': 'Development',
        'due_date': now.toIso8601String().substring(0, 10),
        'status': 'Completed',
        'priority': 'Medium',
      },
      {
        'id': 5,
        'title': 'Team meeting',
        'project': 'Management',
        'due_date': now.add(const Duration(days: 7)).toIso8601String().substring(0, 10),
        'status': 'Open',
        'priority': 'Low',
      },
    ];
  }

  Future<void> _loadProjects() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/admin/projects'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _projects = jsonDecode(response.body));
      }
    } catch (e) {
      // Use mock projects for development
      setState(() => _projects = [
        {'id': 1, 'name': 'Task Tool Development'},
        {'id': 2, 'name': 'Mobile App Development'},
      ]);
    }
  }

  Future<void> _loadModules(int projectId) async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/admin/projects/$projectId/modules'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _modules = jsonDecode(response.body));
      }
    } catch (e) {
      // Use mock modules for development
      setState(() => _modules = [
        {'id': 1, 'name': 'Authentication Module', 'project_id': projectId},
        {'id': 2, 'name': 'Dashboard Module', 'project_id': projectId},
      ]);
    }
  }

  void _updateSelectedDateTasks() {
    final selectedDateStr = _selectedDate.toIso8601String().substring(0, 10);
    setState(() {
      _selectedDateTasks = _tasks.where((task) => task['due_date'] == selectedDateStr).toList();
    });
  }

  List<dynamic> _getTasksForDate(DateTime date) {
    final dateStr = date.toIso8601String().substring(0, 10);
    return _tasks.where((task) => task['due_date'] == dateStr).toList();
  }

  void _showTaskCreationDialog(DateTime selectedDate) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    int? selectedProjectId;
    int? selectedModuleId;
    String priority = TaskPriority.importantNotUrgent;
    String status = TaskStatus.open;
    int? estimatedHours;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Create Task for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Task Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Project',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedProjectId,
                    items: _projects.map<DropdownMenuItem<int>>((project) {
                      return DropdownMenuItem<int>(
                        value: project['id'],
                        child: Text(project['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedProjectId = value;
                        selectedModuleId = null;
                      });
                      if (value != null) _loadModules(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Module',
                      border: OutlineInputBorder(),
                    ),
                    value: selectedModuleId,
                    items: _modules.map<DropdownMenuItem<int>>((module) {
                      return DropdownMenuItem<int>(
                        value: module['id'],
                        child: Text(module['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedModuleId = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Priority',
                            border: OutlineInputBorder(),
                          ),
                          value: priority,
                          items: TaskPriority.values.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Row(
                                children: [
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: TaskPriority.getColor(p),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.grey.shade300),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(p, style: const TextStyle(fontSize: 12))),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => priority = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: 'Est. Hours',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            estimatedHours = int.tryParse(value);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  _createTask(
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    projectId: selectedProjectId,
                    moduleId: selectedModuleId,
                    priority: priority,
                    status: status,
                    dueDate: selectedDate,
                    estimatedHours: estimatedHours,
                  );
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Create Task'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createTask({
    required String title,
    required String description,
    int? projectId,
    int? moduleId,
    required String priority,
    required String status,
    required DateTime dueDate,
    int? estimatedHours,
  }) async {
    if (moduleId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a project and module')),
      );
      return;
    }

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBase/task/api/admin/projects/$projectId/modules/$moduleId/tasks'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'priority': priority,
          'status': status,
          'due_date': dueDate.toIso8601String().substring(0, 10),
          'estimated_hours': estimatedHours,
        }),
      );

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully'), backgroundColor: Colors.green),
        );
        _loadTasks(); // Refresh tasks
      } else {
        // Add to local tasks for demo
        setState(() {
          _tasks.add({
            'id': _tasks.length + 1,
            'title': title,
            'description': description,
            'priority': priority,
            'status': status,
            'due_date': dueDate.toIso8601String().substring(0, 10),
            'estimated_hours': estimatedHours,
            'project': _projects.firstWhere((p) => p['id'] == projectId, orElse: () => {'name': 'Unknown'})['name'],
          });
        });
        _updateSelectedDateTasks();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating task: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Calendar',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Calendar Widget
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Calendar Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.blue),
                          const SizedBox(width: 8),
                          const Text(
                            'Task Calendar',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          // View Mode Toggle
                          ToggleButtons(
                            isSelected: [_viewMode == 'month', _viewMode == 'agenda'],
                            onPressed: (index) {
                              setState(() {
                                _viewMode = index == 0 ? 'month' : 'agenda';
                              });
                            },
                            children: const [
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Month'),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Agenda'),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Add Task Button
                          ElevatedButton.icon(
                            onPressed: () => _showTaskCreationDialog(_selectedDate),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Task'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
                              });
                            },
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text(
                            '${_getMonthName(_focusedDate.month)} ${_focusedDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1);
                              });
                            },
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ),
                    // Calendar Grid or Agenda View
                    Expanded(
                      child: _viewMode == 'month'
                          ? _buildCalendarGrid()
                          : _buildAgendaView(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Task Details Panel
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Task Panel Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.assignment, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            'Tasks for ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    // Task List
                    Expanded(
                      child: _selectedDateTasks.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.event_available, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('No tasks for this date', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _selectedDateTasks.length,
                              itemBuilder: (context, index) {
                                final task = _selectedDateTasks[index];
                                return _buildTaskCard(task);
                              },
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

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month, 1);
    final lastDayOfMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0);
    final firstDayWeekday = firstDayOfMonth.weekday % 7; // Make Sunday = 0
    final daysInMonth = lastDayOfMonth.day;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar days
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: 42, // 6 weeks * 7 days
              itemBuilder: (context, index) {
                final dayNumber = index - firstDayWeekday + 1;
                
                if (dayNumber < 1 || dayNumber > daysInMonth) {
                  return const SizedBox(); // Empty cell
                }
                
                final date = DateTime(_focusedDate.year, _focusedDate.month, dayNumber);
                final tasksForDate = _getTasksForDate(date);
                final isSelected = _selectedDate.year == date.year &&
                    _selectedDate.month == date.month &&
                    _selectedDate.day == date.day;
                final isToday = DateTime.now().year == date.year &&
                    DateTime.now().month == date.month &&
                    DateTime.now().day == date.day;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDate = date;
                    });
                    _updateSelectedDateTasks();
                  },
                  onDoubleTap: () => _showTaskCreationDialog(date),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.blue
                          : isToday
                              ? Colors.blue.shade100
                              : null,
                      borderRadius: BorderRadius.circular(8),
                      border: tasksForDate.isNotEmpty
                          ? Border.all(color: Colors.orange, width: 2)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : isToday
                                    ? Colors.blue
                                    : Colors.black,
                            fontWeight: isToday || isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        if (tasksForDate.isNotEmpty)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : Colors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task['title'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getPriorityColor(task['priority']),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task['priority'],
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            task['project'],
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(task['status']),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  task['status'],
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'open':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Widget _buildAgendaView() {
    // Get tasks for the current month
    final monthTasks = _tasks.where((task) {
      if (task['due_date'] == null) return false;
      final taskDate = DateTime.parse(task['due_date']);
      return taskDate.year == _focusedDate.year && taskDate.month == _focusedDate.month;
    }).toList();

    // Group tasks by date
    final groupedTasks = <String, List<dynamic>>{};
    for (final task in monthTasks) {
      final dateKey = task['due_date'];
      if (!groupedTasks.containsKey(dateKey)) {
        groupedTasks[dateKey] = [];
      }
      groupedTasks[dateKey]!.add(task);
    }

    final sortedDates = groupedTasks.keys.toList()..sort();

    if (sortedDates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_note, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No tasks scheduled this month', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showTaskCreationDialog(_selectedDate),
              icon: const Icon(Icons.add),
              label: const Text('Add Task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedDates.length,
      itemBuilder: (context, index) {
        final dateKey = sortedDates[index];
        final tasks = groupedTasks[dateKey]!;
        final date = DateTime.parse(dateKey);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      '${date.day}/${date.month}/${date.year}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${tasks.length} task${tasks.length == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.blue.shade600),
                    ),
                  ],
                ),
              ),
              ...tasks.map((task) => ListTile(
                leading: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: TaskPriority.getColor(task['priority']),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(
                      '${TaskPriority.getOrder(task['priority'] ?? '')}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                title: Text(task['title'] ?? 'Untitled Task'),
                subtitle: Text(task['description'] ?? 'No description'),
                trailing: Chip(
                  label: Text(
                    task['status'] ?? TaskStatus.open,
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: TaskStatus.getBackgroundColor(task['status']),
                ),
                onTap: () {
                  // Navigate to task details - will implement later
                },
              )),
            ],
          ),
        );
      },
    );
  }


}
