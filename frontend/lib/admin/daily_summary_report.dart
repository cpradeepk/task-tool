import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';


const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class DailySummaryReportScreen extends StatefulWidget {
  const DailySummaryReportScreen({super.key});

  @override
  State<DailySummaryReportScreen> createState() => _DailySummaryReportScreenState();
}

class _DailySummaryReportScreenState extends State<DailySummaryReportScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _reportData;
  bool _isLoading = false;
  bool _isExpanded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final dateStr = _selectedDate.toIso8601String().substring(0, 10);
      final response = await http.get(
        Uri.parse('$apiBase/task/api/admin/reports/daily-summary?date=$dateStr'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _reportData = jsonDecode(response.body));
      } else {
        setState(() => _errorMessage = 'Failed to load report');
      }
    } catch (e) {
      // Use mock data for now
      setState(() => _reportData = _getMockReportData());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _getMockReportData() {
    return {
      'date': _selectedDate.toIso8601String().substring(0, 10),
      'summary': {
        'total_users': 12,
        'active_users': 8,
        'total_tasks': 45,
        'tasks_completed': 12,
        'tasks_in_progress': 18,
        'tasks_delayed': 3,
        'total_hours_logged': 64,
        'projects_active': 5,
      },
      'user_details': [
        {
          'user_id': 1,
          'name': 'Mohini (EL-0003)',
          'tasks_in_progress': 0,
          'tasks_delayed': 0,
          'tasks_completed': 2,
          'hours_worked': 19,
          'tasks_completed_mtd': 3,
          'mtd_hours': 32,
        },
        {
          'user_id': 2,
          'name': 'Pawan Prasad (EL-0034)',
          'tasks_in_progress': 0,
          'tasks_delayed': 0,
          'tasks_completed': 1,
          'hours_worked': 8,
          'tasks_completed_mtd': 8,
          'mtd_hours': 64,
        },
        {
          'user_id': 3,
          'name': 'Bindu (EL-0021)',
          'tasks_in_progress': 0,
          'tasks_delayed': 0,
          'tasks_completed': 1,
          'hours_worked': 8,
          'tasks_completed_mtd': 6,
          'mtd_hours': 48,
        },
      ],
      'task_details': [
        {
          'task_id': 'JSR-19042025225540',
          'title': 'SVC SocietyPro / Society Connekt / Society Run',
          'due_date': '2025-09-30',
          'priority': 'Normal',
          'status': 'Yet to Start',
          'estimated_hours': 100,
          'hours_spent': 0,
        },
        {
          'task_id': 'JSR-19042025225816',
          'title': 'Society City',
          'due_date': '2025-10-01',
          'priority': 'Normal',
          'status': 'Yet to Start',
          'estimated_hours': 100,
          'hours_spent': 0,
        },
        {
          'task_id': 'JSR-19042025225854',
          'title': 'OneCHS',
          'due_date': '2025-09-01',
          'priority': 'Normal',
          'status': 'Yet to Start',
          'estimated_hours': 100,
          'hours_spent': 0,
        },
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date picker
            Row(
              children: [
                const Icon(Icons.today, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Daily Summary Report - ${_selectedDate.toIso8601String().substring(0, 10)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                      _loadReport();
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Change Date'),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _loadReport,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Report',
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              )
            else if (_reportData != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      
                      // Expand/Collapse Toggle
                      Row(
                        children: [
                          const Text(
                            'Detailed Report',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => setState(() => _isExpanded = !_isExpanded),
                            icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                            label: Text(_isExpanded ? 'Collapse' : 'Expand'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (_isExpanded) ...[
                        // User Details Table
                        _buildUserDetailsTable(),
                        const SizedBox(height: 24),
                        
                        // Task Details Table
                        _buildTaskDetailsTable(),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
    );
  }

  Widget _buildSummaryCards() {
    final summary = _reportData!['summary'] as Map<String, dynamic>;
    
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildSummaryCard('Active Users', '${summary['active_users']}/${summary['total_users']}', Icons.people, Colors.blue),
        _buildSummaryCard('Tasks Completed', '${summary['tasks_completed']}', Icons.check_circle, Colors.green),
        _buildSummaryCard('Tasks In Progress', '${summary['tasks_in_progress']}', Icons.play_circle, Colors.orange),
        _buildSummaryCard('Hours Logged', '${summary['total_hours_logged']}', Icons.access_time, Colors.purple),
      ],
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
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

  Widget _buildUserDetailsTable() {
    final userDetails = _reportData!['user_details'] as List<dynamic>;
    
    return Container(
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
                Icon(Icons.people, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'User Performance Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Sr. No.')),
                DataColumn(label: Text('Name (User ID)')),
                DataColumn(label: Text('Task In Progress')),
                DataColumn(label: Text('Task Delayed')),
                DataColumn(label: Text('Task Completed')),
                DataColumn(label: Text('Hours Worked')),
                DataColumn(label: Text('Task Completed MTD')),
                DataColumn(label: Text('MTD')),
              ],
              rows: userDetails.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final user = entry.value;
                return DataRow(
                  cells: [
                    DataCell(Text('$index')),
                    DataCell(Text(user['name'])),
                    DataCell(Text('${user['tasks_in_progress']}')),
                    DataCell(Text('${user['tasks_delayed']}')),
                    DataCell(Text('${user['tasks_completed']}')),
                    DataCell(Text('${user['hours_worked']} hrs')),
                    DataCell(Text('${user['tasks_completed_mtd']}')),
                    DataCell(Text('${user['mtd_hours']} hrs')),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskDetailsTable() {
    final taskDetails = _reportData!['task_details'] as List<dynamic>;
    
    return Container(
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
                Icon(Icons.assignment, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Task Details',
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
                DataColumn(label: Text('Due Date')),
                DataColumn(label: Text('Task')),
                DataColumn(label: Text('Description')),
                DataColumn(label: Text('SubTask')),
                DataColumn(label: Text('Est. Hours')),
                DataColumn(label: Text('Hours Spent')),
                DataColumn(label: Text('Status')),
              ],
              rows: taskDetails.map<DataRow>((task) {
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
                          task['task_id'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    DataCell(Text(task['due_date'])),
                    DataCell(Text(task['priority'])),
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
                    DataCell(Text('-')), // SubTask placeholder
                    DataCell(Text('${task['estimated_hours']}')),
                    DataCell(Text('${task['hours_spent']}')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task['status']),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task['status'],
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'yet to start':
        return Colors.grey;
      case 'delayed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
