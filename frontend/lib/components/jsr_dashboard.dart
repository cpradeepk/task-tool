import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import 'jsr_layout.dart';
import 'ui/stats_card.dart';
import 'ui/status_badge.dart';
import 'ui/priority_badge.dart';
import 'ui/custom_buttons.dart';
import 'ui/loading_states.dart';
import '../theme/theme_provider.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class JSRDashboard extends StatefulWidget {
  const JSRDashboard({super.key});

  @override
  State<JSRDashboard> createState() => _JSRDashboardState();
}

class _JSRDashboardState extends State<JSRDashboard> {
  Map<String, dynamic> _stats = {};
  List<dynamic> _recentTasks = [];
  bool _isLoading = true;
  String _userRole = 'employee';
  String? _userEmail;
  String _activeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadDashboardData();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userEmail = prefs.getString('email');
      final isAdmin = prefs.getBool('is_admin') ?? false;
      _userRole = isAdmin ? 'admin' : 'employee';
    });
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    
    await Future.wait([
      _loadStats(),
      _loadRecentTasks(),
    ]);
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    final jwt = await _getJwt();
    if (jwt == null) {
      setState(() => _stats = _getMockStats());
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/dashboard/stats/$_userRole'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _stats = jsonDecode(response.body));
      } else {
        setState(() => _stats = _getMockStats());
      }
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _stats = _getMockStats());
    }
  }

  Future<void> _loadRecentTasks() async {
    final jwt = await _getJwt();
    if (jwt == null) {
      setState(() => _recentTasks = _getMockTasks());
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/tasks'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        final tasks = jsonDecode(response.body) as List;
        setState(() => _recentTasks = tasks.take(10).toList());
      } else {
        setState(() => _recentTasks = _getMockTasks());
      }
    } catch (e) {
      print('Error loading tasks: $e');
      setState(() => _recentTasks = _getMockTasks());
    }
  }

  Map<String, dynamic> _getMockStats() {
    return {
      'totalTasks': 24,
      'completedTasks': 18,
      'inProgressTasks': 4,
      'delayedTasks': 2,
      'pendingTasks': 0,
    };
  }

  List<dynamic> _getMockTasks() {
    return [
      {
        'id': 1,
        'title': 'Complete project documentation',
        'status': 'In Progress',
        'priority': 'U&I',
        'dueDate': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'assignee': 'John Doe',
      },
      {
        'id': 2,
        'title': 'Review code changes',
        'status': 'Done',
        'priority': 'NU&I',
        'dueDate': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'assignee': 'Jane Smith',
      },
      {
        'id': 3,
        'title': 'Update user interface',
        'status': 'Delayed',
        'priority': 'U&NI',
        'dueDate': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'assignee': 'Mike Johnson',
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return JSRPageWrapper(
        title: _userRole == 'admin' ? 'Admin Dashboard' : 'Welcome back!',
        subtitle: _userRole == 'admin' 
            ? 'System overview and user management'
            : 'Here\'s an overview of your tasks and activities',
        child: Column(
          children: [
            // Stats Cards Skeleton
            Row(
              children: [
                Expanded(child: DashboardCardSkeleton()),
                const SizedBox(width: 24),
                Expanded(child: DashboardCardSkeleton()),
                const SizedBox(width: 24),
                Expanded(child: DashboardCardSkeleton()),
                const SizedBox(width: 24),
                Expanded(child: DashboardCardSkeleton()),
              ],
            ),
            const SizedBox(height: 32),
            
            // Content Skeleton
            Expanded(
              child: JSRCard(
                child: Column(
                  children: [
                    SkeletonText(width: 200, height: 24),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Column(
                        children: List.generate(5, (index) => 
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: TaskCardSkeleton(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return JSRPageWrapper(
      title: _userRole == 'admin' ? 'Admin Dashboard' : 'Welcome back!',
      subtitle: _userRole == 'admin' 
          ? 'System overview and user management'
          : 'Here\'s an overview of your tasks and activities',
      actions: [
        Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 16,
              color: DesignTokens.colors['gray600'],
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('EEEE, MMMM d, y').format(DateTime.now()),
              style: TextStyle(
                fontSize: 14,
                color: DesignTokens.colors['gray600'],
              ),
            ),
          ],
        ),
      ],
      child: Column(
        children: [
          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: StatsCard(
                  title: 'Total Tasks',
                  value: _stats['totalTasks'] ?? 0,
                  icon: Icons.list_alt,
                  color: StatsCardColor.blue,
                  onTap: () => _handleFilterClick('all'),
                  isActive: _activeFilter == 'all',
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: StatsCard(
                  title: 'In Progress',
                  value: _stats['inProgressTasks'] ?? 0,
                  icon: Icons.hourglass_empty,
                  color: StatsCardColor.yellow,
                  onTap: () => _handleFilterClick('in-progress'),
                  isActive: _activeFilter == 'in-progress',
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: StatsCard(
                  title: 'Completed',
                  value: _stats['completedTasks'] ?? 0,
                  icon: Icons.check_circle,
                  color: StatsCardColor.green,
                  subtitle: _getCompletionRate(),
                  onTap: () => _handleFilterClick('completed'),
                  isActive: _activeFilter == 'completed',
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: StatsCard(
                  title: 'Delayed',
                  value: _stats['delayedTasks'] ?? 0,
                  icon: Icons.warning,
                  color: StatsCardColor.red,
                  onTap: () => _handleFilterClick('delayed'),
                  isActive: _activeFilter == 'delayed',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Recent Tasks
          Expanded(
            child: JSRCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recent Tasks (${_getFilteredTasks().length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: DesignTokens.colors['black'],
                          ),
                        ),
                      ),
                      CustomButton(
                        text: 'View All',
                        variant: ButtonVariant.outline,
                        size: ButtonSize.small,
                        onPressed: () => context.go('/tasks'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Task List
                  Expanded(
                    child: _buildTaskList(),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Quick Actions
          JSRCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.colors['black'],
                  ),
                ),
                const SizedBox(height: 16),
                _buildQuickActions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList() {
    final filteredTasks = _getFilteredTasks();
    
    if (filteredTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 48,
              color: DesignTokens.colors['gray400'],
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: TextStyle(
                fontSize: 16,
                color: DesignTokens.colors['gray600'],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: filteredTasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.colors['gray50'],
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.colors['gray200']!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task['title'] ?? 'Untitled Task',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.colors['black'],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              StatusBadge(status: task['status'] ?? 'Unknown'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              PriorityBadge(priority: task['priority'] ?? 'NU&NI'),
              const SizedBox(width: 12),
              Icon(
                Icons.person,
                size: 14,
                color: DesignTokens.colors['gray500'],
              ),
              const SizedBox(width: 4),
              Text(
                task['assignee'] ?? 'Unassigned',
                style: TextStyle(
                  fontSize: 12,
                  color: DesignTokens.colors['gray600'],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.calendar_today,
                size: 14,
                color: DesignTokens.colors['gray500'],
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(task['dueDate']),
                style: TextStyle(
                  fontSize: 12,
                  color: DesignTokens.colors['gray600'],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    if (_userRole == 'admin') {
      return Row(
        children: [
          Expanded(
            child: _buildQuickActionCard(
              'User Management',
              'Manage user accounts',
              Icons.people,
              () => context.go('/users'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildQuickActionCard(
              'System Settings',
              'Configure preferences',
              Icons.settings,
              () => context.go('/settings'),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            'Create Task',
            'Add a new task',
            Icons.add_task,
            () => context.go('/tasks/create'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickActionCard(
            'View Projects',
            'Browse all projects',
            Icons.folder,
            () => context.go('/projects'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildQuickActionCard(
            'Team Chat',
            'Collaborate with team',
            Icons.chat,
            () => context.go('/chat'),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return JSRCard(
      onTap: onTap,
      showHoverEffect: true,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: DesignTokens.colors['primary'],
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.colors['primary'],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: DesignTokens.colors['gray600'],
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getFilteredTasks() {
    switch (_activeFilter) {
      case 'completed':
        return _recentTasks.where((task) => task['status'] == 'Done').toList();
      case 'in-progress':
        return _recentTasks.where((task) => task['status'] == 'In Progress').toList();
      case 'delayed':
        return _recentTasks.where((task) => task['status'] == 'Delayed').toList();
      default:
        return _recentTasks;
    }
  }

  void _handleFilterClick(String filter) {
    setState(() {
      _activeFilter = filter;
    });
  }

  String _getCompletionRate() {
    final total = _stats['totalTasks'] ?? 0;
    final completed = _stats['completedTasks'] ?? 0;
    if (total == 0) return '0% completion rate';
    final rate = ((completed / total) * 100).round();
    return '$rate% completion rate';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'No date';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd').format(date);
    } catch (e) {
      return 'Invalid date';
    }
  }
}
