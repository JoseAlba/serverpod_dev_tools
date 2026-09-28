/// Represents a single column or field within a Serverpod model entity.
class FieldNode {
  /// The field identifier (e.g., `id`, `uuid`, `courseUuid`).
  final String name;

  /// The Dart/Serverpod base type (e.g., `int`, `String`, `UuidValue`, `DateTime`).
  final String type;

  /// Whether this field is the table's primary key (`id` or marked primary key).
  final bool isPrimaryKey;

  /// Whether this field acts as a foreign key pointing to another table.
  final bool isForeignKey;

  /// If this is a foreign key, the target table name it references.
  final String? foreignKeyTargetTable;

  /// If this is a foreign key, the target field name it references (usually `id` or `uuid`).
  final String? foreignKeyTargetField;

  /// Whether this field allows null values (`?`).
  final bool isNullable;

  /// Whether this field is a list collection (`List<T>`).
  final bool isList;

  /// Human-readable documentation comment describing this field.
  final String? description;

  const FieldNode({
    required this.name,
    required this.type,
    this.isPrimaryKey = false,
    this.isForeignKey = false,
    String? foreignKeyTargetTable,
    String? relationTargetTable,
    this.foreignKeyTargetField,
    this.isNullable = false,
    this.isList = false,
    this.description,
  }) : foreignKeyTargetTable = foreignKeyTargetTable ?? relationTargetTable;

  /// Compatibility getter for target table.
  String? get relationTargetTable => foreignKeyTargetTable;

  FieldNode copyWith({
    String? name,
    String? type,
    bool? isPrimaryKey,
    bool? isForeignKey,
    String? foreignKeyTargetTable,
    String? foreignKeyTargetField,
    bool? isNullable,
    bool? isList,
    String? description,
  }) => FieldNode(
    name: name ?? this.name,
    type: type ?? this.type,
    isPrimaryKey: isPrimaryKey ?? this.isPrimaryKey,
    isForeignKey: isForeignKey ?? this.isForeignKey,
    foreignKeyTargetTable: foreignKeyTargetTable ?? this.foreignKeyTargetTable,
    foreignKeyTargetField: foreignKeyTargetField ?? this.foreignKeyTargetField,
    isNullable: isNullable ?? this.isNullable,
    isList: isList ?? this.isList,
    description: description ?? this.description,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'isPrimaryKey': isPrimaryKey,
    'isForeignKey': isForeignKey,
    if (foreignKeyTargetTable != null) 'foreignKeyTargetTable': foreignKeyTargetTable,
    if (foreignKeyTargetField != null) 'foreignKeyTargetField': foreignKeyTargetField,
    'isNullable': isNullable,
    'isList': isList,
    if (description != null) 'description': description,
  };

  factory FieldNode.fromJson(Map<String, dynamic> json) => FieldNode(
    name: json['name'] as String,
    type: json['type'] as String,
    isPrimaryKey: json['isPrimaryKey'] as bool? ?? false,
    isForeignKey: json['isForeignKey'] as bool? ?? false,
    foreignKeyTargetTable: json['foreignKeyTargetTable'] as String?,
    foreignKeyTargetField: json['foreignKeyTargetField'] as String?,
    isNullable: json['isNullable'] as bool? ?? false,
    isList: json['isList'] as bool? ?? false,
    description: json['description'] as String?,
  );
}
