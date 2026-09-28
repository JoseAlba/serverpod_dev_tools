import 'package:flutter/material.dart';
import '../schema_models.dart';

/// Draggable Luna Modeler / Claude style table card representing a database entity.
class TableNodeWidget extends StatefulWidget {
  final TableNode table;
  final bool isSelected;
  final bool isDimmed;
  final String searchQuery;
  final ValueChanged<Offset> onDragDelta;
  final VoidCallback onTap;
  final VoidCallback onInspectData;

  const TableNodeWidget({
    super.key,
    required this.table,
    this.isSelected = false,
    this.isDimmed = false,
    this.searchQuery = '',
    required this.onDragDelta,
    required this.onTap,
    required this.onInspectData,
  });

  @override
  State<TableNodeWidget> createState() => _TableNodeWidgetState();
}

class _TableNodeWidgetState extends State<TableNodeWidget> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Parse accent color from hex
    final accentColor = _parseColor(widget.table.colorHex) ?? colorScheme.primary;

    return Opacity(
      opacity: widget.isDimmed ? 0.35 : 1.0,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) => widget.onDragDelta(details.delta),
          onTap: widget.onTap,
          child: Container(
            width: 280,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: widget.isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant.withValues(alpha: 0.7),
                width: widget.isSelected ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected
                      ? colorScheme.primary.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.18),
                  blurRadius: widget.isSelected ? 16 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Table Header
                _buildHeader(context, accentColor),

                // 2. Field Rows (if not collapsed)
                if (!_isCollapsed) ...[
                  const Divider(height: 1, thickness: 1),
                  for (final field in widget.table.fields) _buildFieldRow(context, field),
                ],

                // 3. Table Action Footer
                _buildFooter(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color accentColor) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
          border: Border(
            left: BorderSide(color: accentColor, width: 4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator,
              size: 15,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.table.className,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _buildEntityTypeBadge(widget.table.entityType, widget.table.isDatabaseTable),
                    ],
                  ),
                  Text(
                    widget.table.isDatabaseTable ? widget.table.tableName : widget.table.entityType.name.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              tooltip: _isCollapsed ? 'Expand fields' : 'Collapse fields',
              onPressed: () => setState(() => _isCollapsed = !_isCollapsed),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldRow(BuildContext context, FieldNode field) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isPk = field.isPrimaryKey;
    final isFk = field.isForeignKey;

    // Check search highlight
    final matchesSearch = widget.searchQuery.isNotEmpty &&
        field.name.toLowerCase().contains(widget.searchQuery);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: matchesSearch
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.25),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Key icon
          SizedBox(
            width: 16,
            child: isPk
                ? const Tooltip(
                    message: 'Primary Key',
                    child: Text(
                      '◆',
                      style: TextStyle(
                        color: Color(0xFFE3B341),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : isFk
                    ? Tooltip(
                        message: 'Foreign Key -> ${field.foreignKeyTargetTable}',
                        child: const Text(
                          '⇢',
                          style: TextStyle(
                            color: Color(0xFF5FD4C4),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
          const SizedBox(width: 4),

          // Field name
          Expanded(
            child: Text(
              field.name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 11.5,
                fontWeight: isPk || !field.isNullable ? FontWeight.w600 : FontWeight.normal,
                color: isFk ? const Color(0xFF5FD4C4) : colorScheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Type label
          Text(
            '${field.type}${field.isNullable ? '?' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              fontSize: 10.5,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.table.isDatabaseTable
                ? '${widget.table.fields.length} columns'
                : '${widget.table.fields.length} properties',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          if (widget.table.isDatabaseTable)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: OutlinedButton.icon(
                key: Key('inspect_data_${widget.table.tableName}'),
                icon: Icon(Icons.table_chart_outlined, size: 13, color: colorScheme.primary),
                label: Text(
                  'Inspect Data',
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: const Size(0, 26),
                  side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: widget.onInspectData,
              ),
            )
          else
            Text(
              widget.table.entityType == EntityType.enumeration
                  ? 'Enum Definition'
                  : 'Serializable Object',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 9.5,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildEntityTypeBadge(EntityType type, bool isDatabaseTable) {
    final (label, color) = switch (type) {
      EntityType.table => ('TABLE', const Color(0xFF5FD4C4)),
      EntityType.object => ('DTO', const Color(0xFF60A5FA)),
      EntityType.enumeration => ('ENUM', const Color(0xFFFBBF24)),
      EntityType.exception => ('EXC', const Color(0xFFF87171)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static Color? _parseColor(String? hexString) {
    if (hexString == null) return null;
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    final intVal = int.tryParse(buffer.toString(), radix: 16);
    return intVal != null ? Color(intVal) : null;
  }
}
