List<int> longestPath(List<Map<String, dynamic>> tasks, List<Map<String, dynamic>> deps) {
  final g = <int, List<int>>{ for (final t in tasks) t['id'] as int : [] };
  final w = <int, double>{ for (final t in tasks) t['id'] as int : ((t['expected_time'] as num?)?.toDouble() ?? 1.0) };
  final indeg = <int, int>{ for (final t in tasks) t['id'] as int : 0 };
  for (final d in deps) {
    final u = d['depends_on_task_id'] as int; final v = d['task_id'] as int;
    g[u]!.add(v);
    indeg[v] = (indeg[v] ?? 0) + 1;
  }
  final q = <int>[...tasks.where((t)=>indeg[t['id'] as int]==0).map((t)=>t['id'] as int)];
  final order = <int>[];
  while (q.isNotEmpty) {
    final u = q.removeAt(0); order.add(u);
    for (final v in g[u]!) { indeg[v] = (indeg[v] ?? 0) - 1; if (indeg[v]==0) q.add(v); }
  }
  final dist = <int,double>{ for (final t in tasks) t['id'] as int : double.negativeInfinity };
  final parent = <int,int?>{ for (final t in tasks) t['id'] as int : null };
  for (final u in order) {
    if ((indeg[u] ?? 0) == 0) dist[u] = w[u] ?? 1.0;
    for (final v in g[u]!) {
      final base = dist[u] ?? double.negativeInfinity;
      final cand = (base.isFinite ? base : 0.0) + (w[v] ?? 1.0);
      final dv = dist[v] ?? double.negativeInfinity;
      if (!dv.isFinite || cand > dv) { dist[v] = cand; parent[v] = u; }
    }
  }
  var best = order.isNotEmpty ? order.last : (tasks.isNotEmpty ? tasks.last['id'] as int : -1);
  var bestVal = dist[best] ?? double.negativeInfinity;
  for (final t in tasks) { final id = t['id'] as int; final dv = dist[id] ?? double.negativeInfinity; if (dv.isFinite && dv > bestVal) { best = id; bestVal = dv; } }
  final path = <int>[]; int? cur = best; final seen = <int>{};
  while (cur != null && !seen.contains(cur)) { path.add(cur); seen.add(cur); cur = parent[cur]; }
  return path.reversed.toList();
}

