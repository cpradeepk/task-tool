import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Priority data
  List<Map<String, dynamic>> _priorities = [];
  
  // Status data
  List<Map<String, dynamic>> _statuses = [];
  
  // Project categories
  List<Map<String, dynamic>> _categories = [];
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMasterData();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _loadMasterData() async {
    setState(() => _isLoading = true);
    
    // Load default master data
    _priorities = [
      {
        'id': 1,
        'name': 'Important & Urgent',
        'description': 'Priority 1 - Eisenhower Matrix',
        'color': 'Orange',
        'order': 1,
      },
      {
        'id': 2,
        'name': 'Important & Not Urgent',
        'description': 'Priority 2 - Eisenhower Matrix',
        'color': 'Yellow',
        'order': 2,
      },
      {
        'id': 3,
        'name': 'Not Important & Urgent',
        'description': 'Priority 3 - Eisenhower Matrix',
        'color': 'White',
        'order': 3,
      },
      {
        'id': 4,
        'name': 'Not Important & Not Urgent',
        'description': 'Priority 4 - Eisenhower Matrix',
        'color': 'White',
        'order': 4,
      },
    ];

    _statuses = [
      {'id': 1, 'name': 'Open', 'color': 'White', 'description': 'Task is open and ready to start'},
      {'id': 2, 'name': 'In Progress', 'color': 'Yellow', 'description': 'Task is currently being worked on'},
      {'id': 3, 'name': 'Completed', 'color': 'Green', 'description': 'Task has been completed'},
      {'id': 4, 'name': 'Cancelled', 'color': 'Grey', 'description': 'Task has been cancelled'},
      {'id': 5, 'name': 'Hold', 'color': 'Brown', 'description': 'Task is on hold'},
      {'id': 6, 'name': 'Delayed', 'color': 'Red', 'description': 'Task is delayed'},
    ];

    _categories = [
      {'id': 1, 'name': 'Development', 'description': 'Software development projects'},
      {'id': 2, 'name': 'Design', 'description': 'UI/UX and graphic design projects'},
      {'id': 3, 'name': 'Marketing', 'description': 'Marketing and promotional projects'},
      {'id': 4, 'name': 'Research', 'description': 'Research and analysis projects'},
      {'id': 5, 'name': 'Operations', 'description': 'Operational and administrative projects'},
    ];

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Master Data Management',
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.settings, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Master Data Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _loadMasterData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.priority_high),
                      SizedBox(width: 8),
                      Text('Priorities'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag),
                      SizedBox(width: 8),
                      Text('Statuses'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.category),
                      SizedBox(width: 8),
                      Text('Categories'),
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
                      _buildPrioritiesTab(),
                      _buildStatusesTab(),
                      _buildCategoriesTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritiesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Task Priorities (Eisenhower Matrix)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddPriorityDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Priority'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _priorities.length,
              itemBuilder: (context, index) {
                final priority = _priorities[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getColorFromName(priority['color']),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${priority['order']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    title: Text(priority['name']),
                    subtitle: Text(priority['description']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editPriority(priority),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => _deletePriority(priority['id']),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Task Statuses',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddStatusDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Status'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _statuses.length,
              itemBuilder: (context, index) {
                final status = _statuses[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getColorFromName(status['color']),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Icon(Icons.flag),
                    ),
                    title: Text(status['name']),
                    subtitle: Text(status['description']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editStatus(status),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => _deleteStatus(status['id']),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Project Categories',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _showAddCategoryDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Category'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.category, color: Colors.blue),
                    title: Text(category['name']),
                    subtitle: Text(category['description']),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => _editCategory(category),
                          icon: const Icon(Icons.edit),
                        ),
                        IconButton(
                          onPressed: () => _deleteCategory(category['id']),
                          icon: const Icon(Icons.delete, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorFromName(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'orange':
        return Colors.orange;
      case 'yellow':
        return Colors.yellow;
      case 'green':
        return Colors.green;
      case 'red':
        return Colors.red;
      case 'brown':
        return Colors.brown;
      case 'grey':
        return Colors.grey;
      case 'white':
      default:
        return Colors.white;
    }
  }

  void _showAddPriorityDialog() {
    // TODO: Implement add priority dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Priority functionality - Coming Soon')),
    );
  }

  void _editPriority(Map<String, dynamic> priority) {
    // TODO: Implement edit priority dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit Priority: ${priority['name']} - Coming Soon')),
    );
  }

  void _deletePriority(int id) {
    // TODO: Implement delete priority
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete Priority functionality - Coming Soon')),
    );
  }

  void _showAddStatusDialog() {
    // TODO: Implement add status dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Status functionality - Coming Soon')),
    );
  }

  void _editStatus(Map<String, dynamic> status) {
    // TODO: Implement edit status dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit Status: ${status['name']} - Coming Soon')),
    );
  }

  void _deleteStatus(int id) {
    // TODO: Implement delete status
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete Status functionality - Coming Soon')),
    );
  }

  void _showAddCategoryDialog() {
    // TODO: Implement add category dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add Category functionality - Coming Soon')),
    );
  }

  void _editCategory(Map<String, dynamic> category) {
    // TODO: Implement edit category dialog
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edit Category: ${category['name']} - Coming Soon')),
    );
  }

  void _deleteCategory(int id) {
    // TODO: Implement delete category
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Delete Category functionality - Coming Soon')),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
