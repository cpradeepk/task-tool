import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../modern_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class JSRReportsScreen extends StatefulWidget {
  const JSRReportsScreen({super.key});

  @override
  State<JSRReportsScreen> createState() => _JSRReportsScreenState();
}

class _JSRReportsScreenState extends State<JSRReportsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _plannedTasks = [];
  List<dynamic> _completedTasks = [];
  List<dynamic> _filteredPlannedTasks = [];
  List<dynamic> _filteredCompletedTasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String _selectedProject = 'All';
  String _selectedStatus = 'All';
  String _selectedPriority = 'All';
  List<String> _projects = ['All'];
  List<String> _statuses = ['All', 'Open', 'In Progress', 'Completed', 'Hold', 'Cancelled'];
  List<String> _priorities = ['All', 'Important & Urgent', 'Important & Not Urgent', 'Not Important & Urgent', 'Not Important & Not Urgent'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadJSRData();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadJSRData() async {
    setState(() => _isLoading = true);

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final startDateStr = _startDate.toIso8601String().substring(0, 10);
      final endDateStr = _endDate.toIso8601String().substring(0, 10);

      // Load planned tasks
      final plannedResponse = await http.get(
        Uri.parse('$apiBase/task/api/admin/jsr/planned?start_date=$startDateStr&end_date=$endDateStr'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      // Load completed tasks
      final completedResponse = await http.get(
        Uri.parse('$apiBase/task/api/admin/jsr/completed?start_date=$startDateStr&end_date=$endDateStr'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (plannedResponse.statusCode == 200 && completedResponse.statusCode == 200) {
        setState(() {
          _plannedTasks = jsonDecode(plannedResponse.body);
          _completedTasks = jsonDecode(completedResponse.body);
        });
      } else {
        // Use mock data
        setState(() {
          _plannedTasks = _generateMockPlannedTasks();
          _completedTasks = _generateMockCompletedTasks();
        });
      }
    } catch (e) {
      setState(() {
        _plannedTasks = _generateMockPlannedTasks();
        _completedTasks = _generateMockCompletedTasks();
      });
    } finally {
      setState(() => _isLoading = false);

      // Extract unique projects for filtering
      final allTasks = [..._plannedTasks, ..._completedTasks];
      final projects = allTasks.map((task) => task['project'] as String).toSet().toList();
      setState(() => _projects = ['All', ...projects]);

      _applyFilters();
    }
  }

  void _applyFilters() {
    setState(() {
      // Filter planned tasks
      _filteredPlannedTasks = _plannedTasks.where((task) {
        final matchesProject = _selectedProject == 'All' || task['project'] == _selectedProject;
        final matchesStatus = _selectedStatus == 'All' || task['status'] == _selectedStatus;
        final matchesPriority = _selectedPriority == 'All' || task['priority'] == _selectedPriority;

        // Date range filtering
        final taskDate = DateTime.parse(task['due_date']);
        final matchesDateRange = taskDate.isAfter(_startDate.subtract(const Duration(days: 1))) &&
                                taskDate.isBefore(_endDate.add(const Duration(days: 1)));

        return matchesProject && matchesStatus && matchesPriority && matchesDateRange;
      }).toList();

      // Filter completed tasks
      _filteredCompletedTasks = _completedTasks.where((task) {
        final matchesProject = _selectedProject == 'All' || task['project'] == _selectedProject;
        final matchesStatus = _selectedStatus == 'All' || task['status'] == _selectedStatus;
        final matchesPriority = _selectedPriority == 'All' || task['priority'] == _selectedPriority;

        // Date range filtering
        final taskDate = DateTime.parse(task['completed_date']);
        final matchesDateRange = taskDate.isAfter(_startDate.subtract(const Duration(days: 1))) &&
                                taskDate.isBefore(_endDate.add(const Duration(days: 1)));

        return matchesProject && matchesStatus && matchesPriority && matchesDateRange;
      }).toList();
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadJSRData();
    }
  }

  List<dynamic> _generateMockPlannedTasks() {
    return [
      {
        'id': 'JSR-20250117001',
        'title': 'Complete user authentication module',
        'project': 'Task Tool',
        'assignee': 'john@example.com',
        'priority': 'High',
        'estimated_hours': 8,
        'due_date': _endDate.add(const Duration(days: 1)).toIso8601String().substring(0, 10),
        'status': 'In Progress',
        'progress': 60,
        'dependencies': ['JSR-20250116003'],
      },
      {
        'id': 'JSR-20250117002',
        'title': 'Design dashboard wireframes',
        'project': 'UI/UX Project',
        'assignee': 'sarah@example.com',
        'priority': 'Medium',
        'estimated_hours': 6,
        'due_date': _endDate.add(const Duration(days: 2)).toIso8601String().substring(0, 10),
        'status': 'Open',
        'progress': 0,
        'dependencies': [],
      },
      {
        'id': 'JSR-20250117003',
        'title': 'Database optimization',
        'project': 'Backend Development',
        'assignee': 'mike@example.com',
        'priority': 'High',
        'estimated_hours': 12,
        'due_date': _endDate.add(const Duration(days: 3)).toIso8601String().substring(0, 10),
        'status': 'Open',
        'progress': 0,
        'dependencies': ['JSR-20250117001'],
      },
      {
        'id': 'JSR-20250117004',
        'title': 'API documentation update',
        'project': 'Documentation',
        'assignee': 'lisa@example.com',
        'priority': 'Low',
        'estimated_hours': 4,
        'due_date': _endDate.add(const Duration(days: 5)).toIso8601String().substring(0, 10),
        'status': 'Open',
        'progress': 0,
        'dependencies': [],
      },
    ];
  }

  List<dynamic> _generateMockCompletedTasks() {
    return [
      {
        'id': 'JSR-20250116001',
        'title': 'Setup project repository',
        'project': 'Task Tool',
        'assignee': 'john@example.com',
        'priority': 'High',
        'estimated_hours': 2,
        'actual_hours': 2.5,
        'completed_date': _endDate.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10),
        'status': 'Completed',
        'quality_score': 95,
        'notes': 'Repository setup with CI/CD pipeline configured',
      },
      {
        'id': 'JSR-20250116002',
        'title': 'Initial database schema design',
        'project': 'Backend Development',
        'assignee': 'mike@example.com',
        'priority': 'Medium',
        'estimated_hours': 6,
        'actual_hours': 7,
        'completed_date': _endDate.subtract(const Duration(days: 1)).toIso8601String().substring(0, 10),
        'status': 'Completed',
        'quality_score': 88,
        'notes': 'Schema designed with proper indexing and relationships',
      },
      {
        'id': 'JSR-20250116003',
        'title': 'User interface mockups',
        'project': 'UI/UX Project',
        'assignee': 'sarah@example.com',
        'priority': 'Medium',
        'estimated_hours': 8,
        'actual_hours': 6,
        'completed_date': _endDate.subtract(const Duration(days: 2)).toIso8601String().substring(0, 10),
        'status': 'Completed',
        'quality_score': 92,
        'notes': 'Mockups approved by stakeholders',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return ModernLayout(
      title: 'JSR Reports',
      child: Column(
        children: [
          // Header with date picker
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.assignment, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Job Status Report (JSR)',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _selectDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text('${_startDate.toIso8601String().substring(0, 10)} - ${_endDate.toIso8601String().substring(0, 10)}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadJSRData,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Data',
                ),
              ],
            ),
          ),

          // Filter Controls
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Project filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Project',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: _selectedProject,
                        items: _projects.map((project) => DropdownMenuItem(
                          value: project,
                          child: Text(project),
                        )).toList(),
                        onChanged: (value) {
                          setState(() => _selectedProject = value!);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Status filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: _selectedStatus,
                        items: _statuses.map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        )).toList(),
                        onChanged: (value) {
                          setState(() => _selectedStatus = value!);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Priority filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        value: _selectedPriority,
                        items: _priorities.map((priority) => DropdownMenuItem(
                          value: priority,
                          child: Text(priority),
                        )).toList(),
                        onChanged: (value) {
                          setState(() => _selectedPriority = value!);
                          _applyFilters();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Clear filters button
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedProject = 'All';
                          _selectedStatus = 'All';
                          _selectedPriority = 'All';
                        });
                        _applyFilters();
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Summary Cards
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Planned Tasks',
                    '${_filteredPlannedTasks.length}',
                    Icons.schedule,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Completed Tasks',
                    '${_filteredCompletedTasks.length}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Total Hours Planned',
                    '${_plannedTasks.fold<int>(0, (sum, task) => sum + (task['estimated_hours'] as int? ?? 0))}',
                    Icons.access_time,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryCard(
                    'Avg Quality Score',
                    _completedTasks.isNotEmpty
                        ? '${(_completedTasks.fold<int>(0, (sum, task) => sum + (task['quality_score'] as int? ?? 0)) / _completedTasks.length).toStringAsFixed(1)}%'
                        : '0%',
                    Icons.star,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule),
                      const SizedBox(width: 8),
                      Text('Planned (${_filteredPlannedTasks.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle),
                      const SizedBox(width: 8),
                      Text('Completed (${_filteredCompletedTasks.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPlannedTasksTab(),
                      _buildCompletedTasksTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPlannedTasksTab() {
    if (_filteredPlannedTasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No planned tasks for this date', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Planned Tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Task ID')),
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Project')),
                  DataColumn(label: Text('Assignee')),
                  DataColumn(label: Text('Priority')),
                  DataColumn(label: Text('Est. Hours')),
                  DataColumn(label: Text('Due Date')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Progress')),
                  DataColumn(label: Text('Dependencies')),
                ],
                rows: _filteredPlannedTasks.map<DataRow>((task) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task['id'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            task['title'],
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      DataCell(Text(task['project'])),
                      DataCell(Text(task['assignee'].split('@')[0])),
                      DataCell(
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
                      ),
                      DataCell(Text('${task['estimated_hours']}h')),
                      DataCell(Text(task['due_date'])),
                      DataCell(
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
                      ),
                      DataCell(
                        Row(
                          children: [
                            SizedBox(
                              width: 60,
                              child: LinearProgressIndicator(
                                value: task['progress'] / 100.0,
                                backgroundColor: Colors.grey.shade300,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  task['progress'] == 100 ? Colors.green : Colors.blue,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('${task['progress']}%', style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                      DataCell(
                        Text(
                          (task['dependencies'] as List).isEmpty
                              ? 'None'
                              : (task['dependencies'] as List).join(', '),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedTasksTab() {
    if (_filteredCompletedTasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No completed tasks for this date', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'Completed Tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Task ID')),
                  DataColumn(label: Text('Title')),
                  DataColumn(label: Text('Project')),
                  DataColumn(label: Text('Assignee')),
                  DataColumn(label: Text('Priority')),
                  DataColumn(label: Text('Est. Hours')),
                  DataColumn(label: Text('Actual Hours')),
                  DataColumn(label: Text('Completed Date')),
                  DataColumn(label: Text('Quality Score')),
                  DataColumn(label: Text('Notes')),
                ],
                rows: _filteredCompletedTasks.map<DataRow>((task) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task['id'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 200,
                          child: Text(
                            task['title'],
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      DataCell(Text(task['project'])),
                      DataCell(Text(task['assignee'].split('@')[0])),
                      DataCell(
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
                      ),
                      DataCell(Text('${task['estimated_hours']}h')),
                      DataCell(Text('${task['actual_hours']}h')),
                      DataCell(Text(task['completed_date'])),
                      DataCell(
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: task['quality_score'] >= 90
                                  ? Colors.green
                                  : task['quality_score'] >= 80
                                      ? Colors.orange
                                      : Colors.red,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text('${task['quality_score']}%'),
                          ],
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Text(
                            task['notes'] ?? '',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
