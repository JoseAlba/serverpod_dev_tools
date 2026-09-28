import 'package:flutter/material.dart';
import '../schema_models.dart';

/// State controller for the 2D interactive ER diagram canvas.
class CanvasController extends ChangeNotifier {
  SchemaGraph? _graph;
  final Map<String, Offset> _positions = {};

  double _zoom = 1.0;
  Offset _pan = const Offset(60, 40);

  String? _selectedTable;
  String? _hoveredTable;
  String _searchQuery = '';
  String? _selectedModuleFilter;
  EntityType? _selectedTypeFilter;
  bool _databaseOnly = false;

  // Getters
  SchemaGraph? get graph => _graph;
  Map<String, Offset> get positions => _positions;
  double get zoom => _zoom;
  Offset get pan => _pan;
  String? get selectedTable => _selectedTable;
  String? get hoveredTable => _hoveredTable;
  String get searchQuery => _searchQuery;
  String? get selectedModuleFilter => _selectedModuleFilter;
  EntityType? get selectedTypeFilter => _selectedTypeFilter;
  bool get databaseOnly => _databaseOnly;

  /// Sets the active schema graph and initializes node positions.
  void setGraph(SchemaGraph graph) {
    _graph = graph;
    _positions.clear();

    for (final table in graph.tables) {
      _positions[table.tableName] = Offset(table.positionX, table.positionY);
    }
    notifyListeners();
  }

  /// Updates the canvas position of a specific table node when dragged.
  void updateTablePosition(String tableName, Offset delta) {
    final current = _positions[tableName] ?? Offset.zero;
    _positions[tableName] = current + (delta / _zoom);
    notifyListeners();
  }

  /// Selects a table for detail inspection and relation highlighting.
  void selectTable(String? tableName) {
    if (_selectedTable != tableName) {
      _selectedTable = tableName;
      notifyListeners();
    }
  }

  /// Sets the currently hovered table for edge highlighting.
  void setHoveredTable(String? tableName) {
    if (_hoveredTable != tableName) {
      _hoveredTable = tableName;
      notifyListeners();
    }
  }

  /// Updates the search filter query.
  void setSearchQuery(String query) {
    _searchQuery = query.trim().toLowerCase();
    notifyListeners();
  }

  /// Sets the active module domain filter (e.g. `courses`, `students`, or null for all).
  void setModuleFilter(String? module) {
    _selectedModuleFilter = module;
    notifyListeners();
  }

  /// Sets the active entity type filter (e.g. table, object, enum, exception, or null for all).
  void setTypeFilter(EntityType? type) {
    _selectedTypeFilter = type;
    notifyListeners();
  }

  /// Sets whether to only show actual physical PostgreSQL database tables.
  void setDatabaseOnly(bool val) {
    _databaseOnly = val;
    notifyListeners();
  }

  /// Adjusts zoom level within comfortable limits [0.25, 2.5].
  void setZoom(double newZoom) {
    _zoom = newZoom.clamp(0.25, 2.5);
    notifyListeners();
  }

  void zoomIn() => setZoom(_zoom + 0.15);
  void zoomOut() => setZoom(_zoom - 0.15);
  void resetZoom() {
    _zoom = 1.0;
    _pan = const Offset(60, 40);
    notifyListeners();
  }

  /// Pans the canvas viewport.
  void updatePan(Offset delta) {
    _pan += delta;
    notifyListeners();
  }

  /// Centers the canvas viewport on a specific table.
  void centerOnTable(String tableName, Size viewportSize) {
    final pos = _positions[tableName];
    if (pos == null) return;

    _pan = Offset(
      (viewportSize.width / 2) - (pos.dx * _zoom) - (140 * _zoom),
      (viewportSize.height / 2) - (pos.dy * _zoom) - (100 * _zoom),
    );
    _selectedTable = tableName;
    notifyListeners();
  }

  /// Automatically rearranges all tables into an organized, non-overlapping multi-column layout.
  void autoLayout() {
    if (_graph == null || _graph!.tables.isEmpty) return;

    final tables = _graph!.tables;
    const columnWidth = 320.0;
    const horizontalGap = 80.0;
    const rowGap = 40.0;
    const initialMargin = 60.0;

    final columnCount = (tables.length > 8) ? 3 : (tables.length > 3 ? 2 : 1);
    final colY = List<double>.filled(columnCount, initialMargin);

    for (var i = 0; i < tables.length; i++) {
      final table = tables[i];
      final col = i % columnCount;
      final x = initialMargin + col * (columnWidth + horizontalGap);
      final y = colY[col];

      final cardHeight = 60.0 + (table.fields.length * 28.0) + 40.0;
      colY[col] += cardHeight + rowGap;

      _positions[table.tableName] = Offset(x, y);
    }

    notifyListeners();
  }

  /// Checks if a table matches the current search, module, and database/type filters.
  bool isTableVisible(TableNode table) {
    if (_databaseOnly && !table.isDatabaseTable) {
      return false;
    }

    if (_selectedTypeFilter != null && table.entityType != _selectedTypeFilter) {
      return false;
    }

    if (_selectedModuleFilter != null && table.module != _selectedModuleFilter) {
      return false;
    }

    if (_searchQuery.isEmpty) return true;

    if (table.tableName.toLowerCase().contains(_searchQuery) ||
        table.className.toLowerCase().contains(_searchQuery)) {
      return true;
    }

    // Check if any field name matches
    return table.fields.any((f) => f.name.toLowerCase().contains(_searchQuery));
  }
}
