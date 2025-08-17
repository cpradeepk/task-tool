import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

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
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTasks();
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
                    // Calendar Grid
                    Expanded(
                      child: _buildCalendarGrid(),
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
}
