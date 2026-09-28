import 'dart:io';
import 'package:test/test.dart';
import 'package:serverpod_dev_tools/serverpod_dev_tools.dart';

Directory _resolveHttpDir() {
  var dir = Directory('apps/studio/studio_server/http');
  if (dir.existsSync()) return dir;
  dir = Directory('../learn_os/apps/studio/studio_server/http');
  if (dir.existsSync()) return dir;
  return Directory('apps/studio/studio_server/http');
}

void main() {
  group('HTTP Files Scan & Parse Tests', () {
    test('HttpFileParser discovers all real .http files in studio_server/http', () {
      final dir = _resolveHttpDir();
      final collections = HttpFileParser.scanDirectory(dir);

      expect(collections, isNotEmpty);
      final fileNames = collections.map((c) => c.fileName).toSet();

      expect(fileNames, contains('course.http'));
      expect(fileNames, contains('dashboard.http'));
      expect(fileNames, contains('homework.http'));
      expect(fileNames, contains('settings.http'));
      expect(fileNames, contains('student.http'));
      expect(fileNames, contains('student_portal.http'));
    });

    test('HttpFileParser parses variables and endpoints from course.http', () {
      final dir = _resolveHttpDir();
      final collections = HttpFileParser.scanDirectory(dir);
      final courseCollection = collections.firstWhere((c) => c.fileName == 'course.http');

      expect(courseCollection.variables, isNotEmpty);
      expect(courseCollection.variables.any((v) => v.name == 'baseUrl'), isTrue);

      expect(courseCollection.requests, isNotEmpty);
      final firstRequest = courseCollection.requests.first;
      expect(firstRequest.method, equals('POST'));
      expect(firstRequest.endpoint, equals('course'));
      expect(firstRequest.methodName, isNotEmpty);
    });

    test('HttpFileParser handles empty directory gracefully', () {
      final emptyDir = Directory.systemTemp.createTempSync('http_test_');
      try {
        final collections = HttpFileParser.scanDirectory(emptyDir);
        expect(collections, isEmpty);
      } finally {
        emptyDir.deleteSync(recursive: true);
      }
    });
  });
}
