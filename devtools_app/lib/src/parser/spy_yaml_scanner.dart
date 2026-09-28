import '../models/schema_graph.dart';
import '../models/table_node.dart';
import 'relation_resolver.dart';
import 'spy_yaml_parser.dart';

/// Web-compatible parser & layout engine that turns YAML strings into a [SchemaGraph].
class SpyYamlScanner {
  final SpyYamlParser _parser;
  final RelationResolver _resolver;

  SpyYamlScanner({
    SpyYamlParser? parser,
    RelationResolver? resolver,
  })  : _parser = parser ?? SpyYamlParser(),
        _resolver = resolver ?? RelationResolver();

  /// Parses a combined raw YAML string into a positioned [SchemaGraph].
  SchemaGraph parseString(String yamlContent) {
    final rawTables = _parser.parseYamlString(yamlContent);
    final resolution = _resolver.resolve(rawTables);
    final positionedTables = _layoutTablesInGrid(resolution.tables);

    return SchemaGraph(
      tables: positionedTables,
      relations: resolution.relations,
      metadata: {
        'tableCount': positionedTables.length,
        'relationCount': resolution.relations.length,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Automatically positions tables in a non-overlapping multi-column layout.
  List<TableNode> _layoutTablesInGrid(List<TableNode> tables) {
    if (tables.isEmpty) return tables;

    const columnWidth = 320.0;
    const horizontalGap = 80.0;
    const rowGap = 50.0;
    const initialMargin = 60.0;

    final columnCount = (tables.length > 4)
        ? (tables.length > 12 ? 4 : 3)
        : (tables.length > 1 ? 2 : 1);

    final columnYPositions = List<double>.filled(columnCount, initialMargin);
    final positioned = <TableNode>[];

    for (var i = 0; i < tables.length; i++) {
      final table = tables[i];
      final col = i % columnCount;
      final x = initialMargin + col * (columnWidth + horizontalGap);
      final y = columnYPositions[col];

      final estimatedHeight = 56.0 + (table.fields.length * 28.0) + 44.0;
      columnYPositions[col] += estimatedHeight + rowGap;

      positioned.add(
        table.copyWith(
          positionX: x,
          positionY: y,
        ),
      );
    }

    return positioned;
  }
}
