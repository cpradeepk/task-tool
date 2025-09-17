import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'components/professional_card.dart';
import 'components/animations.dart';
import 'components/professional_buttons.dart';
import 'theme/theme_provider.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class EnhancedDashboardScreen extends StatefulWidget {
  const EnhancedDashboardScreen({super.key});

  @override
  State<EnhancedDashboardScreen> createState() => _EnhancedDashboardScreenState();
}

class _EnhancedDashboardScreenState extends State<EnhancedDashboardScreen> {
  Map<String, dynamic> _stats = {};
  List<dynamic> _thisWeekTasks = [];
  List<dynamic> _overdueTasks = [];
  Map<String, dynamic> _warnings = {};
  bool _isLoading = true;
  String _userRole = 'employee';
  String? _userEmail;

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
      // Determine user role - this should come from your auth system
      final isAdmin = prefs.getBool('isAdmin') ?? false;
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
      _loadThisWeekTasks(),
      _loadOverdueTasks(),
      _loadWarnings(),
    ]);
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadStats() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/dashboard/stats/$_userRole'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _stats = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading stats: $e');
      setState(() => _stats = {});
    }
  }

  Future<void> _loadThisWeekTasks() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/dashboard/this-week'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _thisWeekTasks = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading this week tasks: $e');
      setState(() => _thisWeekTasks = []);
    }
  }

  Future<void> _loadOverdueTasks() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/dashboard/overdue-tasks'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _overdueTasks = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading overdue tasks: $e');
      setState(() => _overdueTasks = []);
    }
  }

  Future<void> _loadWarnings() async {
    final jwt = await _getJwt();
    if (jwt == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBase/task/api/dashboard/warnings'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _warnings = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading warnings: $e');
      setState(() => _warnings = {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
              padding: const EdgeInsets.all(DesignTokens.spacing16),
              child: FadeInAnimation(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    _buildWelcomeSection(),
                    const SizedBox(height: DesignTokens.spacing24),
                    
                    // Warning Alert (if any)
                    if (_warnings['has_warnings'] == true) ...[
                      _buildWarningAlert(),
                      const SizedBox(height: DesignTokens.spacing24),
                    ],
                    
                    // Stats Cards
                    _buildStatsSection(),
                    const SizedBox(height: DesignTokens.spacing24),
                    
                    // Main Content based on role
                    _buildRoleBasedContent(),
                  ],
                ),
              ),
            );
  }



  Widget _buildWelcomeSection() {
    final greeting = _getGreeting();
    final subtitle = _getSubtitle();
    
    return ProfessionalCard(
      backgroundColor: DesignTokens.primaryOrange,
      customShadow: [
        BoxShadow(
          color: DesignTokens.primaryOrange.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: TextStyle(
                    color: DesignTokens.colors['black'],
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: DesignTokens.colors['black']!.withOpacity(0.8),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            decoration: BoxDecoration(
              color: DesignTokens.colors['black']!.withOpacity(0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
            ),
            child: Icon(
              _getRoleIcon(),
              size: 48,
              color: DesignTokens.colors['black']!.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String timeGreeting;
    
    if (hour < 12) {
      timeGreeting = 'Good morning';
    } else if (hour < 17) {
      timeGreeting = 'Good afternoon';
    } else {
      timeGreeting = 'Good evening';
    }
    
    return '$timeGreeting! 👋';
  }

  String _getSubtitle() {
    switch (_userRole) {
      case 'admin':
        return 'System overview and user management';
      case 'management':
        return 'Team performance and project insights';
      default:
        return 'Plan Weekly, Execute Daily';
    }
  }

  IconData _getRoleIcon() {
    switch (_userRole) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'management':
        return Icons.analytics;
      default:
        return Icons.dashboard;
    }
  }

  Widget _buildWarningAlert() {
    final warningLevel = _warnings['warning_level'] ?? 'none';
    final warningCount = _warnings['warning_count'] ?? 0;
    
    Color alertColor;
    IconData alertIcon;
    String alertMessage;
    
    switch (warningLevel) {
      case 'critical':
        alertColor = const Color(0xFFB37200);
        alertIcon = Icons.error;
        alertMessage = 'Critical: You have $warningCount overdue tasks!';
        break;
      case 'high':
        alertColor = DesignTokens.primaryOrange;
        alertIcon = Icons.warning;
        alertMessage = 'Warning: You have $warningCount overdue tasks';
        break;
      case 'medium':
        alertColor = const Color(0xFFFFCA1A);
        alertIcon = Icons.schedule;
        alertMessage = 'Notice: You have $warningCount tasks due today';
        break;
      default:
        return const SizedBox.shrink();
    }
    
    return ProfessionalCard(
      backgroundColor: alertColor.withOpacity(0.1),
      child: Row(
        children: [
          Icon(alertIcon, color: alertColor, size: 24),
          const SizedBox(width: DesignTokens.spacing12),
          Expanded(
            child: Text(
              alertMessage,
              style: TextStyle(
                color: alertColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ProfessionalButton(
            text: 'View Tasks',
            size: ButtonSize.small,
            variant: ButtonVariant.outline,
            onPressed: () => _viewOverdueTasks(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return StaggeredListAnimation(
      children: [
        _buildStatsGrid(),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final statsCards = _getStatsCards();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 5 : 
                              constraints.maxWidth > 800 ? 3 : 2;
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: DesignTokens.spacing16,
            mainAxisSpacing: DesignTokens.spacing16,
            childAspectRatio: 1.2,
          ),
          itemCount: statsCards.length,
          itemBuilder: (context, index) => statsCards[index],
        );
      },
    );
  }

  List<Widget> _getStatsCards() {
    switch (_userRole) {
      case 'admin':
        return _getAdminStatsCards();
      case 'management':
        return _getManagementStatsCards();
      default:
        return _getEmployeeStatsCards();
    }
  }

  List<Widget> _getAdminStatsCards() {
    return [
      StatsCard(
        title: 'Total Users',
        value: '${_stats['total_users'] ?? 0}',
        icon: Icons.people,
        iconColor: DesignTokens.primaryOrange,
        onTap: () => _navigateToUsers(),
      ),
      StatsCard(
        title: 'Active Users',
        value: '${_stats['active_users'] ?? 0}',
        icon: Icons.person,
        iconColor: Colors.green,
        subtitle: '${_stats['completion_rate'] ?? 0}% active',
      ),
      StatsCard(
        title: 'Total Projects',
        value: '${_stats['total_projects'] ?? 0}',
        icon: Icons.folder,
        iconColor: DesignTokens.primaryOrange,
        onTap: () => _navigateToProjects(),
      ),
      StatsCard(
        title: 'Total Tasks',
        value: '${_stats['total_tasks'] ?? 0}',
        icon: Icons.task,
        iconColor: Colors.purple,
      ),
      StatsCard(
        title: 'Overdue Tasks',
        value: '${_stats['overdue_tasks'] ?? 0}',
        icon: Icons.warning,
        iconColor: const Color(0xFFB37200),
        onTap: () => _viewOverdueTasks(),
      ),
    ];
  }

  List<Widget> _getManagementStatsCards() {
    return [
      StatsCard(
        title: 'Active Projects',
        value: '${_stats['active_projects'] ?? 0}',
        icon: Icons.folder_open,
        iconColor: DesignTokens.primaryOrange,
      ),
      StatsCard(
        title: 'Team Members',
        value: '${_stats['team_members'] ?? 0}',
        icon: Icons.group,
        iconColor: Colors.green,
      ),
      StatsCard(
        title: 'Total Tasks',
        value: '${_stats['total_tasks'] ?? 0}',
        icon: Icons.task,
        iconColor: DesignTokens.primaryOrange,
      ),
      StatsCard(
        title: 'Completed',
        value: '${_stats['completed_tasks'] ?? 0}',
        icon: Icons.check_circle,
        iconColor: Colors.green,
        subtitle: '${_stats['completion_rate'] ?? 0}% completion',
      ),
      StatsCard(
        title: 'Delayed',
        value: '${_stats['delayed_tasks'] ?? 0}',
        icon: Icons.schedule,
        iconColor: Colors.red,
      ),
    ];
  }

  List<Widget> _getEmployeeStatsCards() {
    return [
      StatsCard(
        title: 'Total Tasks',
        value: '${_stats['total_tasks'] ?? 0}',
        icon: Icons.task,
        iconColor: DesignTokens.primaryOrange,
        onTap: () => _filterTasks('all'),
      ),
      StatsCard(
        title: 'Pending',
        value: '${_stats['pending_tasks'] ?? 0}',
        icon: Icons.schedule,
        iconColor: Colors.grey,
        onTap: () => _filterTasks('pending'),
      ),
      StatsCard(
        title: 'In Progress',
        value: '${_stats['in_progress_tasks'] ?? 0}',
        icon: Icons.play_circle,
        iconColor: DesignTokens.primaryOrange,
        onTap: () => _filterTasks('in_progress'),
      ),
      StatsCard(
        title: 'Completed',
        value: '${_stats['completed_tasks'] ?? 0}',
        icon: Icons.check_circle,
        iconColor: Colors.green,
        subtitle: '${_stats['completion_rate'] ?? 0}% completion',
        onTap: () => _filterTasks('completed'),
      ),
      StatsCard(
        title: 'Delayed',
        value: '${_stats['delayed_tasks'] ?? 0}',
        icon: Icons.warning,
        iconColor: const Color(0xFFB37200),
        onTap: () => _filterTasks('delayed'),
      ),
    ];
  }

  Widget _buildRoleBasedContent() {
    switch (_userRole) {
      case 'admin':
        return _buildAdminContent();
      case 'management':
        return _buildManagementContent();
      default:
        return _buildEmployeeContent();
    }
  }

  Widget _buildAdminContent() {
    return Column(
      children: [
        // Quick Actions for Admin
        _buildQuickActions(),
        const SizedBox(height: DesignTokens.spacing24),
        
        // System Overview
        _buildSystemOverview(),
      ],
    );
  }

  Widget _buildManagementContent() {
    return Column(
      children: [
        // Team Performance
        _buildTeamPerformance(),
        const SizedBox(height: DesignTokens.spacing24),
        
        // Project Overview
        _buildProjectOverview(),
      ],
    );
  }

  Widget _buildEmployeeContent() {
    return Column(
      children: [
        // This Week Tasks
        _buildThisWeekTasks(),
        const SizedBox(height: DesignTokens.spacing24),
        
        // Quick Actions
        _buildEmployeeQuickActions(),
      ],
    );
  }

  Widget _buildQuickActions() {
    return ProfessionalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: DesignTokens.colors['black'],
            ),
          ),
          const SizedBox(height: DesignTokens.spacing16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: DesignTokens.spacing16,
            mainAxisSpacing: DesignTokens.spacing16,
            childAspectRatio: 1.5,
            children: [
              QuickActionButton(
                title: 'User Management',
                subtitle: 'Manage users',
                icon: Icons.people,
                onTap: () => _navigateToUsers(),
              ),
              QuickActionButton(
                title: 'System Settings',
                subtitle: 'Configure system',
                icon: Icons.settings,
                onTap: () => _navigateToSettings(),
              ),
              QuickActionButton(
                title: 'Reports',
                subtitle: 'View reports',
                icon: Icons.analytics,
                onTap: () => _navigateToReports(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSystemOverview() {
    return ProfessionalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: DesignTokens.colors['black'],
            ),
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            'System is running smoothly. All services are operational.',
            style: TextStyle(
              color: DesignTokens.colors['gray600'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamPerformance() {
    return ProfessionalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Team Performance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: DesignTokens.colors['black'],
            ),
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            'Team performance metrics will be displayed here.',
            style: TextStyle(
              color: DesignTokens.colors['gray600'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectOverview() {
    return ProfessionalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: DesignTokens.colors['black'],
            ),
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            'Project overview and progress will be displayed here.',
            style: TextStyle(
              color: DesignTokens.colors['gray600'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThisWeekTasks() {
    return ProfessionalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'This Week\'s Tasks',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: DesignTokens.colors['black'],
                ),
              ),
              Text(
                '${_thisWeekTasks.length} tasks',
                style: TextStyle(
                  color: DesignTokens.colors['gray600'],
                ),
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing16),
          if (_thisWeekTasks.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.task_alt,
                    size: 48,
                    color: DesignTokens.colors['gray400'],
                  ),
                  const SizedBox(height: DesignTokens.spacing8),
                  Text(
                    'No tasks this week',
                    style: TextStyle(
                      color: DesignTokens.colors['gray600'],
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _thisWeekTasks.length.clamp(0, 5),
              separatorBuilder: (context, index) => 
                  const SizedBox(height: DesignTokens.spacing8),
              itemBuilder: (context, index) {
                final task = _thisWeekTasks[index];
                return _buildTaskItem(task);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmployeeQuickActions() {
    return ProfessionalCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: DesignTokens.colors['black'],
            ),
          ),
          const SizedBox(height: DesignTokens.spacing16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: DesignTokens.spacing16,
            mainAxisSpacing: DesignTokens.spacing16,
            childAspectRatio: 2,
            children: [
              QuickActionButton(
                title: 'Create Task',
                subtitle: 'Add new task',
                icon: Icons.add_task,
                onTap: () => _createTask(),
              ),
              QuickActionButton(
                title: 'View All Tasks',
                subtitle: 'See all tasks',
                icon: Icons.list,
                onTap: () => _viewAllTasks(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing12),
      decoration: BoxDecoration(
        color: DesignTokens.colors['gray50'],
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: DesignTokens.colors['gray200']!),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(task['status']),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: DesignTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] ?? 'Untitled Task',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: DesignTokens.colors['black'],
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing4),
                Text(
                  task['project_name'] ?? 'Unknown Project',
                  style: TextStyle(
                    fontSize: 12,
                    color: DesignTokens.colors['gray600'],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing8,
              vertical: DesignTokens.spacing4,
            ),
            decoration: BoxDecoration(
              color: _getStatusColor(task['status']).withOpacity(0.1),
              borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
            ),
            child: Text(
              task['status'] ?? 'Open',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(task['status']),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completed':
      case 'done':
        return Colors.green;
      case 'in progress':
        return DesignTokens.primaryOrange;
      case 'delayed':
        return Colors.red;
      case 'on hold':
      case 'hold':
        return Colors.amber;
      default:
        return DesignTokens.colors['gray500']!;
    }
  }

  // Navigation methods
  void _navigateToUsers() => context.go('/admin/users');
  void _navigateToProjects() => context.go('/projects');
  void _navigateToSettings() => context.go('/admin/settings');
  void _navigateToReports() => context.go('/admin/reports');
  void _viewOverdueTasks() => context.go('/tasks?filter=overdue');
  void _filterTasks(String filter) => context.go('/tasks?filter=$filter');
  void _createTask() => context.go('/tasks/create');
  void _viewAllTasks() => context.go('/tasks');
}
