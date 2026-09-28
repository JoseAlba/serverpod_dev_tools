/// Column metadata description in a table query result.
class TableColumnMeta {
  final String name;
  final String type;
  final bool isNullable;

  const TableColumnMeta({
    required this.name,
    required this.type,
    this.isNullable = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'isNullable': isNullable,
  };

  factory TableColumnMeta.fromJson(Map<String, dynamic> json) => TableColumnMeta(
    name: json['name'] as String,
    type: json['type'] as String,
    isNullable: json['isNullable'] as bool? ?? false,
  );
}

/// Represents a paginated snapshot of live table data returned from the Serverpod database.
class TableDataPage {
  /// Name of the queried database table.
  final String tableName;

  /// Ordered list of column metadata headers.
  final List<TableColumnMeta> columns;

  /// List of row records, keyed by column name.
  final List<Map<String, dynamic>> rows;

  /// Total count of rows in the table.
  final int totalRows;

  /// 0-based page index.
  final int page;

  /// Requested page limit.
  final int pageSize;

  /// Query execution duration in milliseconds.
  final double executionDurationMs;

  const TableDataPage({
    required this.tableName,
    required this.columns,
    required this.rows,
    required this.totalRows,
    required this.page,
    required this.pageSize,
    required this.executionDurationMs,
  });

  Map<String, dynamic> toJson() => {
    'tableName': tableName,
    'columns': columns.map((c) => c.toJson()).toList(),
    'rows': rows,
    'totalRows': totalRows,
    'page': page,
    'pageSize': pageSize,
    'executionDurationMs': executionDurationMs,
  };

  factory TableDataPage.fromJson(Map<String, dynamic> json) => TableDataPage(
    tableName: json['tableName'] as String,
    columns: (json['columns'] as List<dynamic>?)
            ?.map((c) => TableColumnMeta.fromJson(c as Map<String, dynamic>))
            .toList() ??
        const [],
    rows: (json['rows'] as List<dynamic>?)
            ?.map((r) => Map<String, dynamic>.from(r as Map))
            .toList() ??
        const [],
    totalRows: json['totalRows'] as int? ?? 0,
    page: json['page'] as int? ?? 0,
    pageSize: json['pageSize'] as int? ?? 50,
    executionDurationMs: (json['executionDurationMs'] as num?)?.toDouble() ?? 0.0,
  );
}
