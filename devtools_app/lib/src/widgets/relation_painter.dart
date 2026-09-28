import 'package:flutter/material.dart';
import '../schema_models.dart';

/// CustomPainter rendering smooth cubic bezier relation edges and crow's foot notation.
class RelationPainter extends CustomPainter {
  final List<RelationEdge> relations;
  final Map<String, Offset> positions;
  final Map<String, TableNode> tableByName;
  final String? selectedTable;
  final String? hoveredTable;
  final ColorScheme colorScheme;

  const RelationPainter({
    required this.relations,
    required this.positions,
    required this.tableByName,
    this.selectedTable,
    this.hoveredTable,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final rel in relations) {
      final fromPos = positions[rel.fromTable];
      final toPos = positions[rel.toTable];
      if (fromPos == null || toPos == null) continue;

      final fromTableNode = tableByName[rel.fromTable];
      final toTableNode = tableByName[rel.toTable];

      // Calculate anchor Y positions based on field index
      final y1 = fromPos.dy + _calculateFieldYOffset(fromTableNode, rel.fromField);
      final y2 = toPos.dy + _calculateFieldYOffset(toTableNode, rel.toField);

      // Determine left-to-right or right-to-left connection
      const cardWidth = 280.0;
      final fromRight = fromPos.dx < toPos.dx;
      final x1 = fromRight ? fromPos.dx + cardWidth : fromPos.dx;
      final x2 = fromRight ? toPos.dx : toPos.dx + cardWidth;

      final isHighlighted = (selectedTable != null &&
              (selectedTable == rel.fromTable || selectedTable == rel.toTable)) ||
          (hoveredTable != null &&
              (hoveredTable == rel.fromTable || hoveredTable == rel.toTable));

      // Parse edge color from source table or theme
      final edgeColor = _parseColor(fromTableNode?.colorHex) ?? colorScheme.primary;

      final paint = Paint()
        ..color = isHighlighted ? edgeColor : edgeColor.withValues(alpha: 0.6)
        ..strokeWidth = isHighlighted ? 2.4 : 1.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      // Draw cubic bezier curve
      final mx = (x1 + x2) / 2;
      final path = Path()
        ..moveTo(x1, y1)
        ..cubicTo(mx, y1, mx, y2, x2, y2);

      canvas.drawPath(path, paint);

      // 1. Target endpoint: "One" tick mark
      final tickDx = fromRight ? -8.0 : 8.0;
      canvas.drawLine(
        Offset(x2 - tickDx, y2 - 6),
        Offset(x2 - tickDx, y2 + 6),
        paint,
      );

      // 2. Source endpoint: Crow's foot for 1:N, or single tick for 1:1
      if (rel.cardinality == '1:N') {
        final footDx = fromRight ? 10.0 : -10.0;
        final footPath = Path()
          ..moveTo(x1, y1)
          ..lineTo(x1 + footDx, y1 - 6)
          ..moveTo(x1, y1)
          ..lineTo(x1 + footDx, y1 + 6);
        canvas.drawPath(footPath, paint);
      } else {
        // 1:1 tick mark
        final singleTickDx = fromRight ? 8.0 : -8.0;
        canvas.drawLine(
          Offset(x1 + singleTickDx, y1 - 6),
          Offset(x1 + singleTickDx, y1 + 6),
          paint,
        );
      }
    }
  }

  /// Calculates vertical offset of a field within the table card.
  double _calculateFieldYOffset(TableNode? table, String fieldName) {
    if (table == null) return 40.0;
    final idx = table.fields.indexWhere((f) => f.name == fieldName);
    final fieldIdx = idx >= 0 ? idx : 0;
    // Header height (44) + field row height (28.5) * fieldIdx + half row (14)
    return 44.0 + (fieldIdx * 28.5) + 14.0;
  }

  static Color? _parseColor(String? hexString) {
    if (hexString == null) return null;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    final intVal = int.tryParse(buffer.toString(), radix: 16);
    return intVal != null ? Color(intVal) : null;
  }

  @override
  bool shouldRepaint(covariant RelationPainter oldDelegate) {
    return oldDelegate.relations != relations ||
        oldDelegate.positions != positions ||
        oldDelegate.selectedTable != selectedTable ||
        oldDelegate.hoveredTable != hoveredTable;
  }
}
