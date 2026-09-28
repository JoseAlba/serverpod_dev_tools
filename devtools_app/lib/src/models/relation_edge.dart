/// Represents a directional relationship edge connecting two tables in an ER diagram.
class RelationEdge {
  /// Unique identifier for this relationship edge.
  final String id;

  /// Name of the source table containing the foreign key (or relation field).
  final String fromTable;

  /// Field on the source table acting as the foreign reference (e.g. `courseUuid`, `author`).
  final String fromField;

  /// Name of the referenced target table.
  final String toTable;

  /// Referenced target field (usually `id` or `uuid`).
  final String toField;

  /// Cardinality relationship (`1:1` or `1:N`).
  final String cardinality;

  /// Optional named relation identifier from `relation(name=...)`.
  final String? relationName;

  /// True if explicitly declared via `relation(...)`, false if inferred from naming conventions.
  final bool isExplicit;

  const RelationEdge({
    required this.id,
    required this.fromTable,
    required this.fromField,
    required this.toTable,
    required this.toField,
    this.cardinality = '1:N',
    this.relationName,
    this.isExplicit = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'fromTable': fromTable,
    'fromField': fromField,
    'toTable': toTable,
    'toField': toField,
    'cardinality': cardinality,
    if (relationName != null) 'relationName': relationName,
    'isExplicit': isExplicit,
  };

  factory RelationEdge.fromJson(Map<String, dynamic> json) => RelationEdge(
    id: json['id'] as String,
    fromTable: json['fromTable'] as String,
    fromField: json['fromField'] as String,
    toTable: json['toTable'] as String,
    toField: json['toField'] as String,
    cardinality: json['cardinality'] as String? ?? '1:N',
    relationName: json['relationName'] as String?,
    isExplicit: json['isExplicit'] as bool? ?? true,
  );
}
