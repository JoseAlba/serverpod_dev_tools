import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/schema_graph.dart';
import '../models/table_node.dart';
import 'relation_resolver.dart';
import 'spy_yaml_parser.dart';

/// Scans a Serverpod project directory for `.spy.yaml` files and produces a [SchemaGraph].
class SpyYamlScanner {
  final SpyYamlParser _parser;
  final RelationResolver _resolver;

  SpyYamlScanner({
    SpyYamlParser? parser,
    RelationResolver? resolver,
  })  : _parser = parser ?? SpyYamlParser(),
        _resolver = resolver ?? RelationResolver();

  /// Resolves the most appropriate models directory by checking candidate locations.
  static Directory resolveModelsDirectory(Directory? initial) {
    if (initial != null && initial.existsSync()) return initial;

    final candidates = [
      ?initial,
      Directory('lib/src/models'),
      Directory('lib/src'),
      Directory('lib'),
      Directory('studio_server/lib/src/models'),
      Directory('../studio_server/lib/src/models'),
      Directory('studio_server/lib/src'),
      Directory('../lib/src/models'),
      Directory('../../lib/src/models'),
      Directory('apps/studio/studio_server/lib/src/models'),
      Directory('../../apps/studio/studio_server/lib/src/models'),
    ];

    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        final hasSpyFiles = candidate
            .listSync(recursive: true)
            .whereType<File>()
            .any((f) => f.path.endsWith('.spy.yaml'));
        if (hasSpyFiles) return candidate;
      }
    }

    try {
      for (final entity in Directory.current.listSync(recursive: false)) {
        if (entity is Directory) {
          final subModels = Directory(p.join(entity.path, 'lib', 'src', 'models'));
          if (subModels.existsSync()) return subModels;
        }
      }
    } catch (_) {}

    return initial ?? Directory('lib/src/models');
  }

  /// Scans the given [projectRoot] (or subdirectories like `lib/src/models`) for `.spy.yaml` files.
  Future<SchemaGraph> scanDirectory(Directory projectRoot) async {
    final targetRoot = resolveModelsDirectory(projectRoot);
    final rawTables = <TableNode>[];

    if (!await targetRoot.exists()) {
      return const SchemaGraph(tables: [], relations: []);
    }

    final spyFiles = await _findSpyYamlFiles(targetRoot);

    for (final file in spyFiles) {
      try {
        final content = await file.readAsString();
        final module = _inferModuleName(file.path, targetRoot.path);
        final tables = _parser.parseYamlString(content, moduleName: module);
        rawTables.addAll(tables);
      } catch (_) {
        // Skip unreadable files
        continue;
      }
    }

    // Resolve relations and assign domain colors
    final resolution = _resolver.resolve(rawTables);

    // Compute automatic initial canvas layout positions
    final positionedTables = _layoutTablesInGrid(resolution.tables);

    return SchemaGraph(
      tables: positionedTables,
      relations: resolution.relations,
      metadata: {
        'scannedPath': projectRoot.path,
        'fileCount': spyFiles.length,
        'tableCount': positionedTables.length,
        'relationCount': resolution.relations.length,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Parses a combined raw YAML string directly into a [SchemaGraph] (e.g. from manual input or tests).
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

  /// Recursively finds all `.spy.yaml` and `.yaml` files that match Serverpod model patterns.
  Future<List<File>> _findSpyYamlFiles(Directory root) async {
    final files = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File && entity.path.endsWith('.spy.yaml')) {
        files.add(entity);
      }
    }
    return files;
  }

  /// Infers the logical module/domain name from the relative directory path.
  /// Example: `/path/to/models/courses/course.spy.yaml` -> `courses`.
  String? _inferModuleName(String filePath, String rootPath) {
    final relPath = p.relative(filePath, from: rootPath);
    final segments = p.split(relPath);

    // Look for segment right after 'models' if present
    final modelsIdx = segments.indexOf('models');
    if (modelsIdx >= 0 && modelsIdx + 2 < segments.length) {
      return segments[modelsIdx + 1];
    }

    // If directly in a subdirectory of lib/src/...
    if (segments.length >= 2) {
      return segments[segments.length - 2];
    }

    return null;
  }

  /// Positions tables in a clean, non-overlapping multi-column grid layout for the 2D canvas.
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

      // Estimate card height: header (56px) + ~28px per field + footer (44px)
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
