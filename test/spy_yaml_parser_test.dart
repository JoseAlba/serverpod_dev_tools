import 'dart:io';
import 'package:test/test.dart';
import 'package:serverpod_dev_tools/src/models/table_node.dart';
import 'package:serverpod_dev_tools/src/parser/spy_yaml_parser.dart';
import 'package:serverpod_dev_tools/src/parser/spy_yaml_scanner.dart';

void main() {
  group('SpyYamlParser', () {
    final parser = SpyYamlParser();

    test('parses single model with table, fields, and indexes', () {
      const yaml = '''
### Top-level course curriculum entity containing modules and lessons.
class: Course
table: learnos_course
fields:
  uuid: UuidValue
  title: String
  instructorBio: String?
  price: double
  isPublished: bool
  tags: List<String>
indexes:
  course_uuid_idx:
    fields: uuid
    unique: true
''';

      final tables = parser.parseYamlString(yaml, moduleName: 'courses');
      expect(tables.length, equals(1));

      final course = tables.first;
      expect(course.className, equals('Course'));
      expect(course.tableName, equals('learnos_course'));
      expect(course.module, equals('courses'));
      expect(course.description, contains('Top-level course curriculum'));

      // Check auto-injected primary key id
      expect(course.fields.first.name, equals('id'));
      expect(course.fields.first.isPrimaryKey, isTrue);

      // Check fields
      final uuidField = course.fields.firstWhere((f) => f.name == 'uuid');
      expect(uuidField.type, equals('UuidValue'));
      expect(uuidField.isNullable, isFalse);

      final bioField = course.fields.firstWhere((f) => f.name == 'instructorBio');
      expect(bioField.type, equals('String'));
      expect(bioField.isNullable, isTrue);

      final tagsField = course.fields.firstWhere((f) => f.name == 'tags');
      expect(tagsField.type, equals('List<String>'));
      expect(tagsField.isList, isTrue);

      // Check indexes
      expect(course.indexes.length, equals(1));
      expect(course.indexes.first.name, equals('course_uuid_idx'));
      expect(course.indexes.first.fields, equals(['uuid']));
      expect(course.indexes.first.isUnique, isTrue);
    });

    test('parses explicit relation syntax from Claude sample', () {
      const yaml = '''
class: Company
table: company
fields:
  name: String
---
class: Employee
table: employee
fields:
  name: String
  company: Company?, relation(parent=company)
''';

      final tables = parser.parseYamlString(yaml);
      expect(tables.length, equals(2));

      final employee = tables.firstWhere((t) => t.className == 'Employee');
      final companyField = employee.fields.firstWhere((f) => f.name == 'company');
      expect(companyField.isForeignKey, isTrue);
      expect(companyField.foreignKeyTargetTable, equals('company'));
    });
  });

  group('RelationResolver & Inferred Keys', () {
    test('resolves inferred foreign keys (e.g. courseUuid) and 1:N cardinality', () {
      const yaml = '''
class: Course
table: learnos_course
fields:
  uuid: UuidValue
indexes:
  course_uuid_idx:
    fields: uuid
    unique: true
---
class: CourseModule
table: learnos_course_module
fields:
  uuid: UuidValue
  courseUuid: UuidValue
  title: String
indexes:
  module_uuid_idx:
    fields: uuid
    unique: true
''';

      final scanner = SpyYamlScanner();
      final graph = scanner.parseString(yaml);

      expect(graph.tables.length, equals(2));
      expect(graph.relations.length, equals(1));

      final rel = graph.relations.first;
      expect(rel.fromTable, equals('learnos_course_module'));
      expect(rel.fromField, equals('courseUuid'));
      expect(rel.toTable, equals('learnos_course'));
      expect(rel.toField, equals('uuid'));
      expect(rel.cardinality, equals('1:N'));
    });

    test('resolves 1:1 cardinality when foreign key has unique index', () {
      const yaml = '''
class: Student
table: student
fields:
  uuid: UuidValue
---
class: StudentProfile
table: student_profile
fields:
  uuid: UuidValue
  studentUuid: UuidValue
indexes:
  student_profile_unique_idx:
    fields: studentUuid
    unique: true
''';

      final scanner = SpyYamlScanner();
      final graph = scanner.parseString(yaml);

      expect(graph.relations.length, equals(1));
      final rel = graph.relations.first;
      expect(rel.cardinality, equals('1:1'));
    });
  });

  group('Real Project Model Directory Scan', () {
    test('successfully scans actual studio_server models with entity types', () async {
      var targetDir = Directory('/Users/josealba/Development/learn_os/apps/studio/studio_server/lib/src/models');
      if (!targetDir.existsSync()) {
        targetDir = Directory('../learn_os/apps/studio/studio_server/lib/src/models');
      }
      final modelsDir = SpyYamlScanner.resolveModelsDirectory(targetDir);
      if (!modelsDir.existsSync()) return;

      final scanner = SpyYamlScanner();
      final graph = await scanner.scanDirectory(modelsDir);

      expect(graph.tables, isNotEmpty);
      expect(graph.tables.length, greaterThanOrEqualTo(50));
      expect(graph.relations, isNotEmpty);

      // Verify physical PostgreSQL tables are distinguished from DTOs and enums
      final dbTables = graph.tables.where((t) => t.isDatabaseTable).toList();
      final nonDbEntities = graph.tables.where((t) => !t.isDatabaseTable).toList();

      expect(dbTables.length, equals(21));
      expect(nonDbEntities.length, greaterThanOrEqualTo(29));

      // Verify learnos_course and learnos_course_module are connected
      final courseTable = graph.tables.firstWhere((t) => t.tableName == 'learnos_course');
      expect(courseTable.isDatabaseTable, isTrue);
      expect(courseTable.entityType, equals(EntityType.table));

      final hasCourseModuleRel = graph.relations.any(
        (r) => r.fromTable == 'learnos_course_module' && r.toTable == 'learnos_course',
      );
      expect(hasCourseModuleRel, isTrue);
    });
  });
}
