import 'package:flutter/material.dart';
import 'dart:async';
import '../models/task.dart';
import '../models/notification.dart';
import '../models/activity.dart';
import '../models/time_entry.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../services/notification_service.dart';
import '../services/time_tracking_service.dart';
import '../services/chat_service.dart';
import '../widgets/team_dashboard.dart';
import '../widgets/notification_center.dart';
import '../widgets/chat_interface.dart';
import '../widgets/enhanced_task_card.dart';
import '../widgets/responsive_layout.dart';

class IntegratedDashboard extends StatefulWidget {
  final String? projectId;

  const IntegratedDashboard({
    Key? key,
    this.projectId,
  }) : super(key: key);

  @override
  State<IntegratedDashboard> createState() => _IntegratedDashboardState();
}

class _IntegratedDashboardState extends State<IntegratedDashboard> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Services
  final SocketService _socketService = SocketService();
  final NotificationService _notificationService = NotificationService();
  final TimeTrackingService _timeTrackingService = TimeTrackingService();
  final ChatService _chatService = ChatService();

  // Data
  List<Task> _recentTasks = [];
  List<AppNotification> _recentNotifications = [];
  List<ActivityLog> _recentActivities = [];
  ActiveTimer? _activeTimer;
  int _unreadNotifications = 0;
  
  // State
  bool _isLoading = true;
  String? _error;
  
  // Stream subscriptions
  StreamSubscription? _taskUpdateSubscription;
  StreamSubscription? _notificationSubscription;
  StreamSubscription? _timerSubscription;
  StreamSubscription? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeServices();
    _loadDashboardData();
    _setupRealTimeListeners();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _taskUpdateSubscription?.cancel();
    _notificationSubscription?.cancel();
    _timerSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      await Future.wait([
        _socketService.connect(),
        _notificationService.initialize(),
        _chatService.initialize(),
      ]);
    } catch (e) {
      debugPrint('Error initializing services: $e');
    }
  }

  void _setupRealTimeListeners() {
    // Task updates
    _taskUpdateSubscription = _socketService.taskUpdateStream.listen((data) {
      _handleTaskUpdate(data);
    });

    // Notifications
    _notificationSubscription = _socketService.notificationStream.listen((data) {
      _handleNotificationUpdate(data);
    });

    // Timer updates
    _timerSubscription = _timeTrackingService.activeTimerStream.listen((timer) {
      setState(() {
        _activeTimer = timer;
      });
    });

    // Connection status
    _connectionSubscription = _socketService.connectionStream.listen((isConnected) {
      if (isConnected) {
        _loadDashboardData(); // Refresh data when reconnected
      }
    });
  }

  void _handleTaskUpdate(Map<String, dynamic> data) {
    final type = data['type'];
    final taskData = data['task'];
    
    if (taskData != null) {
      final task = Task.fromJson(taskData);
      
      setState(() {
        switch (type) {
          case 'task_created':
          case 'task_updated':
            final index = _recentTasks.indexWhere((t) => t.id == task.id);
            if (index != -1) {
              _recentTasks[index] = task;
            } else {
              _recentTasks.insert(0, task);
              if (_recentTasks.length > 10) {
                _recentTasks.removeLast();
              }
            }
            break;
          case 'task_deleted':
            _recentTasks.removeWhere((t) => t.id == task.id);
            break;
        }
      });
    }
  }

  void _handleNotificationUpdate(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'new_notification':
        final notification = AppNotification.fromJson(data);
        setState(() {
          _recentNotifications.insert(0, notification);
          if (_recentNotifications.length > 5) {
            _recentNotifications.removeLast();
          }
          _unreadNotifications++;
        });
        
        // Show in-app notification
        _showInAppNotification(notification);
        break;
        
      case 'notification_read':
        setState(() {
          if (_unreadNotifications > 0) {
            _unreadNotifications--;
          }
        });
        break;
        
      case 'all_notifications_read':
        setState(() {
          _unreadNotifications = 0;
        });
        break;
    }
  }

  void _showInAppNotification(AppNotification notification) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _getNotificationIcon(notification.type),
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notification.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(notification.message),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: _getNotificationColor(notification.type),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            _tabController.animateTo(2); // Navigate to notifications tab
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _loadDashboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final futures = await Future.wait([
        _loadRecentTasks(),
        _loadRecentNotifications(),
        _loadRecentActivities(),
        _loadNotificationStats(),
      ]);

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

  Future<void> _loadRecentTasks() async {
    try {
      final response = await ApiService.get('/tasks', queryParams: {
        'limit': '10',
        'sortBy': 'updatedAt',
        'sortOrder': 'desc',
        if (widget.projectId != null) 'projectId': widget.projectId!,
      });

      setState(() {
        _recentTasks = (response['tasks'] as List<dynamic>)
            .map((data) => Task.fromJson(data))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading recent tasks: $e');
    }
  }

  Future<void> _loadRecentNotifications() async {
    try {
      final response = await _notificationService.getNotifications(limit: 5);
      setState(() {
        _recentNotifications = response['notifications'] as List<AppNotification>;
      });
    } catch (e) {
      debugPrint('Error loading recent notifications: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      final response = await ApiService.get('/activity/recent', queryParams: {
        'limit': '10',
        if (widget.projectId != null) 'projectId': widget.projectId!,
      });

      setState(() {
        _recentActivities = (response['activities'] as List<dynamic>)
            .map((data) => ActivityLog.fromJson(data))
            .toList();
      });
    } catch (e) {
      debugPrint('Error loading recent activities: $e');
    }
  }

  Future<void> _loadNotificationStats() async {
    try {
      final stats = await _notificationService.getNotificationStats();
      setState(() {
        _unreadNotifications = stats.unread;
      });
    } catch (e) {
      debugPrint('Error loading notification stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projectId != null ? 'Project Dashboard' : 'Team Dashboard'),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            const Tab(
              icon: Icon(Icons.dashboard),
              text: 'Overview',
            ),
            const Tab(
              icon: Icon(Icons.task),
              text: 'Tasks',
            ),
            Tab(
              icon: _unreadNotifications > 0
                  ? Badge(
                      label: Text('$_unreadNotifications'),
                      child: const Icon(Icons.notifications),
                    )
                  : const Icon(Icons.notifications),
              text: 'Notifications',
            ),
            const Tab(
              icon: Icon(Icons.chat),
              text: 'Chat',
            ),
          ],
        ),
        actions: [
          if (_activeTimer != null)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  StreamBuilder<ActiveTimer?>(
                    stream: _timeTrackingService.activeTimerStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return Text(
                          snapshot.data!.formattedElapsed,
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildTasksTab(),
                    _buildNotificationsTab(),
                    _buildChatTab(),
                  ],
                ),
    );
  }

  Widget _buildOverviewTab() {
    return TeamDashboard(projectId: widget.projectId);
  }

  Widget _buildTasksTab() {
    return RefreshIndicator(
      onRefresh: _loadRecentTasks,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recentTasks.length,
        itemBuilder: (context, index) {
          final task = _recentTasks[index];
          return EnhancedTaskCard(
            task: task,
            onTap: () => _navigateToTaskDetails(task),
            onStatusChanged: (updatedTask) => _updateTaskStatus(updatedTask),
            onPriorityChanged: (updatedTask) => _updateTaskPriority(updatedTask),
          );
        },
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return const NotificationCenter();
  }

  Widget _buildChatTab() {
    return ChatInterface(
      projectId: widget.projectId,
    );
  }

  // Helper methods
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
      case NotificationType.mention:
        return Icons.alternate_email;
      default:
        return Icons.info;
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
      case NotificationType.mention:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _navigateToTaskDetails(Task task) {
    Navigator.pushNamed(
      context,
      '/task-details',
      arguments: task,
    );
  }

  Future<void> _updateTaskStatus(Task task) async {
    try {
      await ApiService.put('/tasks/${task.id}', {
        'status': task.status.value,
      });
      
      // Update local state
      final index = _recentTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        setState(() {
          _recentTasks[index] = task;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task status: $e')),
      );
    }
  }

  Future<void> _updateTaskPriority(Task task) async {
    try {
      await ApiService.put('/tasks/${task.id}', {
        'priority': task.priority.value,
      });
      
      // Update local state
      final index = _recentTasks.indexWhere((t) => t.id == task.id);
      if (index != -1) {
        setState(() {
          _recentTasks[index] = task;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update task priority: $e')),
      );
    }
  }
}
