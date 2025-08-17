import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'http://localhost:3003');

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _thisWeekTasks = [];
  List<dynamic> _priorityTasks = [];
  List<dynamic> _recentNotes = [];
  List<dynamic> _favoriteNotes = [];
  List<dynamic> _taggedItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    await Future.wait([
      _loadThisWeekTasks(),
      _loadPriorityTasks(),
      _loadRecentNotes(),
      _loadFavoriteNotes(),
      _loadTaggedItems(),
    ]);
    
    setState(() => _isLoading = false);
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadThisWeekTasks() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      // This would be a custom endpoint for dashboard data
      final response = await http.get(
        Uri.parse('$apiBase/task/api/dashboard/this-week'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _thisWeekTasks = jsonDecode(response.body));
      }
    } catch (e) {
      // For now, use mock data
      setState(() => _thisWeekTasks = _getMockThisWeekTasks());
    }
  }

  Future<void> _loadPriorityTasks() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/dashboard/priority-tasks'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _priorityTasks = jsonDecode(response.body));
      }
    } catch (e) {
      setState(() => _priorityTasks = _getMockPriorityTasks());
    }
  }

  Future<void> _loadRecentNotes() async {
    // Mock data for now
    setState(() => _recentNotes = _getMockRecentNotes());
  }

  Future<void> _loadFavoriteNotes() async {
    // Mock data for now
    setState(() => _favoriteNotes = _getMockFavoriteNotes());
  }

  Future<void> _loadTaggedItems() async {
    // Mock data for now
    setState(() => _taggedItems = _getMockTaggedItems());
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Dashboard',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  _buildWelcomeSection(),
                  const SizedBox(height: 24),
                  
                  // Main Dashboard Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 1200;
                      return isWide
                          ? _buildWideLayout()
                          : _buildNarrowLayout();
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Good morning! 👋',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Plan Weekly, Execute Daily',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildQuickStat('Tasks This Week', '${_thisWeekTasks.length}'),
                    const SizedBox(width: 24),
                    _buildQuickStat('High Priority', '${_priorityTasks.length}'),
                  ],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.dashboard,
            size: 64,
            color: Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildWideLayout() {
    return Column(
      children: [
        // Top Row - This Week & Priority Tasks
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 2, child: _buildThisWeekWidget()),
            const SizedBox(width: 16),
            Expanded(child: _buildPriorityTasksWidget()),
          ],
        ),
        const SizedBox(height: 16),
        
        // Middle Row - Notes
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildRecentNotesWidget()),
            const SizedBox(width: 16),
            Expanded(child: _buildFavoriteNotesWidget()),
          ],
        ),
        const SizedBox(height: 16),
        
        // Bottom Row - Notes Shortcut & Tagged
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildNotesShortcutWidget()),
            const SizedBox(width: 16),
            Expanded(child: _buildTaggedWidget()),
          ],
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        _buildThisWeekWidget(),
        const SizedBox(height: 16),
        _buildPriorityTasksWidget(),
        const SizedBox(height: 16),
        _buildNotesShortcutWidget(),
        const SizedBox(height: 16),
        _buildRecentNotesWidget(),
        const SizedBox(height: 16),
        _buildFavoriteNotesWidget(),
        const SizedBox(height: 16),
        _buildTaggedWidget(),
      ],
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required Widget child,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
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
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (onTap != null)
                  IconButton(
                    onPressed: onTap,
                    icon: const Icon(Icons.more_horiz, size: 18),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildThisWeekWidget() {
    return SizedBox(
      height: 400,
      child: _buildDashboardCard(
        title: 'This Week',
        icon: Icons.calendar_today,
        iconColor: Colors.green,
        child: _thisWeekTasks.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.task_alt, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No tasks this week', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _thisWeekTasks.length,
                itemBuilder: (context, index) {
                  final task = _thisWeekTasks[index];
                  return _buildTaskItem(task);
                },
              ),
      ),
    );
  }

  Widget _buildPriorityTasksWidget() {
    return SizedBox(
      height: 400,
      child: _buildDashboardCard(
        title: 'My Priorities',
        icon: Icons.priority_high,
        iconColor: Colors.red,
        child: _priorityTasks.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.low_priority, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No priority tasks', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _priorityTasks.length,
                itemBuilder: (context, index) {
                  final task = _priorityTasks[index];
                  return _buildTaskItem(task);
                },
              ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
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
          Text(
            task['title'] ?? 'Untitled Task',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            task['project'] ?? 'Unknown Project',
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
                  task['status'] ?? 'Open',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                task['due_date'] ?? '',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'in progress':
        return Colors.blue;
      case 'delayed':
        return Colors.red;
      case 'hold':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  // Mock data methods
  List<Map<String, dynamic>> _getMockThisWeekTasks() {
    return [
      {
        'title': 'Complete user authentication',
        'project': 'Task Tool',
        'status': 'In Progress',
        'due_date': '2025-01-20',
      },
      {
        'title': 'Design dashboard wireframes',
        'project': 'UI/UX Project',
        'status': 'Open',
        'due_date': '2025-01-22',
      },
    ];
  }

  List<Map<String, dynamic>> _getMockPriorityTasks() {
    return [
      {
        'title': 'Fix critical security vulnerability',
        'project': 'Security Audit',
        'status': 'Open',
        'due_date': '2025-01-18',
      },
    ];
  }

  List<Map<String, dynamic>> _getMockRecentNotes() {
    return [
      {'title': 'Meeting notes - Sprint planning', 'date': '2025-01-17'},
      {'title': 'Ideas for dashboard improvement', 'date': '2025-01-16'},
    ];
  }

  List<Map<String, dynamic>> _getMockFavoriteNotes() {
    return [
      {'title': 'Project architecture decisions', 'date': '2025-01-15'},
    ];
  }

  List<Map<String, dynamic>> _getMockTaggedItems() {
    return [
      {'title': 'Review @john\'s code changes', 'type': 'task'},
      {'title': '@team meeting tomorrow', 'type': 'note'},
    ];
  }

  Widget _buildRecentNotesWidget() {
    return SizedBox(
      height: 300,
      child: _buildDashboardCard(
        title: 'My Last Notes',
        icon: Icons.note,
        iconColor: Colors.purple,
        child: _recentNotes.isEmpty
            ? const Center(child: Text('No recent notes'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _recentNotes.length,
                itemBuilder: (context, index) {
                  final note = _recentNotes[index];
                  return ListTile(
                    dense: true,
                    title: Text(note['title']),
                    subtitle: Text(note['date']),
                    leading: const Icon(Icons.note, size: 16),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildFavoriteNotesWidget() {
    return SizedBox(
      height: 300,
      child: _buildDashboardCard(
        title: 'My Favourite Notes',
        icon: Icons.star,
        iconColor: Colors.amber,
        child: _favoriteNotes.isEmpty
            ? const Center(child: Text('No favorite notes'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _favoriteNotes.length,
                itemBuilder: (context, index) {
                  final note = _favoriteNotes[index];
                  return ListTile(
                    dense: true,
                    title: Text(note['title']),
                    subtitle: Text(note['date']),
                    leading: const Icon(Icons.star, size: 16, color: Colors.amber),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildNotesShortcutWidget() {
    return SizedBox(
      height: 200,
      child: _buildDashboardCard(
        title: 'Notes Shortcut',
        icon: Icons.add_circle,
        iconColor: Colors.green,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text('Quick create:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickActionButton(Icons.text_fields, 'Text', () {}),
                  _buildQuickActionButton(Icons.mic, 'Voice', () {}),
                  _buildQuickActionButton(Icons.videocam, 'Video', () {}),
                  _buildQuickActionButton(Icons.link, 'Link', () {}),
                  _buildQuickActionButton(Icons.attach_file, 'Document', () {}),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaggedWidget() {
    return SizedBox(
      height: 300,
      child: _buildDashboardCard(
        title: 'Tagged',
        icon: Icons.tag,
        iconColor: Colors.teal,
        child: _taggedItems.isEmpty
            ? const Center(child: Text('No tagged items'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _taggedItems.length,
                itemBuilder: (context, index) {
                  final item = _taggedItems[index];
                  return ListTile(
                    dense: true,
                    title: Text(item['title']),
                    leading: Icon(
                      item['type'] == 'task' ? Icons.task : Icons.note,
                      size: 16,
                    ),
                  );
                },
              ),
      ),
    );
  }
}
