import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../schema_models.dart';

import '../services/devtools_schema_service.dart';

/// Modal dialog providing live data inspection for a selected Serverpod database table.
class TableDataInspectorDialog extends StatefulWidget {
  final TableNode table;
  final DevToolsSchemaService service;

  const TableDataInspectorDialog({
    super.key,
    required this.table,
    required this.service,
  });

  static Future<void> show(
    BuildContext context, {
    required TableNode table,
    required DevToolsSchemaService service,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => TableDataInspectorDialog(
        table: table,
        service: service,
      ),
    );
  }

  @override
  State<TableDataInspectorDialog> createState() => _TableDataInspectorDialogState();
}

class _TableDataInspectorDialogState extends State<TableDataInspectorDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  TableDataPage? _pageData;

  int _pageSize = 50;
  int _currentPage = 0;
  String? _sortColumn;
  bool _isDescending = false;
  String _filterText = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final page = await widget.service.fetchTableData(
        tableName: widget.table.tableName,
        limit: _pageSize,
        offset: _currentPage * _pageSize,
        orderBy: _sortColumn,
        descending: _isDescending,
      );

      if (mounted) {
        setState(() {
          _pageData = page;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onSort(String columnName) {
    setState(() {
      if (_sortColumn == columnName) {
        _isDescending = !_isDescending;
      } else {
        _sortColumn = columnName;
        _isDescending = false;
      }
      _currentPage = 0;
    });
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: size.width * 0.9,
        height: size.height * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Toolbar
            _buildHeader(context),
            const SizedBox(height: 12),

            // 2. Filter & Controls Bar
            _buildControlsBar(context),
            const SizedBox(height: 12),

            // 3. Main Data Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? _buildErrorView(context)
                      : _buildDataGrid(context),
            ),

            // 4. Pagination Footer
            if (_pageData != null) _buildPaginationFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(Icons.table_chart, color: colorScheme.primary, size: 24),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.table.className,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.table.tableName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            if (_pageData != null)
              Text(
                '${_pageData!.totalRows} total records · Query time: ${_pageData!.executionDurationMs.toStringAsFixed(1)} ms',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh data',
          onPressed: _loadData,
        ),
        IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildControlsBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        // Text filter
        Expanded(
          child: SizedBox(
            height: 38,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filter loaded records...',
                prefixIcon: const Icon(Icons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
              ),
              onChanged: (val) => setState(() => _filterText = val.toLowerCase()),
            ),
          ),
        ),
        const SizedBox(width: 16),

        // Page size dropdown
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Rows:', style: theme.textTheme.bodySmall),
            const SizedBox(width: 6),
            DropdownButton<int>(
              value: _pageSize,
              underline: const SizedBox.shrink(),
              items: const [25, 50, 100, 200]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e')))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _pageSize = val;
                    _currentPage = 0;
                  });
                  _loadData();
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDataGrid(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final page = _pageData;

    if (page == null || page.rows.isEmpty) {
      return Center(
        child: Text(
          'No records found in table "${widget.table.tableName}"',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Filter rows based on search text
    final filteredRows = page.rows.where((row) {
      if (_filterText.isEmpty) return true;
      return row.values.any((val) => val.toString().toLowerCase().contains(_filterText));
    }).toList();

    // Determine column keys from column meta or first row
    final columns = page.columns.isNotEmpty
        ? page.columns.map((c) => c.name).toList()
        : page.rows.first.keys.toList();

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(colorScheme.surfaceContainerHighest),
            border: TableBorder.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 0.8,
              borderRadius: BorderRadius.circular(8),
            ),
            sortColumnIndex: _sortColumn != null ? columns.indexOf(_sortColumn!) : null,
            sortAscending: !_isDescending,
            columns: [
              for (final col in columns)
                DataColumn(
                  label: Text(
                    col,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                  ),
                  onSort: (columnIndex, ascending) => _onSort(col),
                ),
            ],
            rows: [
              for (final row in filteredRows)
                DataRow(
                  cells: [
                    for (final col in columns) _buildCell(context, row[col]),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  DataCell _buildCell(BuildContext context, dynamic value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (value == null) {
      return DataCell(
        Text(
          'null',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.outline,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (value is bool) {
      return DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: value
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.grey.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            value ? 'true' : 'false',
            style: TextStyle(
              color: value ? Colors.green : Colors.grey,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      );
    }

    final strVal = value.toString();

    // UUID detection
    final isUuid = RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(strVal);
    if (isUuid) {
      return DataCell(
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: strVal));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('UUID copied to clipboard!'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          child: Tooltip(
            message: 'Click to copy: $strVal',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${strVal.substring(0, 8)}...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.copy, size: 12, color: colorScheme.primary),
              ],
            ),
          ),
        ),
      );
    }

    return DataCell(
      SelectableText(
        strVal,
        style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
      ),
    );
  }

  Widget _buildPaginationFooter(BuildContext context) {
    final theme = Theme.of(context);
    final page = _pageData!;
    final totalPages = (page.totalRows / _pageSize).ceil();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${page.rows.isEmpty ? 0 : (_currentPage * _pageSize) + 1} - ${mathMin((_currentPage + 1) * _pageSize, page.totalRows)} of ${page.totalRows}',
            style: theme.textTheme.bodySmall,
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _currentPage > 0
                    ? () {
                        setState(() => _currentPage--);
                        _loadData();
                      }
                    : null,
              ),
              Text(
                'Page ${_currentPage + 1} of ${totalPages > 0 ? totalPages : 1}',
                style: theme.textTheme.bodySmall,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: (_currentPage + 1) < totalPages
                    ? () {
                        setState(() => _currentPage++);
                        _loadData();
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 40),
          const SizedBox(height: 10),
          Text(
            'Failed to query table data',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _errorMessage ?? 'Unknown error',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry Query'),
          ),
        ],
      ),
    );
  }

  static int mathMin(int a, int b) => a < b ? a : b;
}
