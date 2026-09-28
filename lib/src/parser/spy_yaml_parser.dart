import 'package:yaml/yaml.dart';

import '../models/field_node.dart';
import '../models/index_node.dart';
import '../models/table_node.dart';

/// Parses Serverpod `.spy.yaml` model files into structured [TableNode] definitions.
class SpyYamlParser {
  /// Known primitive scalar types in Serverpod.
  static const Set<String> _primitiveTypes = {
    'bool',
    'int',
    'double',
    'String',
    'Duration',
    'DateTime',
    'ByteData',
    'UuidValue',
    'Uri',
    'BigInt',
  };

  /// Parses a YAML document string (or multi-document string separated by `---`) into [TableNode]s.
  ///
  /// [moduleName] can optionally tag the extracted tables with a domain category (e.g. `courses`).
  List<TableNode> parseYamlString(String yamlContent, {String? moduleName}) {
    final tables = <TableNode>[];
    final documents = _splitMultiDocYaml(yamlContent);

    for (final docStr in documents) {
      final trimmed = docStr.trim();
      if (trimmed.isEmpty) continue;

      try {
        final doc = loadYaml(trimmed);
        if (doc is! Map) continue;

        // Detect entity type
        String? className;
        String? tableName;
        var isDatabaseTable = false;
        var entityType = EntityType.object;
        var enumValues = <String>[];

        if (doc.containsKey('class')) {
          className = doc['class']?.toString();
          if (className == null) continue;
          if (doc.containsKey('table') && doc['table'] != null) {
            isDatabaseTable = true;
            entityType = EntityType.table;
            tableName = doc['table'].toString();
          } else {
            isDatabaseTable = false;
            entityType = EntityType.object;
            tableName = className;
          }
        } else if (doc.containsKey('enum')) {
          className = doc['enum']?.toString();
          if (className == null) continue;
          isDatabaseTable = false;
          entityType = EntityType.enumeration;
          tableName = className;
          final rawVals = doc['values'];
          if (rawVals is List) {
            enumValues = rawVals.map((e) => e.toString()).toList();
          }
        } else if (doc.containsKey('exception')) {
          className = doc['exception']?.toString();
          if (className == null) continue;
          isDatabaseTable = false;
          entityType = EntityType.exception;
          tableName = className;
        } else {
          continue;
        }

        // Extract class-level doc comment if present
        final description = _extractClassDocComment(trimmed);

        // Parse fields
        final fields = <FieldNode>[];
        if (entityType == EntityType.enumeration) {
          for (final val in enumValues) {
            fields.add(FieldNode(
              name: val,
              type: className,
              description: 'Enum value',
            ));
          }
        } else {
          final rawFields = doc['fields'];
          var hasId = false;
          if (rawFields is Map) {
            rawFields.forEach((key, value) {
              final field = _parseField(key.toString(), value?.toString() ?? '', trimmed);
              if (field.name == 'id') hasId = true;
              fields.add(field);
            });
          }

          // In Serverpod, only actual database tables have an auto-managed 'id' primary key
          if (isDatabaseTable && !hasId) {
            fields.insert(
              0,
              const FieldNode(
                name: 'id',
                type: 'int',
                isPrimaryKey: true,
                isNullable: false,
                description: 'Primary key (auto-managed by Serverpod)',
              ),
            );
          }
        }

        // Parse indexes
        final indexes = <IndexNode>[];
        final rawIndexes = doc['indexes'];
        if (rawIndexes is Map) {
          rawIndexes.forEach((idxName, idxDef) {
            if (idxDef is Map) {
              final rawFieldsList = idxDef['fields'];
              final fieldsList = <String>[];
              if (rawFieldsList is List) {
                fieldsList.addAll(rawFieldsList.map((e) => e.toString()));
              } else if (rawFieldsList != null) {
                // Comma separated fields string
                fieldsList.addAll(
                  rawFieldsList.toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty),
                );
              }

              final isUnique = idxDef['unique'] == true || idxDef['unique']?.toString().toLowerCase() == 'true';
              indexes.add(
                IndexNode(
                  name: idxName.toString(),
                  fields: fieldsList,
                  isUnique: isUnique,
                ),
              );
            }
          });
        }

        tables.add(
          TableNode(
            id: tableName,
            className: className,
            tableName: tableName,
            isDatabaseTable: isDatabaseTable,
            entityType: entityType,
            module: moduleName,
            description: description,
            fields: fields,
            indexes: indexes,
            enumValues: enumValues,
          ),
        );
      } catch (_) {
        // Skip unparseable fragments gracefully
        continue;
      }
    }

    return tables;
  }

  /// Parses a single field entry like `title: String?` or `company: Company?, relation(parent=company)`.
  FieldNode _parseField(String fieldName, String rawValue, String fullYaml) {
    final parts = _splitTopLevelCommas(rawValue);
    final rawType = parts.isNotEmpty ? parts[0].trim() : 'String';
    final modifiers = parts.skip(1).map((s) => s.trim()).toList();

    // Check if list: List<T>
    final listMatch = RegExp(r'^List<(.+)>$').firstMatch(rawType);
    final isList = listMatch != null;
    var baseType = isList ? listMatch.group(1)!.trim() : rawType;

    // Check nullability: Type?
    final isNullable = baseType.endsWith('?');
    if (isNullable) {
      baseType = baseType.substring(0, baseType.length - 1).trim();
    }

    // Handle module prefix: module:auth:UserInfo -> UserInfo
    if (baseType.startsWith('module:')) {
      final colonParts = baseType.split(':');
      baseType = colonParts.length > 2 ? colonParts[2] : colonParts.last;
    }

    // Check for relation modifier: relation, relation(parent=...), relation(name=...)
    var isForeignKey = modifiers.any((m) => m.startsWith('relation'));
    String? foreignKeyTargetTable;
    String? foreignKeyTargetField;

    for (final mod in modifiers) {
      if (mod.startsWith('relation')) {
        final parenMatch = RegExp(r'relation\(([^)]*)\)').firstMatch(mod);
        if (parenMatch != null) {
          final args = parenMatch.group(1)!.split(',');
          for (final arg in args) {
            final kv = arg.split('=');
            if (kv.length == 2) {
              final k = kv[0].trim();
              final v = kv[1].trim();
              if (k == 'parent') {
                foreignKeyTargetTable = v;
              } else if (k == 'field') {
                foreignKeyTargetField = v;
              }
            }
          }
        }

        // If no explicit parent specified but baseType is a custom entity class
        if (foreignKeyTargetTable == null && !_primitiveTypes.contains(baseType)) {
          foreignKeyTargetTable = _camelToSnakeCase(baseType);
        }
      }
    }

    final isPrimaryKey = fieldName == 'id';
    final docComment = _extractFieldDocComment(fieldName, fullYaml);

    return FieldNode(
      name: fieldName,
      type: isList ? 'List<$baseType>' : baseType,
      isPrimaryKey: isPrimaryKey,
      isForeignKey: isForeignKey,
      foreignKeyTargetTable: foreignKeyTargetTable,
      foreignKeyTargetField: foreignKeyTargetField,
      isNullable: isNullable,
      isList: isList,
      description: docComment,
    );
  }

  /// Splits comma-separated modifiers while preserving commas inside parentheses `relation(a=1, b=2)`.
  List<String> _splitTopLevelCommas(String input) {
    final result = <String>[];
    var depth = 0;
    var current = StringBuffer();

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (char == '(') {
        depth++;
        current.write(char);
      } else if (char == ')') {
        depth = (depth > 0) ? depth - 1 : 0;
        current.write(char);
      } else if (char == ',' && depth == 0) {
        result.add(current.toString().trim());
        current = StringBuffer();
      } else {
        current.write(char);
      }
    }

    if (current.isNotEmpty) {
      result.add(current.toString().trim());
    }

    return result;
  }

  /// Splits multi-document YAML strings separated by `---`.
  List<String> _splitMultiDocYaml(String content) {
    final docs = <String>[];
    final lines = content.split('\n');
    final current = StringBuffer();

    for (final line in lines) {
      if (line.trim() == '---') {
        if (current.isNotEmpty) {
          docs.add(current.toString());
          current.clear();
        }
      } else {
        current.writeln(line);
      }
    }

    if (current.isNotEmpty) {
      docs.add(current.toString());
    }

    return docs;
  }

  /// Converts a CamelCase class name (`StudentProfile`) to snake_case (`student_profile`).
  static String _camelToSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'(?<=[a-z])[A-Z]'),
      (Match m) => '_${m.group(0)}',
    ).toLowerCase();
  }

  /// Extracts comments immediately preceding `class:` in the YAML text.
  String? _extractClassDocComment(String yaml) {
    final lines = yaml.split('\n');
    final commentLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('###') || trimmed.startsWith('#')) {
        final cleaned = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        commentLines.add(cleaned);
      } else if (trimmed.startsWith('class:')) {
        break;
      } else if (trimmed.isNotEmpty) {
        commentLines.clear();
      }
    }

    return commentLines.isNotEmpty ? commentLines.join(' ').trim() : null;
  }

  /// Extracts comments immediately preceding a field declaration in the YAML text.
  String? _extractFieldDocComment(String fieldName, String yaml) {
    final lines = yaml.split('\n');
    final commentLines = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.startsWith('###') || trimmed.startsWith('#')) {
        final cleaned = trimmed.replaceFirst(RegExp(r'^#+\s*'), '');
        commentLines.add(cleaned);
      } else if (trimmed.startsWith('$fieldName:')) {
        return commentLines.isNotEmpty ? commentLines.join(' ').trim() : null;
      } else if (trimmed.isNotEmpty && !trimmed.startsWith('fields:')) {
        commentLines.clear();
      }
    }

    return null;
  }
}
