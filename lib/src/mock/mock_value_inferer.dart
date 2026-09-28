import 'dart:math';

import '../models/field_node.dart';

/// Context-aware fake value inferer for Serverpod schemas.
///
/// Produces realistic synthetic values based on field names, Dart types,
/// and existing primary key pools for foreign key resolution.
class MockValueInferer {
  static final _random = Random(42);

  static const _firstNames = [
    'Elena', 'Marcus', 'Sophia', 'David', 'Maria',
    'Alexander', 'Chloe', 'Liam', 'Zoe', 'Lucas',
  ];

  static const _lastNames = [
    'Rodriguez', 'Vance', 'Chen', 'Smith', 'Patel',
    'Rostova', 'Kim', 'Garcia', 'Mueller', 'Dubois',
  ];

  /// Generates a realistic mock value for a given [field] on [tableName].
  static dynamic inferValue({
    required FieldNode field,
    required String tableName,
    required int rowIndex,
    required Map<String, List<dynamic>> idPool,
  }) {
    final lowerName = field.name.toLowerCase();
    final lowerType = field.type.toLowerCase();

    // 1. Primary Keys
    if (field.isPrimaryKey || lowerName == 'id') {
      if (lowerType.contains('int')) {
        return rowIndex + 1;
      }
      return _generateUuidV4(rowIndex);
    }

    // 2. Foreign Key References
    if (field.relationTargetTable != null) {
      final target = field.relationTargetTable!;
      final parentPool = idPool[target];
      if (parentPool != null && parentPool.isNotEmpty) {
        return parentPool[rowIndex % parentPool.length];
      }
      if (field.isNullable) return null;
      return lowerType.contains('int') ? 1 : _generateUuidV4(rowIndex);
    }

    // 3. UUID / Identifier fields
    if (lowerType.contains('uuid') || lowerName.endsWith('uuid') || lowerName.endsWith('_id') || lowerName.endsWith('id')) {
      // Check if this looks like a foreign key by naming convention (e.g. courseUuid -> course)
      final candidateTable = _inferParentTableFromFieldName(field.name, idPool.keys);
      if (candidateTable != null && idPool.containsKey(candidateTable) && idPool[candidateTable]!.isNotEmpty) {
        final pool = idPool[candidateTable]!;
        return pool[rowIndex % pool.length];
      }
      return lowerType.contains('int') ? rowIndex + 1 : _generateUuidV4(rowIndex);
    }

    // 4. Contact & Identity
    if (lowerName.contains('email')) {
      final first = _firstNames[rowIndex % _firstNames.length].toLowerCase();
      final last = _lastNames[rowIndex % _lastNames.length].toLowerCase();
      return '$first.$last.${rowIndex + 1}@example.com';
    }

    if (lowerName == 'firstname' || lowerName == 'first_name') {
      return _firstNames[rowIndex % _firstNames.length];
    }

    if (lowerName == 'lastname' || lowerName == 'last_name') {
      return _lastNames[rowIndex % _lastNames.length];
    }

    if (lowerName.contains('name') || lowerName.contains('author')) {
      final first = _firstNames[rowIndex % _firstNames.length];
      final last = _lastNames[rowIndex % _lastNames.length];
      return '$first $last';
    }

    if (lowerName.contains('phone')) {
      return '+1 555-01${(rowIndex + 10).toString().padLeft(2, '0')}-${(rowIndex + 100).toString().padLeft(4, '0')}';
    }

    // 5. Content & Text
    if (lowerName.contains('title') || lowerName.contains('header')) {
      final entity = tableName.replaceAll('learnos_', '').replaceAll('_', ' ');
      return 'Mastering ${entity.toUpperCase()} Fundamentals (Cohort ${rowIndex + 1})';
    }

    if (lowerName.contains('subtitle') || lowerName.contains('tagline')) {
      return 'Comprehensive guide and hands-on exercises for practical application.';
    }

    if (lowerName.contains('description') || lowerName.contains('memo') || lowerName.contains('bio') || lowerName.contains('content') || lowerName.contains('notes')) {
      return 'This is realistic synthetic test data generated automatically for $tableName.${field.name}. It provides reliable sample data for unit tests and local dev.';
    }

    if (lowerName.contains('url') || lowerName.contains('image') || lowerName.contains('avatar') || lowerName.contains('icon') || lowerName.contains('photo')) {
      return 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=500&auto=format&fit=crop';
    }

    // 6. Enums & Statuses
    if (lowerName.contains('status')) {
      const statuses = ['active', 'pending', 'completed', 'in_review'];
      return statuses[rowIndex % statuses.length];
    }

    if (lowerName.contains('role')) {
      const roles = ['teacher', 'student', 'admin', 'lead'];
      return roles[rowIndex % roles.length];
    }

    if (lowerName.contains('cefr') || lowerName.contains('level')) {
      const levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
      return levels[rowIndex % levels.length];
    }

    // 7. Numeric & Pricing
    if (lowerName.contains('price') || lowerName.contains('amount') || lowerName.contains('cost') || lowerName.contains('fee')) {
      return (49.0 + (rowIndex * 25.0));
    }

    if (lowerName.contains('score') || lowerName.contains('grade')) {
      return 75 + (rowIndex % 25);
    }

    if (lowerName.contains('count') || lowerName.contains('order') || lowerName.contains('index') || lowerName.contains('position')) {
      return rowIndex;
    }

    // 8. Timestamps
    if (lowerType.contains('datetime') || lowerName.contains('date') || lowerName.endsWith('at')) {
      final daysAgo = (rowIndex * 3) + 1;
      return DateTime.now().subtract(Duration(days: daysAgo)).toUtc().toIso8601String();
    }

    // 9. Standard Types
    if (lowerType.contains('bool')) {
      return rowIndex % 5 != 0; // 80% true
    }

    if (lowerType.contains('double')) {
      return ((rowIndex + 1) * 1.5).roundToDouble();
    }

    if (lowerType.contains('int')) {
      return rowIndex + 1;
    }

    if (lowerType.contains('list')) {
      return <dynamic>['Item A', 'Item B'];
    }

    if (lowerType.contains('map')) {
      return <String, dynamic>{'key': 'value_${rowIndex + 1}'};
    }

    return 'Sample ${field.name} ${rowIndex + 1}';
  }

  /// Generates a valid RFC 4122 v4 UUID string based on an index seed.
  static String _generateUuidV4(int seed) {
    final bytes = List<int>.generate(16, (i) => (seed * 31 + i * 17 + _random.nextInt(256)) & 0xFF);
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // Version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // Variant RFC 4122

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static String? _inferParentTableFromFieldName(String fieldName, Iterable<String> existingTables) {
    var base = fieldName.replaceAll(RegExp(r'(Uuid|Id|_uuid|_id)$', caseSensitive: false), '').toLowerCase();
    for (final table in existingTables) {
      final cleanTable = table.replaceAll(RegExp(r'^(learnos_|tbl_|app_)', caseSensitive: false), '').toLowerCase();
      if (cleanTable == base || table.toLowerCase() == base) {
        return table;
      }
    }
    return null;
  }
}
