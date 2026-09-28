import 'dart:io';
import 'package:test/test.dart';
import 'package:serverpod_dev_tools/serverpod_dev_tools.dart';

File _findHttpFile(String relativePath) {
  var file = File(relativePath);
  if (file.existsSync()) return file;
  file = File('../learn_os/$relativePath');
  if (file.existsSync()) return file;
  file = File('../../$relativePath');
  if (file.existsSync()) return file;
  return File(relativePath);
}

void main() {
  group('HttpFileParser', () {
    test('parses real studio_server/http/homework.http accurately', () {
      final file = _findHttpFile('apps/studio/studio_server/http/homework.http');
      expect(file.existsSync(), isTrue);

      final collection = HttpFileParser.parseFile(file);
      expect(collection, isNotNull);
      expect(collection!.fileName, equals('homework.http'));
      expect(collection.variables.length, greaterThanOrEqualTo(2));

      final baseVar = collection.variables.firstWhere((v) => v.name == 'baseUrl');
      expect(baseVar.value, equals('http://localhost:8080'));

      expect(collection.requests.length, greaterThanOrEqualTo(3));

      // Request 1: Get Homework Submissions (All)
      final req1 = collection.requests[0];
      expect(req1.method, equals('POST'));
      expect(req1.url, contains('homework/getSubmissions'));
      expect(req1.endpoint, equals('homework'));
      expect(req1.methodName, equals('getSubmissions'));

      // Request 2: Get Pending Submissions Filter
      final req2 = collection.requests[1];
      expect(req2.headers['Content-Type'], equals('application/json'));
      expect(req2.body, contains('"status": "pending"'));

      // Request 3: Grade Homework Submission
      final req3 = collection.requests[2];
      expect(req3.methodName, equals('gradeSubmission'));
    });

    test('parses real studio_server/http/course.http accurately', () {
      final file = _findHttpFile('apps/studio/studio_server/http/course.http');
      expect(file.existsSync(), isTrue);

      final collection = HttpFileParser.parseFile(file);
      expect(collection, isNotNull);
      expect(collection!.requests.length, greaterThanOrEqualTo(4));
    });
  });

  group('HttpFileWriter', () {
    test('saves and formats new request into .http file format', () {
      final tempDir = Directory.systemTemp.createTempSync('http_test');
      try {
        const item = HttpRequestItem(
          id: 'test_1',
          title: 'Test Create Item',
          method: 'POST',
          url: '{{baseUrl}}/test/create',
          headers: {'Content-Type': 'application/json'},
          body: '{"name": "Flutter Unit"}',
          endpoint: 'test',
          methodName: 'create',
        );

        final saved = HttpFileWriter.saveRequestToFile(
          httpDirectory: tempDir,
          fileName: 'custom_test.http',
          request: item,
        );

        expect(saved.existsSync(), isTrue);
        final content = saved.readAsStringSync();
        expect(content, contains('### Test Create Item'));
        expect(content, contains('POST {{baseUrl}}/test/create'));
        expect(content, contains('"name": "Flutter Unit"'));

        // Parse back and verify round-trip
        final parsed = HttpFileParser.parseFile(saved);
        expect(parsed, isNotNull);
        expect(parsed!.requests.length, equals(1));
        expect(parsed.requests.first.methodName, equals('create'));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('TopologicalSorter', () {
    test('orders parent tables before dependent child tables', () {
      const parent = TableNode(
        id: 'school',
        className: 'School',
        tableName: 'school',
        fields: [
          FieldNode(name: 'id', type: 'int', isPrimaryKey: true),
        ],
      );

      const child = TableNode(
        id: 'course',
        className: 'Course',
        tableName: 'course',
        fields: [
          FieldNode(name: 'id', type: 'int', isPrimaryKey: true),
          FieldNode(
            name: 'schoolId',
            type: 'int',
            relationTargetTable: 'school',
          ),
        ],
      );

      const grandchild = TableNode(
        id: 'module',
        className: 'Module',
        tableName: 'module',
        fields: [
          FieldNode(name: 'id', type: 'int', isPrimaryKey: true),
          FieldNode(
            name: 'courseId',
            type: 'int',
            relationTargetTable: 'course',
          ),
        ],
      );

      // Pass in reverse order: grandchild, child, parent
      final graph = SchemaGraph(tables: [grandchild, child, parent]);
      final sorted = TopologicalSorter.sortTables(graph);

      final names = sorted.map((t) => t.tableName).toList();
      expect(names.indexOf('school'), lessThan(names.indexOf('course')));
      expect(names.indexOf('course'), lessThan(names.indexOf('module')));
    });
  });

  group('MockValueInferer & MockDataGenerator', () {
    test('generates valid RFC 4122 v4 UUIDs and realistic mock data', () {
      const courseTable = TableNode(
        id: 'course',
        className: 'Course',
        tableName: 'learnos_course',
        fields: [
          FieldNode(name: 'id', type: 'int', isPrimaryKey: true),
          FieldNode(name: 'uuid', type: 'String'),
          FieldNode(name: 'title', type: 'String'),
          FieldNode(name: 'monthlyPrice', type: 'double'),
          FieldNode(name: 'cefrLevel', type: 'String'),
          FieldNode(name: 'createdAt', type: 'DateTime'),
          FieldNode(name: 'isActive', type: 'bool'),
        ],
      );

      final graph = SchemaGraph(tables: [courseTable]);
      final result = MockDataGenerator.generate(graph: graph, rowsPerTable: 3);

      final rows = result.rows['learnos_course']!;
      expect(rows.length, equals(3));

      for (var i = 0; i < 3; i++) {
        final row = rows[i];
        expect(row['id'], equals(i + 1));

        // Validate RFC 4122 v4 UUID
        final uuid = row['uuid'] as String;
        final uuidRegex = RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          caseSensitive: false,
        );
        expect(uuidRegex.hasMatch(uuid), isTrue);

        expect(row['title'], contains('Mastering'));
        expect(row['monthlyPrice'], greaterThan(0));
        expect(row['createdAt'], isNotEmpty);
      }

      // Check SQL Script generation
      final sql = result.toSqlScript();
      expect(sql, contains('BEGIN;'));
      expect(sql, contains('INSERT INTO "learnos_course"'));
      expect(sql, contains('COMMIT;'));

      // Check JSON Fixtures generation
      final jsonFixtures = result.toJsonFixtures();
      expect(jsonFixtures, contains('"learnos_course"'));

      // Check Dart Script generation
      final dartScript = result.toDartSeedScript();
      expect(dartScript, contains('Future<void> seedDatabase(Session session) async'));
    });

    test('resolveHttpDirectory and recursive scan discovers all .http files', () {
      final resolvedDir = HttpFileParser.resolveHttpDirectory(Directory('http'));
      expect(resolvedDir.existsSync(), isTrue);

      final collections = HttpFileParser.scanDirectory(resolvedDir);
      expect(collections.length, greaterThanOrEqualTo(9));

      final totalRequests = collections.fold<int>(0, (sum, c) => sum + c.requests.length);
      expect(totalRequests, greaterThanOrEqualTo(40));

      final fileNames = collections.map((c) => c.fileName).toSet();
      expect(fileNames, containsAll([
        'analytics.http',
        'branding.http',
        'course.http',
        'dashboard.http',
        'homework.http',
        'live_session.http',
        'settings.http',
        'student.http',
        'student_portal.http',
      ]));
    });
  });
}

