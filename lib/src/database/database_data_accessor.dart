import 'dart:async';
import 'package:serverpod/serverpod.dart';

import '../models/table_data_page.dart';

/// Provides safe, paginated database queries for inspecting table records in Serverpod.
class DatabaseDataAccessor {
  final Database _database;

  const DatabaseDataAccessor(this._database);

  /// Access to underlying Serverpod Database instance.
  Database get database => _database;

  /// Fetches paginated table data (alias for [queryTableData]).
  Future<TableDataPage> fetchTableData({
    required String tableName,
    int limit = 50,
    int offset = 0,
    String? sortBy,
    bool sortAscending = true,
    String? searchQuery,
  }) => queryTableData(
    tableName: tableName,
    limit: limit,
    offset: offset,
    orderBy: sortBy,
    descending: !sortAscending,
  );

  /// Queries row counts across tables in the database.
  Future<Map<String, int>> fetchDatabaseStats() async {
    final stats = <String, int>{};
    try {
      final results = await _database.unsafeQuery(
        "SELECT relname, n_live_tup FROM pg_stat_user_tables;",
      );
      for (final row in results) {
        if (row.length >= 2) {
          final tableName = row[0]?.toString() ?? '';
          final countVal = row[1];
          final count = countVal is int
              ? countVal
              : int.tryParse(countVal?.toString() ?? '0') ?? 0;
          if (tableName.isNotEmpty) {
            stats[tableName] = count;
          }
        }
      }
    } catch (_) {}
    return stats;
  }

  /// Safely queries rows from [tableName] with pagination and optional sorting.
  ///
  /// Strict validation is performed to prevent SQL injection.
  Future<TableDataPage> queryTableData({
    required String tableName,
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool descending = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    // 1. Strict table name validation (only alphanumeric + underscore)
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(tableName)) {
      throw ArgumentError('Invalid table name: "$tableName"');
    }

    // Sanitize pagination limits
    final safeLimit = limit.clamp(1, 500);
    final safeOffset = offset < 0 ? 0 : offset;

    // 2. Query total count
    var totalRows = 0;
    try {
      final countResult = await _database.unsafeQuery(
        'SELECT COUNT(*) FROM "$tableName"',
      );
      if (countResult.isNotEmpty && countResult.first.isNotEmpty) {
        final rawCount = countResult.first.first;
        if (rawCount is int) {
          totalRows = rawCount;
        } else if (rawCount is BigInt) {
          totalRows = rawCount.toInt();
        } else if (rawCount != null) {
          totalRows = int.tryParse(rawCount.toString()) ?? 0;
        }
      }
    } catch (_) {
      // If table doesn't exist yet in the database, return empty page gracefully
      totalRows = 0;
    }

    // 3. Validate orderBy column if provided
    String orderClause = '';
    if (orderBy != null && RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(orderBy)) {
      final direction = descending ? 'DESC' : 'ASC';
      orderClause = 'ORDER BY "$orderBy" $direction';
    } else {
      orderClause = 'ORDER BY 1 ASC'; // default to first column
    }

    // 4. Query paginated records
    final rowsList = <Map<String, dynamic>>[];
    final columnsMeta = <TableColumnMeta>[];

    try {
      final query = 'SELECT * FROM "$tableName" $orderClause LIMIT $safeLimit OFFSET $safeOffset';
      final results = await _database.unsafeQuery(query);

      // Extract rows and column metadata from results
      for (final row in results) {
        final rowMap = <String, dynamic>{};
        final description = row.toColumnMap();

        description.forEach((columnName, value) {
          // Serialize special objects to JSON-friendly primitives & mask secrets
          rowMap[columnName] = _sanitizeCellValue(columnName, value);
        });

        rowsList.add(rowMap);
      }

      // Populate column definitions from first row if available
      if (rowsList.isNotEmpty) {
        final sampleRow = rowsList.first;
        sampleRow.forEach((colName, val) {
          columnsMeta.add(
            TableColumnMeta(
              name: colName,
              type: _inferDisplayType(val),
              isNullable: true,
            ),
          );
        });
      }
    } catch (e) {
      // Return empty results with error note if query fails (e.g. table not migrated yet)
    }

    stopwatch.stop();

    return TableDataPage(
      tableName: tableName,
      columns: columnsMeta,
      rows: rowsList,
      totalRows: totalRows,
      page: (safeOffset / safeLimit).floor(),
      pageSize: safeLimit,
      executionDurationMs: stopwatch.elapsedMicroseconds / 1000.0,
    );
  }

  /// Checks whether a column name represents a sensitive credential, secret, or hash.
  static bool isSensitiveColumn(String columnName) {
    final clean = columnName.toLowerCase();
    // Do not mask foreign key identifiers (e.g. token_id, password_reset_id)
    if (clean.endsWith('_id') || clean.endsWith('id')) {
      return false;
    }
    final stripped = clean.replaceAll('_', '');
    return stripped.contains('password') ||
        stripped.contains('hash') ||
        stripped.contains('secret') ||
        stripped.contains('privatekey') ||
        stripped.contains('token') ||
        stripped.contains('verificationcode') ||
        stripped.contains('apikey') ||
        stripped.contains('authtoken');
  }

  /// Converts complex PostgreSQL driver values into JSON-encodable types,
  /// automatically masking sensitive columns (passwords, secrets, hashes).
  static dynamic _sanitizeCellValue(String columnName, dynamic value) {
    if (value == null) return null;
    if (isSensitiveColumn(columnName)) {
      return '••••••••';
    }
    if (value is num || value is bool || value is String) return value;
    if (value is DateTime) return value.toIso8601String();
    if (value is UuidValue) return value.uuid;
    if (value is BigInt) return value.toInt();
    if (value is List) {
      return value.map((v) => _sanitizeCellValue(columnName, v)).toList();
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _sanitizeCellValue(k.toString(), v)));
    }
    return value.toString();
  }

  /// Infers a friendly display type from the runtime value.
  static String _inferDisplayType(dynamic val) {
    if (val == null) return 'dynamic';
    if (val is int) return 'int';
    if (val is double) return 'double';
    if (val is bool) return 'bool';
    if (val is String) {
      if (RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(val)) return 'UuidValue';
      return 'String';
    }
    if (val is List) return 'List';
    if (val is Map) return 'Map';
    return val.runtimeType.toString();
  }
}
