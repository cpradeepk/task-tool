import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../widgets/project_card.dart';
import '../widgets/project_form_dialog.dart';
import '../widgets/responsive_layout.dart';
import '../widgets/loading_widget.dart';
import '../widgets/error_widget.dart';

class ProjectManagementScreen extends StatefulWidget {
  const ProjectManagementScreen({Key? key}) : super(key: key);

  @override
  State<ProjectManagementScreen> createState() => _ProjectManagementScreenState();
}

class _ProjectManagementScreenState extends State<ProjectManagementScreen> {
  List<Project> _projects = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'ALL';
  String _priorityFilter = 'ALL';
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final projectsData = await ApiService.getProjects();
      final projects = projectsData.map((data) => Project.fromJson(data)).toList();

      setState(() {
        _projects = projects;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Project> get _filteredProjects {
    var filtered = _projects.where((project) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!project.name.toLowerCase().contains(query) &&
            !(project.description?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }

      // Status filter
      if (_statusFilter != 'ALL' && project.status.value != _statusFilter) {
        return false;
      }

      // Priority filter
      if (_priorityFilter != 'ALL' && project.priority.value != _priorityFilter) {
        return false;
      }

      return true;
    }).toList();

    // Sort
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'status':
          comparison = a.status.value.compareTo(b.status.value);
          break;
        case 'priority':
          comparison = a.priority.value.compareTo(b.priority.value);
          break;
        case 'createdAt':
        default:
          comparison = a.createdAt.compareTo(b.createdAt);
          break;
      }
      return _sortOrder == 'desc' ? -comparison : comparison;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final isAdmin = user?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Management'),
        backgroundColor: const Color(0xFF2196F3), // Light blue primary
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProjects,
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateProjectDialog(context),
            ),
        ],
      ),
      body: ResponsiveLayout(
        mobile: _buildMobileLayout(),
        tablet: _buildTabletLayout(),
        desktop: _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildSearchAndFilters(),
        Expanded(
          child: _buildProjectsList(),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      children: [
        SizedBox(
          width: 300,
          child: Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFiltersPanel(),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildSearchBar(),
              Expanded(child: _buildProjectsGrid()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        SizedBox(
          width: 350,
          child: Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _buildFiltersPanel(),
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              _buildSearchBar(),
              _buildSortingOptions(),
              Expanded(child: _buildProjectsGrid()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildQuickFilters(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search projects...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildQuickFilters() {
    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          label: const Text('Active'),
          selected: _statusFilter == 'ACTIVE',
          onSelected: (selected) {
            setState(() {
              _statusFilter = selected ? 'ACTIVE' : 'ALL';
            });
          },
        ),
        FilterChip(
          label: const Text('Completed'),
          selected: _statusFilter == 'COMPLETED',
          onSelected: (selected) {
            setState(() {
              _statusFilter = selected ? 'COMPLETED' : 'ALL';
            });
          },
        ),
        FilterChip(
          label: const Text('High Priority'),
          selected: _priorityFilter == 'IMPORTANT_URGENT',
          onSelected: (selected) {
            setState(() {
              _priorityFilter = selected ? 'IMPORTANT_URGENT' : 'ALL';
            });
          },
        ),
      ],
    );
  }

  Widget _buildFiltersPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filters',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _buildStatusFilter(),
        const SizedBox(height: 16),
        _buildPriorityFilter(),
        const SizedBox(height: 16),
        _buildSortingOptions(),
      ],
    );
  }

  Widget _buildStatusFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Status', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _statusFilter,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
            DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
            DropdownMenuItem(value: 'ON_HOLD', child: Text('On Hold')),
            DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
            DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
          ],
          onChanged: (value) {
            setState(() {
              _statusFilter = value ?? 'ALL';
            });
          },
        ),
      ],
    );
  }

  Widget _buildPriorityFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Priority', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _priorityFilter,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('All Priorities')),
            DropdownMenuItem(value: 'IMPORTANT_URGENT', child: Text('Important & Urgent')),
            DropdownMenuItem(value: 'IMPORTANT_NOT_URGENT', child: Text('Important & Not Urgent')),
            DropdownMenuItem(value: 'NOT_IMPORTANT_URGENT', child: Text('Not Important & Urgent')),
            DropdownMenuItem(value: 'NOT_IMPORTANT_NOT_URGENT', child: Text('Not Important & Not Urgent')),
          ],
          onChanged: (value) {
            setState(() {
              _priorityFilter = value ?? 'ALL';
            });
          },
        ),
      ],
    );
  }

  Widget _buildSortingOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Sort By', style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _sortBy,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'createdAt', child: Text('Created Date')),
                  DropdownMenuItem(value: 'name', child: Text('Name')),
                  DropdownMenuItem(value: 'status', child: Text('Status')),
                  DropdownMenuItem(value: 'priority', child: Text('Priority')),
                ],
                onChanged: (value) {
                  setState(() {
                    _sortBy = value ?? 'createdAt';
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(_sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward),
              onPressed: () {
                setState(() {
                  _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                });
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProjectsList() {
    if (_isLoading) {
      return const LoadingWidget();
    }

    if (_error != null) {
      return ErrorDisplayWidget(
        error: _error!,
        onRetry: _loadProjects,
      );
    }

    final filteredProjects = _filteredProjects;

    if (filteredProjects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No projects found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: filteredProjects.length,
      itemBuilder: (context, index) {
        return ProjectCard(
          project: filteredProjects[index],
          onTap: () => _navigateToProjectDetails(filteredProjects[index]),
          onEdit: () => _showEditProjectDialog(context, filteredProjects[index]),
          onDelete: () => _showDeleteProjectDialog(context, filteredProjects[index]),
        );
      },
    );
  }

  Widget _buildProjectsGrid() {
    if (_isLoading) {
      return const LoadingWidget();
    }

    if (_error != null) {
      return ErrorDisplayWidget(
        error: _error!,
        onRetry: _loadProjects,
      );
    }

    final filteredProjects = _filteredProjects;

    if (filteredProjects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No projects found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: filteredProjects.length,
      itemBuilder: (context, index) {
        return ProjectCard(
          project: filteredProjects[index],
          onTap: () => _navigateToProjectDetails(filteredProjects[index]),
          onEdit: () => _showEditProjectDialog(context, filteredProjects[index]),
          onDelete: () => _showDeleteProjectDialog(context, filteredProjects[index]),
        );
      },
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => ProjectFormDialog(
        onSave: (projectData) async {
          try {
            await ApiService.createProject(projectData);
            await _loadProjects();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Project created successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error creating project: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditProjectDialog(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (context) => ProjectFormDialog(
        project: project,
        onSave: (projectData) async {
          try {
            await ApiService.updateProject(project.id, projectData);
            await _loadProjects();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Project updated successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating project: $e')),
              );
            }
          }
        },
      ),
    );
  }

  void _showDeleteProjectDialog(BuildContext context, Project project) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text('Are you sure you want to delete "${project.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await ApiService.deleteProject(project.id);
                await _loadProjects();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Project deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting project: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToProjectDetails(Project project) {
    Navigator.pushNamed(
      context,
      '/project-details',
      arguments: project,
    );
  }
}
