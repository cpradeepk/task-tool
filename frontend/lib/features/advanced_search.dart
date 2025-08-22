import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../main_layout.dart';

const String apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://task.amtariksha.com');

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  List<dynamic> _recentSearches = [];
  List<dynamic> _savedSearches = [];
  bool _isLoading = false;
  String _selectedCategory = 'All';
  String _selectedProject = 'All';
  String _selectedStatus = 'All';
  String _selectedPriority = 'All';
  String _selectedAssignee = 'All';
  DateTime? _startDate;
  DateTime? _endDate;
  List<String> _selectedTags = [];

  final List<String> _categories = ['All', 'Tasks', 'Projects', 'Modules', 'Notes', 'Users'];
  final List<String> _statuses = ['All', 'Open', 'In Progress', 'Completed', 'Hold', 'Cancelled'];
  final List<String> _priorities = ['All', 'High', 'Medium', 'Low'];
  List<String> _assignees = ['All', 'Me']; // Will be populated from API
  final List<String> _availableTags = ['urgent', 'frontend', 'backend', 'bug-fix', 'enhancement'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecentSearches();
    _loadSavedSearches();
  }

  Future<String?> _getJwt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt');
  }

  Future<void> _performSearch() async {
    if (_searchController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final jwt = await _getJwt();
      if (jwt != null) {
        final queryParams = {
          'q': _searchController.text.trim(),
          'category': _selectedCategory,
          'project': _selectedProject,
          'status': _selectedStatus,
          'priority': _selectedPriority,
          'assignee': _selectedAssignee,
          if (_startDate != null) 'start_date': _startDate!.toIso8601String().substring(0, 10),
          if (_endDate != null) 'end_date': _endDate!.toIso8601String().substring(0, 10),
          if (_selectedTags.isNotEmpty) 'tags': _selectedTags.join(','),
        };

        final uri = Uri.parse('$apiBase/task/api/search').replace(queryParameters: queryParams);
        final response = await http.get(
          uri,
          headers: {'Authorization': 'Bearer $jwt'},
        );

        if (response.statusCode == 200) {
          setState(() => _searchResults = jsonDecode(response.body));
        }
      }
    } catch (e) {
      // Show error message instead of mock data
      print('Search error: $e');
      setState(() => _searchResults = []);
    } finally {
      setState(() => _isLoading = false);
      _saveRecentSearch();
    }
  }



  void _saveRecentSearch() {
    final searchQuery = {
      'query': _searchController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
      'filters': {
        'category': _selectedCategory,
        'project': _selectedProject,
        'status': _selectedStatus,
        'priority': _selectedPriority,
        'tags': _selectedTags,
      }
    };

    setState(() {
      _recentSearches.removeWhere((search) => search['query'] == searchQuery['query']);
      _recentSearches.insert(0, searchQuery);
      if (_recentSearches.length > 10) {
        _recentSearches = _recentSearches.take(10).toList();
      }
    });
  }

  void _loadRecentSearches() {
    // Load recent searches from local storage or API
    setState(() {
      _recentSearches = [];
    });
  }

  void _loadSavedSearches() {
    // Load saved searches from local storage or API
    setState(() {
      _savedSearches = [];
    });
  }

  void _applySavedSearch(Map<String, dynamic> savedSearch) {
    setState(() {
      _searchController.text = savedSearch['query'] ?? '';
      final filters = savedSearch['filters'] as Map<String, dynamic>;
      _selectedCategory = filters['category'] ?? 'All';
      _selectedProject = filters['project'] ?? 'All';
      _selectedStatus = filters['status'] ?? 'All';
      _selectedPriority = filters['priority'] ?? 'All';
      _selectedAssignee = filters['assignee'] ?? 'All';
      _selectedTags = List<String>.from(filters['tags'] ?? []);
    });
    _performSearch();
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'All';
      _selectedProject = 'All';
      _selectedStatus = 'All';
      _selectedPriority = 'All';
      _selectedAssignee = 'All';
      _selectedTags.clear();
      _startDate = null;
      _endDate = null;
    });
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'task': return Icons.task;
      case 'project': return Icons.folder;
      case 'module': return Icons.extension;
      case 'note': return Icons.note;
      case 'user': return Icons.person;
      default: return Icons.search;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'task': return Colors.blue;
      case 'project': return Colors.green;
      case 'module': return Colors.orange;
      case 'note': return Colors.purple;
      case 'user': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Advanced Search',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Search Header
            Row(
              children: [
                const Icon(Icons.search, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Advanced Search',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Filters'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search tasks, projects, notes, and more...',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults.clear());
                              },
                              icon: const Icon(Icons.clear),
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _performSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tabs
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Results'),
                Tab(text: 'Recent'),
                Tab(text: 'Saved'),
              ],
            ),
            const SizedBox(height: 16),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildResultsTab(),
                  _buildRecentTab(),
                  _buildSavedTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsTab() {
    return Column(
      children: [
        // Advanced Filters
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filters',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              
              // First row of filters
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      value: _selectedCategory,
                      items: _categories.map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category, style: const TextStyle(fontSize: 12)),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedCategory = value!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      value: _selectedStatus,
                      items: _statuses.map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status, style: const TextStyle(fontSize: 12)),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedStatus = value!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      value: _selectedPriority,
                      items: _priorities.map((priority) => DropdownMenuItem(
                        value: priority,
                        child: Text(priority, style: const TextStyle(fontSize: 12)),
                      )).toList(),
                      onChanged: (value) => setState(() => _selectedPriority = value!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Tags filter
              const Text('Tags:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: _availableTags.map<Widget>((tag) {
                  final isSelected = _selectedTags.contains(tag);
                  return FilterChip(
                    label: Text(tag, style: const TextStyle(fontSize: 10)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTags.add(tag);
                        } else {
                          _selectedTags.remove(tag);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Search Results
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No results found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                          Text('Try adjusting your search terms or filters', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _getTypeColor(result['type']).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                _getTypeIcon(result['type']),
                                color: _getTypeColor(result['type']),
                              ),
                            ),
                            title: Text(
                              result['title'],
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(result['description']),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Chip(
                                      label: Text(
                                        result['type'],
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                      backgroundColor: _getTypeColor(result['type']).withValues(alpha: 0.2),
                                    ),
                                    if (result['status'] != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        result['status'],
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              // Navigate to the result
                              // context.go(result['url']);
                            },
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildRecentTab() {
    return _recentSearches.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No recent searches', style: TextStyle(fontSize: 18, color: Colors.grey)),
                Text('Your recent searches will appear here', style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        : ListView.builder(
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final search = _recentSearches[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(search['query']),
                subtitle: Text(
                  'Searched ${_formatSearchTime(search['timestamp'])}',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                trailing: IconButton(
                  onPressed: () {
                    setState(() {
                      _searchController.text = search['query'];
                      // Apply filters from recent search
                    });
                    _performSearch();
                  },
                  icon: const Icon(Icons.replay),
                ),
                onTap: () {
                  setState(() => _searchController.text = search['query']);
                  _performSearch();
                },
              );
            },
          );
  }

  Widget _buildSavedTab() {
    return Column(
      children: [
        // Save current search button
        if (_searchController.text.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => _showSaveSearchDialog(),
              icon: const Icon(Icons.bookmark_add),
              label: const Text('Save Current Search'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),

        // Saved searches list
        Expanded(
          child: _savedSearches.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No saved searches', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      Text('Save frequently used searches for quick access', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _savedSearches.length,
                  itemBuilder: (context, index) {
                    final search = _savedSearches[index];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.bookmark, color: Colors.blue),
                        title: Text(search['name']),
                        subtitle: Text(
                          search['query'].isNotEmpty ? search['query'] : 'Filter-based search',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'apply') {
                              _applySavedSearch(search);
                            } else if (action == 'delete') {
                              setState(() => _savedSearches.removeAt(index));
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'apply',
                              child: Row(
                                children: [
                                  Icon(Icons.play_arrow, size: 16),
                                  SizedBox(width: 8),
                                  Text('Apply'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () => _applySavedSearch(search),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showSaveSearchDialog() {
    final nameController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save Search'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Search Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                final savedSearch = {
                  'id': _savedSearches.length + 1,
                  'name': nameController.text.trim(),
                  'query': _searchController.text,
                  'filters': {
                    'category': _selectedCategory,
                    'project': _selectedProject,
                    'status': _selectedStatus,
                    'priority': _selectedPriority,
                    'assignee': _selectedAssignee,
                    'tags': _selectedTags,
                  },
                  'created_at': DateTime.now().toIso8601String().substring(0, 10),
                };
                
                setState(() => _savedSearches.add(savedSearch));
                Navigator.of(context).pop();
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Search saved successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  String _formatSearchTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
