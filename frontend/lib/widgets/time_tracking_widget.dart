import 'package:flutter/material.dart';
import 'dart:async';
import '../models/task.dart';
import '../services/api_service.dart';

class TimeEntry {
  final String id;
  final String description;
  final DateTime startTime;
  final DateTime? endTime;
  final double? hours;
  final DateTime date;
  final Map<String, dynamic> user;

  TimeEntry({
    required this.id,
    required this.description,
    required this.startTime,
    this.endTime,
    this.hours,
    required this.date,
    required this.user,
  });

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'],
      description: json['description'],
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      hours: json['hours']?.toDouble(),
      date: DateTime.parse(json['date']),
      user: json['user'],
    );
  }
}

class ActiveTimer {
  final String id;
  final String taskId;
  final String description;
  final DateTime startTime;
  final double elapsedHours;
  final Map<String, dynamic> task;

  ActiveTimer({
    required this.id,
    required this.taskId,
    required this.description,
    required this.startTime,
    required this.elapsedHours,
    required this.task,
  });

  factory ActiveTimer.fromJson(Map<String, dynamic> json) {
    return ActiveTimer(
      id: json['id'],
      taskId: json['taskId'],
      description: json['description'],
      startTime: DateTime.parse(json['startTime']),
      elapsedHours: json['elapsedHours'].toDouble(),
      task: json['task'],
    );
  }
}

class TimeTrackingWidget extends StatefulWidget {
  final String taskId;
  final Task task;

  const TimeTrackingWidget({
    Key? key,
    required this.taskId,
    required this.task,
  }) : super(key: key);

  @override
  State<TimeTrackingWidget> createState() => _TimeTrackingWidgetState();
}

class _TimeTrackingWidgetState extends State<TimeTrackingWidget> {
  List<TimeEntry> _timeEntries = [];
  ActiveTimer? _activeTimer;
  bool _isLoading = true;
  String? _error;
  Timer? _timer;
  Duration _currentElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadTimeEntries();
    _loadActiveTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadTimeEntries() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await ApiService.get('/tasks/${widget.taskId}/time-entries');
      final timeEntries = (response as List<dynamic>)
          .map((data) => TimeEntry.fromJson(data))
          .toList();

      setState(() {
        _timeEntries = timeEntries;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadActiveTimer() async {
    try {
      final response = await ApiService.get('/tasks/timer/active');
      
      if (response != null) {
        final activeTimer = ActiveTimer.fromJson(response);
        
        // Only show timer if it's for this task
        if (activeTimer.taskId == widget.taskId) {
          setState(() {
            _activeTimer = activeTimer;
            _currentElapsed = Duration(
              milliseconds: (activeTimer.elapsedHours * 3600 * 1000).round(),
            );
          });
          _startTimer();
        }
      }
    } catch (e) {
      // No active timer or error - that's okay
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeTimer != null) {
        setState(() {
          _currentElapsed = DateTime.now().difference(_activeTimer!.startTime);
        });
      }
    });
  }

  Future<void> _startTimeTracking() async {
    try {
      final description = await _showDescriptionDialog('Start Timer', 'Working on ${widget.task.title}');
      if (description == null) return;

      final response = await ApiService.post('/tasks/timer/start', {
        'taskId': widget.taskId,
        'description': description,
      });

      final activeTimer = ActiveTimer.fromJson(response);
      setState(() {
        _activeTimer = activeTimer;
        _currentElapsed = Duration.zero;
      });
      
      _startTimer();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timer started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting timer: $e')),
        );
      }
    }
  }

  Future<void> _stopTimeTracking() async {
    try {
      await ApiService.post('/tasks/timer/stop', {});
      
      setState(() {
        _activeTimer = null;
        _currentElapsed = Duration.zero;
      });
      
      _timer?.cancel();
      await _loadTimeEntries(); // Refresh time entries
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timer stopped')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping timer: $e')),
        );
      }
    }
  }

  Future<String?> _showDescriptionDialog(String title, String initialValue) async {
    final controller = TextEditingController(text: initialValue);
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTimerSection(),
        const SizedBox(height: 16),
        _buildTimeEntriesSection(),
      ],
    );
  }

  Widget _buildTimerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Time Tracking',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_activeTimer != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_activeTimer != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatDuration(_currentElapsed),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _activeTimer!.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _stopTimeTracking,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Timer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: ElevatedButton.icon(
                  onPressed: _startTimeTracking,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Start Timer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildTimeStats(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeStats() {
    final totalHours = _timeEntries.fold<double>(
      0,
      (sum, entry) => sum + (entry.hours ?? 0),
    );
    
    final estimatedHours = widget.task.estimatedHours ?? 0;
    final progress = estimatedHours > 0 ? (totalHours / estimatedHours) : 0.0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Logged',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  '${totalHours.toStringAsFixed(1)}h',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (estimatedHours > 0) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Estimated',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    '${estimatedHours.toStringAsFixed(1)}h',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        if (estimatedHours > 0) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress > 1.0 ? Colors.red : Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toStringAsFixed(1)}% of estimated time',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimeEntriesSection() {
    return Expanded(
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Time Entries',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${_timeEntries.length} entries',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildTimeEntriesList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeEntriesList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading time entries'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadTimeEntries,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_timeEntries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.schedule, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No time entries yet'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _timeEntries.length,
      itemBuilder: (context, index) {
        final entry = _timeEntries[index];
        return _buildTimeEntryCard(entry);
      },
    );
  }

  Widget _buildTimeEntryCard(TimeEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            entry.user['name']?.substring(0, 1).toUpperCase() ?? 'U',
            style: TextStyle(color: Colors.blue[700]),
          ),
        ),
        title: Text(entry.description),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.user['name']} • ${_formatDate(entry.date)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            Text(
              '${_formatTime(entry.startTime)} - ${entry.endTime != null ? _formatTime(entry.endTime!) : 'Running'}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        trailing: entry.hours != null
            ? Text(
                '${entry.hours!.toStringAsFixed(1)}h',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : const Icon(Icons.timer, color: Colors.green),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
