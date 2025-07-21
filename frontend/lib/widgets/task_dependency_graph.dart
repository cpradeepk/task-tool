import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/task.dart';
import '../services/api_service.dart';

class TaskDependencyNode {
  final String id;
  final String title;
  final TaskStatus status;
  final bool isCritical;
  final double slack;
  Offset position;
  
  TaskDependencyNode({
    required this.id,
    required this.title,
    required this.status,
    required this.isCritical,
    required this.slack,
    required this.position,
  });
}

class TaskDependencyEdge {
  final String id;
  final String sourceId;
  final String targetId;
  final String type;
  final bool isCritical;
  
  TaskDependencyEdge({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.type,
    required this.isCritical,
  });
}

class TaskDependencyGraph extends StatefulWidget {
  final String projectId;
  final Function(String)? onTaskTap;

  const TaskDependencyGraph({
    Key? key,
    required this.projectId,
    this.onTaskTap,
  }) : super(key: key);

  @override
  State<TaskDependencyGraph> createState() => _TaskDependencyGraphState();
}

class _TaskDependencyGraphState extends State<TaskDependencyGraph> {
  List<TaskDependencyNode> _nodes = [];
  List<TaskDependencyEdge> _edges = [];
  List<Map<String, dynamic>> _criticalPath = [];
  bool _isLoading = true;
  String? _error;
  double _scale = 1.0;
  Offset _offset = Offset.zero;
  bool _showCriticalPathOnly = false;

  @override
  void initState() {
    super.initState();
    _loadDependencyGraph();
  }

  Future<void> _loadDependencyGraph() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await ApiService.get('/tasks/projects/${widget.projectId}/dependency-graph');
      
      final nodes = (response['nodes'] as List<dynamic>).map((nodeData) {
        return TaskDependencyNode(
          id: nodeData['id'],
          title: nodeData['title'],
          status: TaskStatus.fromString(nodeData['status']),
          isCritical: nodeData['isCritical'] ?? false,
          slack: (nodeData['slack'] ?? 0).toDouble(),
          position: Offset.zero, // Will be calculated
        );
      }).toList();

      final edges = (response['edges'] as List<dynamic>).map((edgeData) {
        return TaskDependencyEdge(
          id: edgeData['id'],
          sourceId: edgeData['source'],
          targetId: edgeData['target'],
          type: edgeData['type'],
          isCritical: edgeData['isCritical'] ?? false,
        );
      }).toList();

      final criticalPath = List<Map<String, dynamic>>.from(response['criticalPath'] ?? []);

      // Calculate node positions using force-directed layout
      _calculateNodePositions(nodes, edges);

      setState(() {
        _nodes = nodes;
        _edges = edges;
        _criticalPath = criticalPath;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _calculateNodePositions(List<TaskDependencyNode> nodes, List<TaskDependencyEdge> edges) {
    if (nodes.isEmpty) return;

    final random = math.Random();
    final center = const Offset(200, 200);
    final radius = 150.0;

    // Initialize positions randomly in a circle
    for (int i = 0; i < nodes.length; i++) {
      final angle = (i / nodes.length) * 2 * math.pi;
      nodes[i].position = Offset(
        center.dx + radius * math.cos(angle) + random.nextDouble() * 20 - 10,
        center.dy + radius * math.sin(angle) + random.nextDouble() * 20 - 10,
      );
    }

    // Simple force-directed layout simulation
    for (int iteration = 0; iteration < 100; iteration++) {
      final forces = <String, Offset>{};
      
      // Initialize forces
      for (final node in nodes) {
        forces[node.id] = Offset.zero;
      }

      // Repulsive forces between all nodes
      for (int i = 0; i < nodes.length; i++) {
        for (int j = i + 1; j < nodes.length; j++) {
          final node1 = nodes[i];
          final node2 = nodes[j];
          final distance = (node1.position - node2.position).distance;
          
          if (distance > 0) {
            final repulsiveForce = 1000 / (distance * distance);
            final direction = (node1.position - node2.position) / distance;
            
            forces[node1.id] = forces[node1.id]! + direction * repulsiveForce;
            forces[node2.id] = forces[node2.id]! - direction * repulsiveForce;
          }
        }
      }

      // Attractive forces for connected nodes
      for (final edge in edges) {
        final sourceNode = nodes.firstWhere((n) => n.id == edge.sourceId);
        final targetNode = nodes.firstWhere((n) => n.id == edge.targetId);
        
        final distance = (sourceNode.position - targetNode.position).distance;
        if (distance > 0) {
          final attractiveForce = distance * 0.01;
          final direction = (targetNode.position - sourceNode.position) / distance;
          
          forces[sourceNode.id] = forces[sourceNode.id]! + direction * attractiveForce;
          forces[targetNode.id] = forces[targetNode.id]! - direction * attractiveForce;
        }
      }

      // Apply forces with damping
      for (final node in nodes) {
        final force = forces[node.id]!;
        node.position += force * 0.1; // Damping factor
        
        // Keep nodes within bounds
        node.position = Offset(
          node.position.dx.clamp(50, 350),
          node.position.dy.clamp(50, 350),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _buildGraph(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Text(
            'Task Dependencies',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (_criticalPath.isNotEmpty) ...[
            FilterChip(
              label: const Text('Critical Path Only'),
              selected: _showCriticalPathOnly,
              onSelected: (selected) {
                setState(() {
                  _showCriticalPathOnly = selected;
                });
              },
            ),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDependencyGraph,
          ),
        ],
      ),
    );
  }

  Widget _buildGraph() {
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
            Text('Error loading dependency graph'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadDependencyGraph,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_nodes.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_tree, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No task dependencies found'),
          ],
        ),
      );
    }

    return GestureDetector(
      onPanUpdate: (details) {
        setState(() {
          _offset += details.delta / _scale;
        });
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = (_scale * details.scale).clamp(0.5, 3.0);
        });
      },
      child: CustomPaint(
        painter: DependencyGraphPainter(
          nodes: _showCriticalPathOnly 
              ? _nodes.where((n) => n.isCritical).toList()
              : _nodes,
          edges: _showCriticalPathOnly
              ? _edges.where((e) => e.isCritical).toList()
              : _edges,
          scale: _scale,
          offset: _offset,
          onNodeTap: widget.onTaskTap,
        ),
        child: Container(),
      ),
    );
  }
}

class DependencyGraphPainter extends CustomPainter {
  final List<TaskDependencyNode> nodes;
  final List<TaskDependencyEdge> edges;
  final double scale;
  final Offset offset;
  final Function(String)? onNodeTap;

  DependencyGraphPainter({
    required this.nodes,
    required this.edges,
    required this.scale,
    required this.offset,
    this.onNodeTap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(scale);
    canvas.translate(offset.dx, offset.dy);

    // Draw edges first
    for (final edge in edges) {
      _drawEdge(canvas, edge);
    }

    // Draw nodes on top
    for (final node in nodes) {
      _drawNode(canvas, node);
    }

    canvas.restore();
  }

  void _drawEdge(Canvas canvas, TaskDependencyEdge edge) {
    final sourceNode = nodes.firstWhere((n) => n.id == edge.sourceId);
    final targetNode = nodes.firstWhere((n) => n.id == edge.targetId);

    final paint = Paint()
      ..color = edge.isCritical ? Colors.red : Colors.grey[400]!
      ..strokeWidth = edge.isCritical ? 3.0 : 1.5
      ..style = PaintingStyle.stroke;

    // Draw arrow
    final direction = (targetNode.position - sourceNode.position);
    final distance = direction.distance;
    final normalizedDirection = direction / distance;
    
    final startPoint = sourceNode.position + normalizedDirection * 25;
    final endPoint = targetNode.position - normalizedDirection * 25;

    canvas.drawLine(startPoint, endPoint, paint);

    // Draw arrowhead
    final arrowSize = 8.0;
    final arrowAngle = math.pi / 6;
    
    final arrowPoint1 = endPoint + Offset(
      -arrowSize * math.cos(math.atan2(normalizedDirection.dy, normalizedDirection.dx) - arrowAngle),
      -arrowSize * math.sin(math.atan2(normalizedDirection.dy, normalizedDirection.dx) - arrowAngle),
    );
    
    final arrowPoint2 = endPoint + Offset(
      -arrowSize * math.cos(math.atan2(normalizedDirection.dy, normalizedDirection.dx) + arrowAngle),
      -arrowSize * math.sin(math.atan2(normalizedDirection.dy, normalizedDirection.dx) + arrowAngle),
    );

    final arrowPath = Path()
      ..moveTo(endPoint.dx, endPoint.dy)
      ..lineTo(arrowPoint1.dx, arrowPoint1.dy)
      ..lineTo(arrowPoint2.dx, arrowPoint2.dy)
      ..close();

    canvas.drawPath(arrowPath, paint..style = PaintingStyle.fill);
  }

  void _drawNode(Canvas canvas, TaskDependencyNode node) {
    final paint = Paint()
      ..color = node.isCritical ? Colors.red[100]! : Color(node.status.color).withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = node.isCritical ? Colors.red : Color(node.status.color)
      ..strokeWidth = node.isCritical ? 3.0 : 2.0
      ..style = PaintingStyle.stroke;

    // Draw node circle
    canvas.drawCircle(node.position, 25, paint);
    canvas.drawCircle(node.position, 25, borderPaint);

    // Draw node text
    final textPainter = TextPainter(
      text: TextSpan(
        text: node.title.length > 10 ? '${node.title.substring(0, 10)}...' : node.title,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 10,
          fontWeight: node.isCritical ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      node.position - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
