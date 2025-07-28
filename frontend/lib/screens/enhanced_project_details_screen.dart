import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../providers/auth_provider.dart';
import '../widgets/project_assignment_modal.dart';
import '../widgets/module_manager.dart';
import '../widgets/priority_editor.dart';
import '../widgets/timeline_view.dart';
import '../widgets/responsive_layout.dart';

class EnhancedProjectDetailsScreen extends StatefulWidget {
  final Project project;

  const EnhancedProjectDetailsScreen({
    Key? key,
    required this.project,
  }) : super(key: key);

  @override
  State<EnhancedProjectDetailsScreen> createState() => _EnhancedProjectDetailsScreenState();
}

class _EnhancedProjectDetailsScreenState extends State<EnhancedProjectDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final canManage = user?.isAdmin == true || 
                     ['ADMIN', 'PROJECT_MANAGER'].contains(user?.role);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.project.name),
            Text(
              'Enhanced Project Management',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2196F3),
        foregroundColor: Colors.white,
        actions: [
          // Priority Editor Button
          IconButton(
            icon: const Icon(Icons.priority_high),
            onPressed: () => _showPriorityEditor(),
            tooltip: 'Edit Priority',
          ),
          
          // Assignment Manager Button
          if (canManage)
            IconButton(
              icon: const Icon(Icons.group),
              onPressed: () => _showAssignmentModal(),
              tooltip: 'Manage Assignments',
            ),
          
          // More options
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  _editProject();
                  break;
                case 'timeline_issues':
                  _showTimelineIssues();
                  break;
                case 'critical_path':
                  _showCriticalPath();
                  break;
                case 'priority_requests':
                  _showPriorityRequests();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (canManage)
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit Project'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'timeline_issues',
                child: Row(
                  children: [
                    Icon(Icons.warning),
                    SizedBox(width: 8),
                    Text('Timeline Issues'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'critical_path',
                child: Row(
                  children: [
                    Icon(Icons.route),
                    SizedBox(width: 8),
                    Text('Critical Path'),
                  ],
                ),
              ),
              if (canManage)
                const PopupMenuItem(
                  value: 'priority_requests',
                  child: Row(
                    children: [
                      Icon(Icons.approval),
                      SizedBox(width: 8),
                      Text('Priority Requests'),
                    ],
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'Overview'),
            Tab(icon: Icon(Icons.view_module), text: 'Modules'),
            Tab(icon: Icon(Icons.timeline), text: 'Timeline'),
            Tab(icon: Icon(Icons.task), text: 'Tasks'),
          ],
        ),
      ),
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        tablet: _buildTabletLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildModulesTab(),
        _buildTimelineTab(),
        _buildTasksTab(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildModulesTab(),
        _buildTimelineTab(),
        _buildTasksTab(),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar with project info
        SizedBox(
          width: 300,
          child: Card(
            margin: const EdgeInsets.all(8),
            child: _buildProjectInfoSidebar(),
          ),
        ),
        
        // Main content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildModulesTab(),
              _buildTimelineTab(),
              _buildTasksTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProjectInfoSidebar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Project Information',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          
          _buildInfoItem('Status', widget.project.status),
          _buildInfoItem('Priority', widget.project.priority),
          _buildInfoItem('Type', widget.project.projectType ?? 'Not specified'),
          
          if (widget.project.startDate != null)
            _buildInfoItem('Start Date', 
              widget.project.startDate!.toLocal().toString().split(' ')[0]),
          
          if (widget.project.endDate != null)
            _buildInfoItem('End Date', 
              widget.project.endDate!.toLocal().toString().split(' ')[0]),
          
          const SizedBox(height: 16),
          
          if (widget.project.description != null) ...[
            Text(
              'Description',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(widget.project.description!),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Project statistics cards
          _buildStatisticsCards(),
          const SizedBox(height: 16),
          
          // Recent activity
          _buildRecentActivity(),
        ],
      ),
    );
  }

  Widget _buildModulesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ModuleManager(
        project: widget.project,
        onModuleChanged: () {
          // Refresh data if needed
        },
      ),
    );
  }

  Widget _buildTimelineTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TimelineView(
        project: widget.project,
      ),
    );
  }

  Widget _buildTasksTab() {
    return const Center(
      child: Text('Tasks view - integrate with existing task management'),
    );
  }

  Widget _buildStatisticsCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Tasks',
            '0', // This would come from API
            Icons.task,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Completed',
            '0%',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'In Progress',
            '0',
            Icons.work,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            'Overdue',
            '0',
            Icons.warning,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Activity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text('No recent activity'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriorityEditor() {
    showDialog(
      context: context,
      builder: (context) => PriorityEditor(
        entityType: 'PROJECT',
        entityId: widget.project.id,
        entityName: widget.project.name,
        currentPriority: widget.project.priority,
        currentPriorityNumber: widget.project.priorityOrder,
        onPriorityChanged: () {
          // Refresh project data
        },
      ),
    );
  }

  void _showAssignmentModal() {
    showDialog(
      context: context,
      builder: (context) => ProjectAssignmentModal(
        project: widget.project,
        onAssignmentChanged: () {
          // Refresh project data
        },
      ),
    );
  }

  void _editProject() {
    // Navigate to project edit screen
  }

  void _showTimelineIssues() {
    // Show timeline issues dialog
  }

  void _showCriticalPath() {
    // Show critical path analysis
  }

  void _showPriorityRequests() {
    // Navigate to priority requests screen
  }
}
