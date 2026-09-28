import 'relation_edge.dart';
import 'table_node.dart';

/// Represents the complete parsed ER diagram graph containing all tables and relation edges.
class SchemaGraph {
  /// All table entities discovered in the schema.
  final List<TableNode> tables;

  /// All relationship edges interconnecting the tables.
  final List<RelationEdge> relations;

  /// Global metadata (e.g. project name, scan timestamp, totals).
  final Map<String, dynamic> metadata;

  const SchemaGraph({
    required this.tables,
    this.relations = const [],
    this.metadata = const {},
  });

  SchemaGraph copyWith({
    List<TableNode>? tables,
    List<RelationEdge>? relations,
    Map<String, dynamic>? metadata,
  }) => SchemaGraph(
    tables: tables ?? this.tables,
    relations: relations ?? this.relations,
    metadata: metadata ?? this.metadata,
  );

  /// Quick lookup map of table by table name.
  Map<String, TableNode> get tableByName => {
    for (final table in tables) table.tableName: table,
  };

  /// Quick lookup map of table by Dart class name.
  Map<String, TableNode> get tableByClassName => {
    for (final table in tables) table.className: table,
  };

  Map<String, dynamic> toJson() => {
    'tables': tables.map((t) => t.toJson()).toList(),
    'relations': relations.map((r) => r.toJson()).toList(),
    'metadata': metadata,
  };

  factory SchemaGraph.fromJson(Map<String, dynamic> json) => SchemaGraph(
    tables: (json['tables'] as List<dynamic>?)
            ?.map((t) => TableNode.fromJson(t as Map<String, dynamic>))
            .toList() ??
        const [],
    relations: (json['relations'] as List<dynamic>?)
            ?.map((r) => RelationEdge.fromJson(r as Map<String, dynamic>))
            .toList() ??
        const [],
    metadata: json['metadata'] as Map<String, dynamic>? ?? const {},
  );
}
