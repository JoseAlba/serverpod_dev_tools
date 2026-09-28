import 'package:flutter/material.dart';

import '../controllers/canvas_controller.dart';
import '../schema_models.dart';
import '../services/devtools_schema_service.dart';
import 'table_data_inspector_dialog.dart';

/// Left sidebar showing entity lists, search, module filters, and the ER diagram legend.
class SidebarPanel extends StatelessWidget {
  final CanvasController controller;
  final DevToolsSchemaService service;
  final VoidCallback onRefresh;
  final VoidCallback onOpenYamlViewer;

  const SidebarPanel({
    super.key,
    required this.controller,
    required this.service,
    required this.onRefresh,
    required this.onOpenYamlViewer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final graph = controller.graph;

    final tables = graph?.tables ?? const [];
    final relations = graph?.relations ?? const [];

    // Extract unique modules
    final modules = <String>{};
    for (final table in tables) {
      if (table.module != null && table.module!.isNotEmpty) {
        modules.add(table.module!);
      }
    }

    final visibleTables = tables.where(controller.isTableVisible).toList();

    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Sidebar Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
            child: Row(
              children: [
                Icon(Icons.hub_outlined, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Serverpod Schema',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Rescan and refresh schema',
                  onPressed: onRefresh,
                ),
              ],
            ),
          ),

          // 2. Summary stats
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${tables.where((t) => t.isDatabaseTable).length} DB tables · ${tables.where((t) => !t.isDatabaseTable).length} models/enums · ${relations.length} relations',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 2b. Entity Category Filter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('All (${tables.length})', style: const TextStyle(fontSize: 11)),
                    selected: controller.selectedTypeFilter == null && !controller.databaseOnly,
                    onSelected: (_) {
                      controller.setDatabaseOnly(false);
                      controller.setTypeFilter(null);
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.storage, size: 14),
                    label: Text(
                      'DB Tables (${tables.where((t) => t.isDatabaseTable).length})',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: controller.databaseOnly,
                    onSelected: (val) {
                      controller.setTypeFilter(null);
                      controller.setDatabaseOnly(val);
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.data_object, size: 14),
                    label: Text(
                      'DTOs (${tables.where((t) => t.entityType == EntityType.object).length})',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: controller.selectedTypeFilter == EntityType.object,
                    onSelected: (val) {
                      controller.setDatabaseOnly(false);
                      controller.setTypeFilter(val ? EntityType.object : null);
                    },
                  ),
                  const SizedBox(width: 6),
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.list, size: 14),
                    label: Text(
                      'Enums (${tables.where((t) => t.entityType == EntityType.enumeration || t.entityType == EntityType.exception).length})',
                      style: const TextStyle(fontSize: 11),
                    ),
                    selected: controller.selectedTypeFilter == EntityType.enumeration,
                    onSelected: (val) {
                      controller.setDatabaseOnly(false);
                      controller.setTypeFilter(val ? EntityType.enumeration : null);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: SizedBox(
              height: 38,
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search entities or fields...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  suffixIcon: controller.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => controller.setSearchQuery(''),
                        )
                      : null,
                  contentPadding: EdgeInsets.zero,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                ),
                onChanged: controller.setSearchQuery,
              ),
            ),
          ),

          // 4. Module Filters
          if (modules.isNotEmpty) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Modules', style: TextStyle(fontSize: 11)),
                    selected: controller.selectedModuleFilter == null,
                    onSelected: (_) => controller.setModuleFilter(null),
                  ),
                  const SizedBox(width: 6),
                  for (final mod in modules) ...[
                    ChoiceChip(
                      label: Text(mod, style: const TextStyle(fontSize: 11)),
                      selected: controller.selectedModuleFilter == mod,
                      onSelected: (selected) =>
                          controller.setModuleFilter(selected ? mod : null),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),

          // 5. Entity List
          Expanded(
            child: visibleTables.isEmpty
                ? Center(
                    child: Text(
                      'No matching entities found',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    itemCount: visibleTables.length,
                    itemBuilder: (context, i) {
                      final table = visibleTables[i];
                      final isSelected = controller.selectedTable == table.tableName;
                      final swatchColor = _parseColor(table.colorHex) ?? colorScheme.primary;

                      return ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        selected: isSelected,
                        selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
                        leading: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: swatchColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                table.className,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            _buildEntityTypeBadge(table.entityType, table.isDatabaseTable),
                          ],
                        ),
                        subtitle: Text(
                          table.isDatabaseTable ? table.tableName : '${table.fields.length} properties',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 10,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: table.isDatabaseTable
                            ? IconButton(
                                icon: const Icon(Icons.table_chart_outlined, size: 16),
                                tooltip: 'Inspect live table data in PostgreSQL',
                                onPressed: () => TableDataInspectorDialog.show(
                                  context,
                                  table: table,
                                  service: service,
                                ),
                              )
                            : null,
                        onTap: () {
                          controller.selectTable(table.tableName);
                          final size = MediaQuery.sizeOf(context);
                          controller.centerOnTable(table.tableName, size);
                        },
                      );
                    },
                  ),
          ),

          // 6. Action buttons (YAML viewer / exporter)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: OutlinedButton.icon(
              onPressed: onOpenYamlViewer,
              icon: const Icon(Icons.code, size: 16),
              label: const Text('YAML Source / Importer'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(36),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),

          // 7. Legend
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              border: Border(
                top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEGEND',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('◆', style: TextStyle(color: Color(0xFFE3B341), fontSize: 12)),
                    const SizedBox(width: 6),
                    Text('id / primary key', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text('⇢', style: TextStyle(color: Color(0xFF5FD4C4), fontSize: 13)),
                    const SizedBox(width: 6),
                    Text('foreign reference', style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Endpoints: | = one side, < = many side (crow\'s foot)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
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
