import '../models/field_node.dart';
import '../models/relation_edge.dart';
import '../models/table_node.dart';

/// Resolves explicit and conventional relationships between [TableNode]s to build [RelationEdge]s.
class RelationResolver {
  /// Curated color palette for domain/module tagging.
  static const List<String> defaultPalette = [
    '#5fd4c4', // Cyan
    '#e3b341', // Amber/Gold
    '#f0966a', // Coral
    '#9d8cf0', // Lavender/Purple
    '#6bb1f0', // Sky Blue
    '#f08cc4', // Rose Pink
    '#8fd16b', // Emerald Green
    '#e879f9', // Fuchsia
    '#38bdf8', // Light Blue
  ];

  /// Resolves all relations and assigns palette colors and layout positions.
  RelationResolutionResult resolve(List<TableNode> tables) {
    final relations = <RelationEdge>[];
    final updatedTables = <TableNode>[];

    // Build lookup maps
    final tableNameMap = <String, TableNode>{};
    final classNameMap = <String, TableNode>{};
    final stemMap = <String, TableNode>{};

    for (final table in tables) {
      tableNameMap[table.tableName.toLowerCase()] = table;
      classNameMap[table.className.toLowerCase()] = table;

      // Stem without standard prefixes like 'learnos_', 'tbl_', etc.
      final stem = table.tableName
          .replaceFirst(RegExp(r'^(learnos_|tbl_|app_)'), '')
          .replaceAll('_', '')
          .toLowerCase();
      stemMap[stem] = table;
    }

    // Module color mapping
    final moduleColorMap = <String, String>{};
    var colorIndex = 0;

    for (var i = 0; i < tables.length; i++) {
      final table = tables[i];
      final module = table.module ?? 'default';
      final colorHex = moduleColorMap.putIfAbsent(
        module,
        () => defaultPalette[colorIndex++ % defaultPalette.length],
      );

      final updatedFields = <FieldNode>[];

      for (final field in table.fields) {
        // Skip primary key fields themselves
        if (field.name == 'id' || field.isPrimaryKey) {
          updatedFields.add(field);
          continue;
        }

        TableNode? targetTable;
        String targetField = 'id';
        var isExplicit = false;
        String? relationName;

        // 1. Check explicit foreign key
        if (field.isForeignKey && field.foreignKeyTargetTable != null) {
          final targetName = field.foreignKeyTargetTable!.toLowerCase();
          targetTable = tableNameMap[targetName] ?? classNameMap[targetName];
          targetField = field.foreignKeyTargetField ?? (targetTable?.primaryKeyField?.name ?? 'id');
          isExplicit = true;
        }

        // 2. Inferred foreign key via naming convention: courseUuid, studentUuid, companyId, authorId
        if (targetTable == null) {
          final match = RegExp(r'^([a-zA-Z0-9]+)(Uuid|Id)$').firstMatch(field.name);
          if (match != null) {
            final prefix = match.group(1)!.toLowerCase();
            final keyType = match.group(2); // 'Uuid' or 'Id'

            targetTable = classNameMap[prefix] ??
                tableNameMap[prefix] ??
                tableNameMap['learnos_$prefix'] ??
                stemMap[prefix];

            if (targetTable != null && targetTable.tableName != table.tableName) {
              targetField = (keyType == 'Uuid') ? 'uuid' : 'id';
              isExplicit = false;
            } else {
              targetTable = null;
            }
          }
        }

        if (targetTable != null) {
          // Check if unique index exists on this field -> 1:1, otherwise 1:N
          final isUnique = table.indexes.any(
            (idx) => idx.isUnique && idx.fields.length == 1 && idx.fields.contains(field.name),
          );
          final cardinality = isUnique ? '1:1' : '1:N';

          final edgeId = '${table.tableName}.${field.name}->${targetTable.tableName}.$targetField';

          // Avoid duplicate edges
          if (!relations.any((r) => r.id == edgeId)) {
            relations.add(
              RelationEdge(
                id: edgeId,
                fromTable: table.tableName,
                fromField: field.name,
                toTable: targetTable.tableName,
                toField: targetField,
                cardinality: cardinality,
                relationName: relationName,
                isExplicit: isExplicit,
              ),
            );
          }

          updatedFields.add(
            field.copyWith(
              isForeignKey: true,
              foreignKeyTargetTable: targetTable.tableName,
              foreignKeyTargetField: targetField,
            ),
          );
        } else {
          updatedFields.add(field);
        }
      }

      updatedTables.add(
        table.copyWith(
          fields: updatedFields,
          colorHex: colorHex,
        ),
      );
    }

    return RelationResolutionResult(
      tables: updatedTables,
      relations: relations,
    );
  }
}

/// Result of the relation resolution containing updated tables and relationship edges.
class RelationResolutionResult {
  final List<TableNode> tables;
  final List<RelationEdge> relations;

  const RelationResolutionResult({
    required this.tables,
    required this.relations,
  });
}
