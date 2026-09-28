import '../models/schema_graph.dart';
import '../models/table_node.dart';

/// Orders database tables in topological dependency order (parents before children)
/// to ensure foreign key constraint satisfaction when seeding data.
class TopologicalSorter {
  /// Sorts [graph.tables] so that tables without dependencies come first,
  /// followed by dependent child tables.
  static List<TableNode> sortTables(SchemaGraph graph) {
    final tables = graph.tables;
    if (tables.isEmpty) return [];

    final tableMap = {for (final t in tables) t.tableName: t};

    // Calculate in-degree (number of parent tables this table depends on)
    // and adjacency list: parentTable -> List<childTable>
    final inDegree = <String, int>{for (final t in tables) t.tableName: 0};
    final dependents = <String, Set<String>>{for (final t in tables) t.tableName: {}};

    for (final table in tables) {
      for (final field in table.fields) {
        final target = field.relationTargetTable;
        if (target != null && target != table.tableName && tableMap.containsKey(target)) {
          // table depends on target: target is parent, table is child
          dependents[target]!.add(table.tableName);
          inDegree[table.tableName] = (inDegree[table.tableName] ?? 0) + 1;
        }
      }
    }

    // Queue of tables with 0 dependencies
    final queue = <String>[];
    for (final entry in inDegree.entries) {
      if (entry.value == 0) {
        queue.add(entry.key);
      }
    }

    final sorted = <TableNode>[];
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final current = queue.removeAt(0);
      visited.add(current);
      if (tableMap.containsKey(current)) {
        sorted.add(tableMap[current]!);
      }

      for (final child in dependents[current]!) {
        inDegree[child] = (inDegree[child] ?? 1) - 1;
        if (inDegree[child] == 0) {
          queue.add(child);
        }
      }
    }

    // Handle any circular dependencies or disconnected cycles
    for (final table in tables) {
      if (!visited.contains(table.tableName)) {
        sorted.add(table);
      }
    }

    return sorted;
  }
}
