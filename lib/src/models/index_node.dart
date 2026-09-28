/// Represents an index definition on a Serverpod table entity.
class IndexNode {
  /// Name of the database index (e.g. `course_uuid_idx`).
  final String name;

  /// Ordered list of column/field names covered by the index.
  final List<String> fields;

  /// Whether this index enforces uniqueness.
  final bool isUnique;

  const IndexNode({
    required this.name,
    required this.fields,
    this.isUnique = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'fields': fields,
    'isUnique': isUnique,
  };

  factory IndexNode.fromJson(Map<String, dynamic> json) => IndexNode(
    name: json['name'] as String,
    fields: (json['fields'] as List<dynamic>).map((e) => e.toString()).toList(),
    isUnique: json['isUnique'] as bool? ?? false,
  );
}
