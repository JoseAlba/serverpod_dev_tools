import 'field_node.dart';
import 'index_node.dart';

/// The architectural kind of Serverpod model entity.
enum EntityType {
  /// Stored as a physical PostgreSQL database table (`table: <tableName>`).
  table,

  /// Serializable DTO / Struct object without a database table (`class: <ClassName>`).
  object,

  /// Enumeration type (`enum: <EnumName>`).
  enumeration,

  /// Custom Serverpod exception (`exception: <ExceptionName>`).
  exception,
}

/// Represents an entity extracted from a Serverpod `.spy.yaml` model or `TableDefinition`.
class TableNode {
  /// Unique identifier for this node (typically matches [tableName] or [className]).
  final String id;

  /// Dart class name of the generated entity (e.g., `Course`, `StudentProfile`, `CefrLevel`).
  final String className;

  /// Underlying PostgreSQL table name if [isDatabaseTable] is true (e.g., `learnos_course`).
  /// If not a database table, this equals [className].
  final String tableName;

  /// Whether this model represents a physical database table in PostgreSQL.
  final bool isDatabaseTable;

  /// The structural type of entity (table, DTO object, enum, exception).
  final EntityType entityType;

  /// Logical group/domain module name (e.g., `courses`, `students`, `settings`).
  final String? module;

  /// Top-level documentation describing the entity's purpose.
  final String? description;

  /// Ordered list of columns/fields declared on this table or object.
  final List<FieldNode> fields;

  /// Defined indexes on this table (only relevant for database tables).
  final List<IndexNode> indexes;

  /// Known values for enumeration types (`enum:`).
  final List<String> enumValues;

  /// Approximate row count in the database (if queried/available).
  final int? rowCount;

  /// Visual X coordinate on the ER diagram canvas.
  final double positionX;

  /// Visual Y coordinate on the ER diagram canvas.
  final double positionY;

  /// Hex color code used for domain categorization and table header bar.
  final String? colorHex;

  const TableNode({
    required this.id,
    required this.className,
    required this.tableName,
    this.isDatabaseTable = true,
    this.entityType = EntityType.table,
    this.module,
    this.description,
    this.fields = const [],
    this.indexes = const [],
    this.enumValues = const [],
    this.rowCount,
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.colorHex,
  });

  /// Finds the primary key field for this table, preferring `id` or a field marked `isPrimaryKey`.
  FieldNode? get primaryKeyField {
    for (final field in fields) {
      if (field.isPrimaryKey || field.name == 'id') return field;
    }
    for (final field in fields) {
      if (field.name == 'uuid') return field;
    }
    return fields.isNotEmpty ? fields.first : null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'className': className,
    'tableName': tableName,
    'isDatabaseTable': isDatabaseTable,
    'entityType': entityType.name,
    if (module != null) 'module': module,
    if (description != null) 'description': description,
    'fields': fields.map((f) => f.toJson()).toList(),
    'indexes': indexes.map((i) => i.toJson()).toList(),
    if (enumValues.isNotEmpty) 'enumValues': enumValues,
    if (rowCount != null) 'rowCount': rowCount,
    'positionX': positionX,
    'positionY': positionY,
    if (colorHex != null) 'colorHex': colorHex,
  };

  factory TableNode.fromJson(Map<String, dynamic> json) {
    final entityTypeStr = json['entityType'] as String?;
    final entityType = switch (entityTypeStr) {
      'table' => EntityType.table,
      'object' => EntityType.object,
      'enumeration' => EntityType.enumeration,
      'exception' => EntityType.exception,
      _ => (json['isDatabaseTable'] == false) ? EntityType.object : EntityType.table,
    };

    final isDatabaseTable = (json['isDatabaseTable'] as bool?) ?? (entityType == EntityType.table);

    return TableNode(
      id: json['id'] as String,
      className: json['className'] as String,
      tableName: json['tableName'] as String,
      isDatabaseTable: isDatabaseTable,
      entityType: entityType,
      module: json['module'] as String?,
      description: json['description'] as String?,
      fields: (json['fields'] as List<dynamic>?)
              ?.map((f) => FieldNode.fromJson(f as Map<String, dynamic>))
              .toList() ??
          const [],
      indexes: (json['indexes'] as List<dynamic>?)
              ?.map((i) => IndexNode.fromJson(i as Map<String, dynamic>))
              .toList() ??
          const [],
      enumValues: (json['enumValues'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      rowCount: json['rowCount'] as int?,
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.0,
      colorHex: json['colorHex'] as String?,
    );
  }

  TableNode copyWith({
    String? id,
    String? className,
    String? tableName,
    bool? isDatabaseTable,
    EntityType? entityType,
    String? module,
    String? description,
    List<FieldNode>? fields,
    List<IndexNode>? indexes,
    List<String>? enumValues,
    int? rowCount,
    double? positionX,
    double? positionY,
    String? colorHex,
  }) => TableNode(
    id: id ?? this.id,
    className: className ?? this.className,
    tableName: tableName ?? this.tableName,
    isDatabaseTable: isDatabaseTable ?? this.isDatabaseTable,
    entityType: entityType ?? this.entityType,
    module: module ?? this.module,
    description: description ?? this.description,
    fields: fields ?? this.fields,
    indexes: indexes ?? this.indexes,
    enumValues: enumValues ?? this.enumValues,
    rowCount: rowCount ?? this.rowCount,
    positionX: positionX ?? this.positionX,
    positionY: positionY ?? this.positionY,
    colorHex: colorHex ?? this.colorHex,
  );
}
