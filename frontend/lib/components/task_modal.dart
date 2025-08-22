import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/theme_provider.dart';
import 'professional_card.dart';
import 'professional_buttons.dart';
import 'animations.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

/// Rich task editing modal with history, comments, and support team management
class TaskEditModal extends StatefulWidget {
  final Map<String, dynamic>? task;
  final int? projectId;
  final int? moduleId;
  final VoidCallback? onSaved;

  const TaskEditModal({
    super.key,
    this.task,
    this.projectId,
    this.moduleId,
    this.onSaved,
  });

  @override
  State<TaskEditModal> createState() => _TaskEditModalState();
}

class _TaskEditModalState extends State<TaskEditModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _commentController = TextEditingController();
  
  // Form data
  String _selectedStatus = 'Yet to Start';
  String _selectedPriority = 'Medium';
  DateTime? _dueDate;
  String? _assignedTo;
  List<String> _supportTeam = [];
  
  // State
  bool _isLoading = false;
  bool _isSaving = false;
  List<dynamic> _comments = [];
  List<dynamic> _history = [];
  List<dynamic> _users = [];
  
  final List<String> _statuses = [
    'Yet to Start',
    'In Progress',
    'Completed',
    'Delayed',
    'On Hold'
  ];
  
  final List<String> _priorities = ['High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeForm();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _initializeForm() {
    if (widget.task != null) {
      final task = widget.task!;
      _titleController.text = task['title'] ?? '';
      _descriptionController.text = task['description'] ?? '';
      _selectedStatus = task['status'] ?? 'Yet to Start';
      _selectedPriority = task['priority'] ?? 'Medium';
      _assignedTo = task['assigned_to'];
      _supportTeam = task['support_team'] != null 
          ? List<String>.from(task['support_team'])
          : [];
      
      if (task['due_date'] != null) {
        _dueDate = DateTime.parse(task['due_date']);
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    await Future.wait([
      _loadUsers(),
      if (widget.task != null) ...[
        _loadComments(),
        _loadHistory(),
      ],
    ]);
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadUsers() async {
    try {
      final jwt = await _getJwt();
      if (jwt == null) return;

      final response = await http.get(
        Uri.parse('$apiBase/task/api/users'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _users = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  Future<void> _loadComments() async {
    if (widget.task == null) return;
    
    try {
      final jwt = await _getJwt();
      if (jwt == null) return;

      final response = await http.get(
        Uri.parse('$apiBase/task/api/tasks/${widget.task!['id']}/comments'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _comments = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading comments: $e');
    }
  }

  Future<void> _loadHistory() async {
    if (widget.task == null) return;
    
    try {
      final jwt = await _getJwt();
      if (jwt == null) return;

      final response = await http.get(
        Uri.parse('$apiBase/task/api/tasks/${widget.task!['id']}/history'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (response.statusCode == 200) {
        setState(() => _history = jsonDecode(response.body));
      }
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
        child: ScaleInAnimation(
          child: ProfessionalCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Header
                _buildHeader(),
                
                // Tab bar
                _buildTabBar(),
                
                // Tab content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildDetailsTab(),
                            _buildCommentsTab(),
                            _buildHistoryTab(),
                            _buildSupportTeamTab(),
                          ],
                        ),
                ),
                
                // Footer
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing20),
      decoration: BoxDecoration(
        color: DesignTokens.colors['gray50'],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(DesignTokens.radiusLarge),
          topRight: Radius.circular(DesignTokens.radiusLarge),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.task != null ? Icons.edit : Icons.add_task,
            color: DesignTokens.primaryOrange,
            size: 24,
          ),
          const SizedBox(width: DesignTokens.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task != null ? 'Edit Task' : 'Create New Task',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.colors['black'],
                  ),
                ),
                if (widget.task != null) ...[
                  const SizedBox(height: DesignTokens.spacing4),
                  Text(
                    widget.task!['task_id_formatted'] ?? 'JSR-${widget.task!['id']}',
                    style: TextStyle(
                      fontSize: 14,
                      color: DesignTokens.colors['gray600'],
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close,
              color: DesignTokens.colors['gray600'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: DesignTokens.colors['gray200']!),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: DesignTokens.primaryOrange,
        unselectedLabelColor: DesignTokens.colors['gray600'],
        indicatorColor: DesignTokens.primaryOrange,
        tabs: [
          const Tab(text: 'Details'),
          Tab(text: 'Comments (${_comments.length})'),
          Tab(text: 'History (${_history.length})'),
          Tab(text: 'Support Team (${_supportTeam.length})'),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DesignTokens.spacing20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Task Title *',
                hintText: 'Enter task title',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Task title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignTokens.spacing16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Enter task description',
              ),
              maxLines: 4,
            ),
            const SizedBox(height: DesignTokens.spacing16),
            
            // Status and Priority row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _statuses.map((status) => DropdownMenuItem(
                      value: status,
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            size: 12,
                            color: _getStatusColor(status),
                          ),
                          const SizedBox(width: 8),
                          Text(status),
                        ],
                      ),
                    )).toList(),
                    onChanged: (value) {
                      setState(() => _selectedStatus = value!);
                    },
                  ),
                ),
                const SizedBox(width: DesignTokens.spacing16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: _priorities.map((priority) => DropdownMenuItem(
                      value: priority,
                      child: Row(
                        children: [
                          Icon(
                            Icons.flag,
                            size: 12,
                            color: _getPriorityColor(priority),
                          ),
                          const SizedBox(width: 8),
                          Text(priority),
                        ],
                      ),
                    )).toList(),
                    onChanged: (value) {
                      setState(() => _selectedPriority = value!);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing16),
            
            // Assignee and Due Date row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _assignedTo,
                    decoration: const InputDecoration(labelText: 'Assigned To'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Unassigned')),
                      ..._users.map((user) => DropdownMenuItem(
                        value: user['id'].toString(),
                        child: Text(user['email'] ?? user['name'] ?? 'Unknown'),
                      )),
                    ],
                    onChanged: (value) {
                      setState(() => _assignedTo = value);
                    },
                  ),
                ),
                const SizedBox(width: DesignTokens.spacing16),
                Expanded(
                  child: InkWell(
                    onTap: _selectDueDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Due Date'),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _dueDate != null
                                  ? '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}'
                                  : 'Select date',
                              style: TextStyle(
                                color: _dueDate != null
                                    ? DesignTokens.colors['black']
                                    : DesignTokens.colors['gray500'],
                              ),
                            ),
                          ),
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: DesignTokens.colors['gray600'],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsTab() {
    return Column(
      children: [
        // Comments list
        Expanded(
          child: _comments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.comment,
                        size: 48,
                        color: DesignTokens.colors['gray400'],
                      ),
                      const SizedBox(height: DesignTokens.spacing16),
                      Text(
                        'No comments yet',
                        style: TextStyle(
                          color: DesignTokens.colors['gray600'],
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(DesignTokens.spacing16),
                  itemCount: _comments.length,
                  separatorBuilder: (context, index) => 
                      const SizedBox(height: DesignTokens.spacing16),
                  itemBuilder: (context, index) {
                    final comment = _comments[index];
                    return _buildCommentItem(comment);
                  },
                ),
        ),
        
        // Add comment section
        if (widget.task != null) _buildAddCommentSection(),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return _history.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 48,
                  color: DesignTokens.colors['gray400'],
                ),
                const SizedBox(height: DesignTokens.spacing16),
                Text(
                  'No history available',
                  style: TextStyle(
                    color: DesignTokens.colors['gray600'],
                  ),
                ),
              ],
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(DesignTokens.spacing16),
            itemCount: _history.length,
            separatorBuilder: (context, index) => 
                const SizedBox(height: DesignTokens.spacing12),
            itemBuilder: (context, index) {
              final historyItem = _history[index];
              return _buildHistoryItem(historyItem);
            },
          );
  }

  Widget _buildSupportTeamTab() {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Support Team Members',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.colors['black'],
                ),
              ),
              const Spacer(),
              ProfessionalButton(
                text: 'Add Member',
                size: ButtonSize.small,
                icon: Icons.person_add,
                onPressed: _addSupportMember,
              ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing16),
          
          if (_supportTeam.isEmpty)
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.support_agent,
                    size: 48,
                    color: DesignTokens.colors['gray400'],
                  ),
                  const SizedBox(height: DesignTokens.spacing16),
                  Text(
                    'No support team members assigned',
                    style: TextStyle(
                      color: DesignTokens.colors['gray600'],
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                itemCount: _supportTeam.length,
                separatorBuilder: (context, index) => 
                    const SizedBox(height: DesignTokens.spacing8),
                itemBuilder: (context, index) {
                  final memberId = _supportTeam[index];
                  final user = _users.firstWhere(
                    (u) => u['id'].toString() == memberId,
                    orElse: () => {'email': 'Unknown User'},
                  );
                  
                  return ProfessionalCard(
                    padding: const EdgeInsets.all(DesignTokens.spacing12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: DesignTokens.primaryOrange,
                          child: Text(
                            (user['email'] ?? 'U').substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: DesignTokens.colors['black'],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: DesignTokens.spacing12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user['name'] ?? user['email'] ?? 'Unknown User',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: DesignTokens.colors['black'],
                                ),
                              ),
                              if (user['email'] != null)
                                Text(
                                  user['email'],
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: DesignTokens.colors['gray600'],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeSupportMember(memberId),
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment) {
    return ProfessionalCard(
      padding: const EdgeInsets.all(DesignTokens.spacing12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: DesignTokens.primaryOrange,
                child: Text(
                  (comment['author_email'] ?? 'U').substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    color: DesignTokens.colors['black'],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: DesignTokens.spacing8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment['author_name'] ?? comment['author_email'] ?? 'Unknown',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DesignTokens.colors['black'],
                      ),
                    ),
                    Text(
                      _formatDateTime(comment['created_at']),
                      style: TextStyle(
                        fontSize: 10,
                        color: DesignTokens.colors['gray500'],
                      ),
                    ),
                  ],
                ),
              ),
              if (comment['is_internal'] == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Internal',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DesignTokens.spacing8),
          Text(
            comment['content'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: DesignTokens.colors['black'],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> historyItem) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: _getHistoryColor(historyItem['change_type']),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: DesignTokens.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getHistoryDescription(historyItem),
                style: TextStyle(
                  fontSize: 14,
                  color: DesignTokens.colors['black'],
                ),
              ),
              const SizedBox(height: DesignTokens.spacing4),
              Text(
                '${historyItem['changed_by_name'] ?? historyItem['changed_by_email'] ?? 'Unknown'} • ${_formatDateTime(historyItem['changed_at'])}',
                style: TextStyle(
                  fontSize: 12,
                  color: DesignTokens.colors['gray500'],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAddCommentSection() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: DesignTokens.colors['gray50'],
        border: Border(
          top: BorderSide(color: DesignTokens.colors['gray200']!),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                hintText: 'Add a comment...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ),
          const SizedBox(width: DesignTokens.spacing12),
          ProfessionalButton(
            text: 'Post',
            size: ButtonSize.small,
            onPressed: _commentController.text.trim().isNotEmpty 
                ? _addComment 
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing20),
      decoration: BoxDecoration(
        color: DesignTokens.colors['gray50'],
        border: Border(
          top: BorderSide(color: DesignTokens.colors['gray200']!),
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(DesignTokens.radiusLarge),
          bottomRight: Radius.circular(DesignTokens.radiusLarge),
        ),
      ),
      child: Row(
        children: [
          const Spacer(),
          ProfessionalButton(
            text: 'Cancel',
            variant: ButtonVariant.outline,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: DesignTokens.spacing12),
          ProfessionalButton(
            text: widget.task != null ? 'Update Task' : 'Create Task',
            isLoading: _isSaving,
            onPressed: _saveTask,
          ),
        ],
      ),
    );
  }

  Future<void> _selectDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    
    if (date != null) {
      setState(() => _dueDate = date);
    }
  }

  void _addSupportMember() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Support Team Member'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _users
                .where((user) => !_supportTeam.contains(user['id'].toString()))
                .map((user) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: DesignTokens.primaryOrange,
                    child: Text(
                      (user['email'] ?? 'U').substring(0, 1).toUpperCase(),
                      style: TextStyle(color: DesignTokens.colors['black']),
                    ),
                  ),
                  title: Text(user['name'] ?? user['email'] ?? 'Unknown'),
                  subtitle: user['email'] != null ? Text(user['email']) : null,
                  onTap: () {
                    setState(() {
                      _supportTeam.add(user['id'].toString());
                    });
                    Navigator.of(context).pop();
                  },
                ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _removeSupportMember(String memberId) {
    setState(() {
      _supportTeam.remove(memberId);
    });
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;
    
    try {
      final jwt = await _getJwt();
      if (jwt == null) return;

      final response = await http.post(
        Uri.parse('$apiBase/task/api/tasks/${widget.task!['id']}/comments'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'content': _commentController.text.trim(),
          'is_internal': false,
        }),
      );

      if (response.statusCode == 201) {
        _commentController.clear();
        await _loadComments();
      }
    } catch (e) {
      print('Error adding comment: $e');
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final jwt = await _getJwt();
      if (jwt == null) return;

      final taskData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'status': _selectedStatus,
        'priority': _selectedPriority,
        'assigned_to': _assignedTo,
        'due_date': _dueDate?.toIso8601String(),
        'support_team': _supportTeam,
        if (widget.projectId != null) 'project_id': widget.projectId,
        if (widget.moduleId != null) 'module_id': widget.moduleId,
      };

      final response = widget.task != null
          ? await http.put(
              Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks/${widget.task!['id']}'),
              headers: {
                'Authorization': 'Bearer $jwt',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(taskData),
            )
          : await http.post(
              Uri.parse('$apiBase/task/api/projects/${widget.projectId}/tasks'),
              headers: {
                'Authorization': 'Bearer $jwt',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(taskData),
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.onSaved?.call();
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error saving task: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'urgent':
        return Colors.red;
      case 'medium':
        return DesignTokens.primaryOrange;
      case 'low':
        return Colors.green;
      default:
        return DesignTokens.colors['gray500']!;
    }
  }

  Color _getHistoryColor(String changeType) {
    switch (changeType.toLowerCase()) {
      case 'created':
        return Colors.green;
      case 'updated':
      case 'status_changed':
        return DesignTokens.primaryOrange;
      case 'support_added':
      case 'support_removed':
        return Colors.blue;
      case 'comment_added':
        return Colors.purple;
      default:
        return DesignTokens.colors['gray500']!;
    }
  }

  String _getHistoryDescription(Map<String, dynamic> historyItem) {
    final changeType = historyItem['change_type'];
    final comment = historyItem['comment'];
    
    if (comment != null && comment.isNotEmpty) {
      return comment;
    }
    
    switch (changeType) {
      case 'created':
        return 'Task was created';
      case 'updated':
        return 'Task was updated';
      case 'status_changed':
        return 'Task status was changed';
      case 'support_added':
        return 'Support team members were added';
      case 'support_removed':
        return 'Support team members were removed';
      case 'comment_added':
        return 'Comment was added';
      default:
        return 'Task was modified';
    }
  }

  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return dateTimeStr;
    }
  }
}
