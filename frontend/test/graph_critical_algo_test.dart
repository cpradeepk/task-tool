import 'package:flutter_test/flutter_test.dart';
import 'package:task_tool_frontend/graph/critical_algo.dart';

void main() {
  test('longestPath simple chain', () {
    final tasks = [
      {'id': 1, 'expected_time': 1.0},
      {'id': 2, 'expected_time': 2.0},
      {'id': 3, 'expected_time': 3.0},
    ];
    final deps = [
      {'depends_on_task_id': 1, 'task_id': 2},
      {'depends_on_task_id': 2, 'task_id': 3},
    ];
    final path = longestPath(List<Map<String, dynamic>>.from(tasks), List<Map<String, dynamic>>.from(deps));
    expect(path, [1,2,3]);
  });

  test('longestPath chooses heavier branch', () {
    final tasks = [
      {'id': 1, 'expected_time': 1.0},
      {'id': 2, 'expected_time': 10.0},
      {'id': 3, 'expected_time': 2.0},
      {'id': 4, 'expected_time': 1.0},
    ];
    final deps = [
      {'depends_on_task_id': 1, 'task_id': 2},
      {'depends_on_task_id': 1, 'task_id': 3},
      {'depends_on_task_id': 3, 'task_id': 4},
    ];
    final path = longestPath(List<Map<String, dynamic>>.from(tasks), List<Map<String, dynamic>>.from(deps));
    expect(path, [1,2]);
  });
}

