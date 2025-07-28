import 'package:flutter/material.dart';
import '../models/project.dart';
import '../services/api_service.dart';

class TimelineView extends StatefulWidget {
  final Project project;

  const TimelineView({
    Key? key,
    required this.project,
  }) : super(key: key);

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  Map<String, dynamic>? _timelineData;
  bool _isLoading = true;
  String? _error;
  bool _showBaseline = false;
  bool _showDependencies = false;

  @override
  void initState() {
    super.initState();
    _loadTimeline();
  }

  Future<void> _loadTimeline() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final timeline = await ApiService.getProjectTimeline(
        widget.project.id,
        includeBaseline: _showBaseline,
        includeDependencies: _showDependencies,
      );
      
      setState(() {
        _timelineData = timeline;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load timeline: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.timeline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Project Timeline',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                _buildViewOptions(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadTimeline,
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[200]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[600]),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: Colors.red[600]))),
                  ],
                ),
              ),

            // Content
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_timelineData == null)
              const Expanded(child: Center(child: Text('No timeline data available')))
            else
              Expanded(child: _buildTimelineChart()),
          ],
        ),
      ),
    );
  }

  Widget _buildViewOptions() {
    return Row(
      children: [
        FilterChip(
          label: const Text('Baseline'),
          selected: _showBaseline,
          onSelected: (selected) {
            setState(() {
              _showBaseline = selected;
            });
            _loadTimeline();
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Dependencies'),
          selected: _showDependencies,
          onSelected: (selected) {
            setState(() {
              _showDependencies = selected;
            });
            _loadTimeline();
          },
        ),
      ],
    );
  }

  Widget _buildTimelineChart() {
    final modules = _timelineData!['modules'] as List<dynamic>;
    final statistics = _timelineData!['statistics'] as Map<String, dynamic>;

    return Column(
      children: [
        // Statistics Summary
        _buildStatisticsSummary(statistics),
        const SizedBox(height: 16),
        
        // Timeline Chart
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Time scale header
                _buildTimeScaleHeader(),
                
                // Project timeline
                _buildProjectTimeline(),
                
                // Module timelines
                ...modules.map((module) => _buildModuleTimeline(module)).toList(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticsSummary(Map<String, dynamic> statistics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              'Total Tasks',
              '${statistics['totalTasks'] ?? 0}',
              Icons.task,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Completion',
              '${statistics['completionPercentage'] ?? 0}%',
              Icons.check_circle,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Estimated Hours',
              '${statistics['totalEstimatedHours']?.toStringAsFixed(1) ?? '0.0'}h',
              Icons.schedule,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Actual Hours',
              '${statistics['totalActualHours']?.toStringAsFixed(1) ?? '0.0'}h',
              Icons.timer,
            ),
          ),
          Expanded(
            child: _buildStatItem(
              'Efficiency',
              '${(statistics['efficiencyRatio']?.toStringAsFixed(2) ?? '0.00')}x',
              Icons.trending_up,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeScaleHeader() {
    // Simplified time scale - in a real implementation, this would be more sophisticated
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));
    final endDate = now.add(const Duration(days: 60));
    
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: List.generate(12, (index) {
          final date = startDate.add(Duration(days: index * 7));
          return Expanded(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Text(
                '${date.month}/${date.day}',
                style: const TextStyle(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildProjectTimeline() {
    final project = _timelineData!['project'];
    final timeline = project['timeline'];
    
    return Container(
      height: 50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Project name
          SizedBox(
            width: 200,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                border: Border(
                  right: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Project',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Timeline bar
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: _buildTimelineBar(
                startDate: timeline?['startDate'] != null 
                    ? DateTime.parse(timeline['startDate']) 
                    : null,
                endDate: timeline?['endDate'] != null 
                    ? DateTime.parse(timeline['endDate']) 
                    : null,
                completionPercentage: timeline?['completionPercentage'] ?? 0,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleTimeline(Map<String, dynamic> module) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // Module name
          SizedBox(
            width: 200,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                border: Border(
                  right: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module['name'],
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${module['tasks']?.length ?? 0} tasks',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Timeline bar
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: _buildTimelineBar(
                startDate: module['calculatedStartDate'] != null 
                    ? DateTime.parse(module['calculatedStartDate']) 
                    : null,
                endDate: module['calculatedEndDate'] != null 
                    ? DateTime.parse(module['calculatedEndDate']) 
                    : null,
                completionPercentage: module['completionPercentage'] ?? 0,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineBar({
    DateTime? startDate,
    DateTime? endDate,
    required int completionPercentage,
    required Color color,
  }) {
    if (startDate == null || endDate == null) {
      return Container(
        height: 20,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(
          child: Text(
            'No dates set',
            style: TextStyle(fontSize: 10),
          ),
        ),
      );
    }

    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: color.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Stack(
        children: [
          // Progress bar
          FractionallySizedBox(
            widthFactor: completionPercentage / 100,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          
          // Percentage text
          Center(
            child: Text(
              '$completionPercentage%',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
