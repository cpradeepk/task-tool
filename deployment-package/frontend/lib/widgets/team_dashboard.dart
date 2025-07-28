import 'package:flutter/material.dart';
import 'dart:async';
import '../models/activity.dart';
import '../models/notification.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../widgets/responsive_layout.dart';

class TeamDashboard extends StatefulWidget {
  final String? projectId;

  const TeamDashboard({
    Key? key,
    this.projectId,
  }) : super(key: key);

  @override
  State<TeamDashboard> createState() => _TeamDashboardState();
}

class _TeamDashboardState extends State<TeamDashboard> {
  final SocketService _socketService = SocketService();
  
  List<ActivityLog> _recentActivities = [];
  List<AppNotification> _recentNotifications = [];
  Map<String, dynamic> _teamStats = {};
  Map<String, dynamic> _projectStats = {};
  
  bool _isLoading = true;
  String? _error;
  
  StreamSubscription? _activitySubscription;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupSocketListeners();
  }

  @override
  void dispose() {
    _activitySubscription?.cancel();
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    _activitySubscription = _socketService.activityStream.listen((data) {
      if (data['type'] == 'new_activity') {
        final activity = ActivityLog.fromJson(data);
        setState(() {
          _recentActivities.insert(0, activity);
          if (_recentActivities.length > 10) {
            _recentActivities.removeLast();
          }
        });
      }
    });

    _notificationSubscription = _socketService.notificationStream.listen((data) {
      if (data['type'] == 'new_notification') {
        final notification = AppNotification.fromJson(data);
        setState(() {
          _recentNotifications.insert(0, notification);
          if (_recentNotifications.length > 5) {
            _recentNotifications.removeLast();
          }
        });
      }
    });
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final futures = <Future>[
        _loadRecentActivities(),
        _loadRecentNotifications(),
        _loadTeamStats(),
      ];

      if (widget.projectId != null) {
        futures.add(_loadProjectStats());
      }

      await Future.wait(futures);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final response = await ApiService.get('/activity/recent', queryParams: {
        'limit': '10',
        if (widget.projectId != null) 'projectId': widget.projectId!,
      });

      final activities = (response['activities'] as List<dynamic>)
          .map((data) => ActivityLog.fromJson(data))
          .toList();

      setState(() {
        _recentActivities = activities;
      });
    } catch (e) {
      debugPrint('Error loading recent activities: $e');
    }
  }

  Future<void> _loadRecentNotifications() async {
    try {
      final response = await ApiService.get('/notifications', queryParams: {
        'limit': '5',
        'isRead': 'false',
      });

      final notifications = (response['notifications'] as List<dynamic>)
          .map((data) => AppNotification.fromJson(data))
          .toList();

      setState(() {
        _recentNotifications = notifications;
      });
    } catch (e) {
      debugPrint('Error loading recent notifications: $e');
    }
  }

  Future<void> _loadTeamStats() async {
    try {
      // This would be a custom endpoint for team statistics
      final response = await ApiService.get('/dashboard/team-stats');
      
      setState(() {
        _teamStats = response;
      });
    } catch (e) {
      debugPrint('Error loading team stats: $e');
      // Set default stats if endpoint doesn't exist
      setState(() {
        _teamStats = {
          'totalTasks': 0,
          'completedTasks': 0,
          'overdueTasks': 0,
          'activeProjects': 0,
          'teamMembers': 0,
        };
      });
    }
  }

  Future<void> _loadProjectStats() async {
    if (widget.projectId == null) return;

    try {
      final response = await ApiService.get('/activity/projects/${widget.projectId}/stats');
      
      setState(() {
        _projectStats = response;
      });
    } catch (e) {
      debugPrint('Error loading project stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          _buildRecentNotifications(),
          const SizedBox(height: 24),
          _buildRecentActivities(),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildStatsCards(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildRecentActivities(),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildRecentNotifications(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildStatsCards(),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _buildRecentActivities(),
              ),
              const SizedBox(width: 24),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildRecentNotifications(),
                    const SizedBox(height: 24),
                    _buildQuickActions(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading dashboard'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return GridView.count(
      crossAxisCount: ResponsiveLayout.isDesktop(context) ? 5 : 
                     ResponsiveLayout.isTablet(context) ? 3 : 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          'Total Tasks',
          '${_teamStats['totalTasks'] ?? 0}',
          Icons.task,
          Colors.blue,
        ),
        _buildStatCard(
          'Completed',
          '${_teamStats['completedTasks'] ?? 0}',
          Icons.check_circle,
          Colors.green,
        ),
        _buildStatCard(
          'Overdue',
          '${_teamStats['overdueTasks'] ?? 0}',
          Icons.warning,
          Colors.red,
        ),
        _buildStatCard(
          'Projects',
          '${_teamStats['activeProjects'] ?? 0}',
          Icons.folder,
          Colors.orange,
        ),
        _buildStatCard(
          'Team Members',
          '${_teamStats['teamMembers'] ?? 0}',
          Icons.people,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Recent Activity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // Navigate to full activity feed
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recentActivities.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.timeline, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No recent activity'),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentActivities.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final activity = _recentActivities[index];
                  return _buildActivityItem(activity);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(ActivityLog activity) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getActivityColor(activity.action).withOpacity(0.1),
        child: Icon(
          _getActivityIcon(activity.action),
          color: _getActivityColor(activity.action),
          size: 20,
        ),
      ),
      title: Text(
        activity.description,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'by ${activity.userName}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            _formatTime(activity.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
      dense: true,
    );
  }

  Widget _buildRecentNotifications() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_recentNotifications.isNotEmpty)
                  Badge(
                    label: Text('${_recentNotifications.length}'),
                    child: IconButton(
                      icon: const Icon(Icons.notifications),
                      onPressed: () {
                        // Navigate to notification center
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_recentNotifications.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No new notifications'),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentNotifications.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final notification = _recentNotifications[index];
                  return _buildNotificationItem(notification);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(AppNotification notification) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _getNotificationColor(notification.type).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getNotificationIcon(notification.type),
          color: _getNotificationColor(notification.type),
          size: 16,
        ),
      ),
      title: Text(
        notification.title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        notification.message,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatTime(notification.createdAt),
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[500],
        ),
      ),
      dense: true,
      onTap: () {
        // Handle notification tap
      },
    );
  }

  Widget _buildQuickActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2,
              children: [
                _buildQuickActionButton(
                  'New Task',
                  Icons.add_task,
                  Colors.blue,
                  () {
                    // Navigate to create task
                  },
                ),
                _buildQuickActionButton(
                  'New Project',
                  Icons.create_new_folder,
                  Colors.green,
                  () {
                    // Navigate to create project
                  },
                ),
                _buildQuickActionButton(
                  'Team Chat',
                  Icons.chat,
                  Colors.orange,
                  () {
                    // Navigate to team chat
                  },
                ),
                _buildQuickActionButton(
                  'Reports',
                  Icons.analytics,
                  Colors.purple,
                  () {
                    // Navigate to reports
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.taskCreated:
        return Colors.blue;
      case ActivityType.taskCompleted:
        return Colors.green;
      case ActivityType.taskUpdated:
        return Colors.orange;
      case ActivityType.taskDeleted:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.taskCreated:
        return Icons.add_task;
      case ActivityType.taskCompleted:
        return Icons.check_circle;
      case ActivityType.taskUpdated:
        return Icons.edit;
      case ActivityType.taskDeleted:
        return Icons.delete;
      case ActivityType.commentAdded:
        return Icons.comment;
      case ActivityType.fileUploaded:
        return Icons.upload_file;
      default:
        return Icons.timeline;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return Colors.blue;
      case NotificationType.taskCompleted:
        return Colors.green;
      case NotificationType.taskOverdue:
        return Colors.red;
      case NotificationType.commentAdded:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.taskAssigned:
        return Icons.assignment_ind;
      case NotificationType.taskCompleted:
        return Icons.check_circle;
      case NotificationType.taskOverdue:
        return Icons.warning;
      case NotificationType.commentAdded:
        return Icons.comment;
      default:
        return Icons.info;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
