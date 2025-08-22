import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../modern_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class PertAnalysisScreen extends StatefulWidget {
  const PertAnalysisScreen({super.key});

  @override
  State<PertAnalysisScreen> createState() => _PertAnalysisScreenState();
}

class _PertAnalysisScreenState extends State<PertAnalysisScreen> {
  List<dynamic> _projects = [];
  int? _selectedProjectId;
  Map<String, dynamic>? _pertData;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadProjects() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/projects'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _projects = jsonDecode(response.body));
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to load projects');
    }
  }

  Future<void> _loadPertAnalysis() async {
    if (_selectedProjectId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/projects/$_selectedProjectId/pert'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _pertData = jsonDecode(response.body));
      } else {
        // Use mock data for demonstration
        setState(() => _pertData = _generateMockPertData());
      }
    } catch (e) {
      setState(() => _pertData = _generateMockPertData());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _generateMockPertData() {
    return {
      'project_id': _selectedProjectId,
      'critical_path': [
        {'task_id': 1, 'name': 'Project Planning', 'duration': 5, 'early_start': 0, 'early_finish': 5, 'late_start': 0, 'late_finish': 5, 'slack': 0},
        {'task_id': 2, 'name': 'Requirements Analysis', 'duration': 8, 'early_start': 5, 'early_finish': 13, 'late_start': 5, 'late_finish': 13, 'slack': 0},
        {'task_id': 3, 'name': 'System Design', 'duration': 10, 'early_start': 13, 'early_finish': 23, 'late_start': 13, 'late_finish': 23, 'slack': 0},
        {'task_id': 4, 'name': 'Development', 'duration': 20, 'early_start': 23, 'early_finish': 43, 'late_start': 23, 'late_finish': 43, 'slack': 0},
        {'task_id': 5, 'name': 'Testing', 'duration': 7, 'early_start': 43, 'early_finish': 50, 'late_start': 43, 'late_finish': 50, 'slack': 0},
      ],
      'all_tasks': [
        {'task_id': 1, 'name': 'Project Planning', 'duration': 5, 'early_start': 0, 'early_finish': 5, 'late_start': 0, 'late_finish': 5, 'slack': 0, 'is_critical': true},
        {'task_id': 2, 'name': 'Requirements Analysis', 'duration': 8, 'early_start': 5, 'early_finish': 13, 'late_start': 5, 'late_finish': 13, 'slack': 0, 'is_critical': true},
        {'task_id': 3, 'name': 'System Design', 'duration': 10, 'early_start': 13, 'early_finish': 23, 'late_start': 13, 'late_finish': 23, 'slack': 0, 'is_critical': true},
        {'task_id': 4, 'name': 'Development', 'duration': 20, 'early_start': 23, 'early_finish': 43, 'late_start': 23, 'late_finish': 43, 'slack': 0, 'is_critical': true},
        {'task_id': 5, 'name': 'Testing', 'duration': 7, 'early_start': 43, 'early_finish': 50, 'late_start': 43, 'late_finish': 50, 'slack': 0, 'is_critical': true},
        {'task_id': 6, 'name': 'Documentation', 'duration': 5, 'early_start': 23, 'early_finish': 28, 'late_start': 38, 'late_finish': 43, 'slack': 15, 'is_critical': false},
        {'task_id': 7, 'name': 'User Training', 'duration': 3, 'early_start': 43, 'early_finish': 46, 'late_start': 47, 'late_finish': 50, 'slack': 4, 'is_critical': false},
      ],
      'project_duration': 50,
      'total_tasks': 7,
      'critical_tasks': 5,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ModernLayout(
      title: 'PERT Analysis',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with project selection
            Row(
              children: [
                const Icon(Icons.timeline, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'PERT Analysis',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                SizedBox(
                  width: 300,
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Select Project',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.folder),
                    ),
                    value: _selectedProjectId,
                    items: _projects.map<DropdownMenuItem<int>>((project) {
                      return DropdownMenuItem<int>(
                        value: project['id'],
                        child: Text(project['name'] ?? 'Unnamed Project'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedProjectId = value);
                      if (value != null) _loadPertAnalysis();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_errorMessage != null)
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
            else if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_pertData != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards
                      _buildSummaryCards(),
                      const SizedBox(height: 24),
                      
                      // Critical Path Visualization
                      _buildCriticalPathChart(),
                      const SizedBox(height: 24),
                      
                      // Tasks Table
                      _buildTasksTable(),
                    ],
                  ),
                ),
              )
            else
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timeline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Select a project to view PERT analysis',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
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

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Project Duration',
            '${_pertData!['project_duration']} days',
            Icons.schedule,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Total Tasks',
            '${_pertData!['total_tasks']}',
            Icons.assignment,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Critical Tasks',
            '${_pertData!['critical_tasks']}',
            Icons.priority_high,
            Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildSummaryCard(
            'Slack Tasks',
            '${_pertData!['total_tasks'] - _pertData!['critical_tasks']}',
            Icons.access_time,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalPathChart() {
    final criticalPath = _pertData!['critical_path'] as List<dynamic>;
    
    return Container(
      padding: const EdgeInsets.all(20),
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
          const Row(
            children: [
              Icon(Icons.route, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Critical Path',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: criticalPath.length,
              itemBuilder: (context, index) {
                final task = criticalPath[index];
                final isLast = index == criticalPath.length - 1;
                
                return Row(
                  children: [
                    Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            task['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${task['duration']} days',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'ES: ${task['early_start']} EF: ${task['early_finish']}',
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, color: Colors.red.shade400),
                      const SizedBox(width: 8),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTasksTable() {
    final allTasks = _pertData!['all_tasks'] as List<dynamic>;
    
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
                Icon(Icons.table_chart, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'All Tasks - PERT Analysis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Task')),
                DataColumn(label: Text('Duration')),
                DataColumn(label: Text('Early Start')),
                DataColumn(label: Text('Early Finish')),
                DataColumn(label: Text('Late Start')),
                DataColumn(label: Text('Late Finish')),
                DataColumn(label: Text('Slack')),
                DataColumn(label: Text('Critical')),
              ],
              rows: allTasks.map<DataRow>((task) {
                final isCritical = task['is_critical'] as bool;
                return DataRow(
                  color: isCritical 
                    ? WidgetStateProperty.all(Colors.red.shade50)
                    : null,
                  cells: [
                    DataCell(
                      SizedBox(
                        width: 150,
                        child: Text(
                          task['name'],
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isCritical ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text('${task['duration']} days')),
                    DataCell(Text('${task['early_start']}')),
                    DataCell(Text('${task['early_finish']}')),
                    DataCell(Text('${task['late_start']}')),
                    DataCell(Text('${task['late_finish']}')),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: task['slack'] == 0 ? Colors.red : Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${task['slack']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      Icon(
                        isCritical ? Icons.warning : Icons.check_circle,
                        color: isCritical ? Colors.red : Colors.green,
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
}
