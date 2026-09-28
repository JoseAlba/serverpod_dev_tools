import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../schema_models.dart';

import '../controllers/canvas_controller.dart';
import '../services/devtools_schema_service.dart';
import 'relation_painter.dart';
import 'table_data_inspector_dialog.dart';
import 'table_node_widget.dart';

/// 2D Infinite Interactive ER Diagram Canvas supporting pan, zoom, and table dragging.
class ERCanvas extends StatefulWidget {
  final CanvasController controller;
  final DevToolsSchemaService service;

  const ERCanvas({
    super.key,
    required this.controller,
    required this.service,
  });

  @override
  State<ERCanvas> createState() => _ERCanvasState();
}

class _ERCanvasState extends State<ERCanvas> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = widget.controller;
    final graph = controller.graph;

    if (graph == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (graph.tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schema_outlined, size: 48, color: colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              'No Serverpod models found',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Make sure .spy.yaml files exist in lib/src/models',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
            ),
          ],
        ),
      );
    }

    final tableByName = graph.tableByName;

    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          // Zoom on scroll wheel
          final zoomDelta = -pointerSignal.scrollDelta.dy * 0.001;
          controller.setZoom(controller.zoom + zoomDelta);
        }
      },
      child: Stack(
        children: [
          // 1. Background Grid & Canvas Pan/Tap Detector (Layer 1)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) => controller.updatePan(details.delta),
              onTap: () => controller.selectTable(null),
              child: CustomPaint(
                painter: _GridBackgroundPainter(
                  pan: controller.pan,
                  zoom: controller.zoom,
                  dotColor: colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),

          // 2. Interactive Diagram Content Layer (Layer 2)
          Positioned.fill(
            child: ClipRect(
              child: Transform(
                transform: Matrix4.identity()
                  ..translateByDouble(controller.pan.dx, controller.pan.dy, 0.0, 1.0)
                  ..scaleByDouble(controller.zoom, controller.zoom, 1.0, 1.0),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // A. Curved Bezier Relation Lines (IgnorePointer so relation lines do not block gestures)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: RelationPainter(
                            relations: graph.relations,
                            positions: controller.positions,
                            tableByName: tableByName,
                            selectedTable: controller.selectedTable,
                            hoveredTable: controller.hoveredTable,
                            colorScheme: colorScheme,
                          ),
                        ),
                      ),
                    ),

                    // B. Draggable Table Entity Cards
                    for (final table in graph.tables)
                      if (controller.isTableVisible(table))
                        _buildPositionedTable(context, table),
                  ],
                ),
              ),
            ),
          ),

        // 2. Top-Right Canvas Control Toolbar
        Positioned(
          top: 14,
          right: 14,
          child: _buildCanvasToolbar(context),
        ),

        // 3. Bottom-Left Canvas Hint Pill
        Positioned(
          left: 14,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              'Drag tables to rearrange · scroll to zoom · drag background to pan · tap table to inspect',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildPositionedTable(BuildContext context, TableNode table) {
    final controller = widget.controller;
    final pos = controller.positions[table.tableName] ?? Offset.zero;
    final isSelected = controller.selectedTable == table.tableName;

    // Check if table is connected to selected or hovered table
    var isDimmed = false;
    if (controller.selectedTable != null && controller.selectedTable != table.tableName) {
      final isConnected = controller.graph?.relations.any((r) =>
          (r.fromTable == controller.selectedTable && r.toTable == table.tableName) ||
          (r.toTable == controller.selectedTable && r.fromTable == table.tableName)) ?? false;
      isDimmed = !isConnected;
    }

    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: TableNodeWidget(
        table: table,
        isSelected: isSelected,
        isDimmed: isDimmed,
        searchQuery: controller.searchQuery,
        onDragDelta: (delta) => controller.updateTablePosition(table.tableName, delta),
        onTap: () {
          controller.selectTable(table.tableName);
        },
        onInspectData: () => TableDataInspectorDialog.show(
          context,
          table: table,
          service: widget.service,
        ),
      ),
    );
  }

  Widget _buildCanvasToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final controller = widget.controller;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            tooltip: 'Zoom out',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: controller.zoomOut,
          ),
          InkWell(
            onTap: controller.resetZoom,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                '${(controller.zoom * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            tooltip: 'Zoom in',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: controller.zoomIn,
          ),
          Container(
            height: 18,
            width: 1,
            color: colorScheme.outlineVariant,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_mosaic_outlined, size: 16),
            tooltip: 'Auto-arrange layout',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: controller.autoLayout,
          ),
        ],
      ),
    );
  }
}

/// Paints an infinite subtle dot grid on the canvas background.
class _GridBackgroundPainter extends CustomPainter {
  final Offset pan;
  final double zoom;
  final Color dotColor;

  const _GridBackgroundPainter({
    required this.pan,
    required this.zoom,
    required this.dotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    const baseSpacing = 24.0;
    final spacing = baseSpacing * zoom;
    if (spacing < 8.0) return; // avoid overdrawing when zoomed far out

    final offsetX = pan.dx % spacing;
    final offsetY = pan.dy % spacing;

    for (var x = offsetX; x < size.width; x += spacing) {
      for (var y = offsetY; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridBackgroundPainter oldDelegate) {
    return oldDelegate.pan != pan ||
        oldDelegate.zoom != zoom ||
        oldDelegate.dotColor != dotColor;
  }
}
