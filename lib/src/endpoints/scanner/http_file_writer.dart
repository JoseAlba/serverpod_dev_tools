import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/http_request_item.dart';

/// Formats and persists [HttpRequestItem]s into `.http` files on disk.
class HttpFileWriter {
  /// Appends or writes a [HttpRequestItem] to a `.http` file.
  ///
  /// If the file does not exist, it will be initialized with a standard header
  /// and `@baseUrl = http://localhost:8080`.
  static File saveRequestToFile({
    required Directory httpDirectory,
    required String fileName,
    required HttpRequestItem request,
    String? baseUrl,
  }) {
    if (!httpDirectory.existsSync()) {
      httpDirectory.createSync(recursive: true);
    }

    final targetName = fileName.endsWith('.http') ? fileName : '$fileName.http';
    final file = File(p.join(httpDirectory.path, targetName));

    final sb = StringBuffer();

    if (!file.existsSync()) {
      // Create new file with header & baseUrl variable
      sb.writeln('### ${p.basenameWithoutExtension(targetName).toUpperCase()} Endpoint HTTP Requests');
      sb.writeln('@baseUrl = ${baseUrl ?? 'http://localhost:8080'}');
      sb.writeln();
    } else {
      sb.write(file.readAsStringSync());
      if (!sb.toString().endsWith('\n\n') && !sb.toString().endsWith('\n')) {
        sb.writeln();
      }
      if (!sb.toString().endsWith('\n\n')) {
        sb.writeln();
      }
    }

    // Append formatted request block
    sb.writeln('### ${request.title}');
    sb.writeln('${request.method} ${request.url}');
    for (final entry in request.headers.entries) {
      sb.writeln('${entry.key}: ${entry.value}');
    }

    if (request.body != null && request.body!.isNotEmpty) {
      if (!request.headers.containsKey('Content-Type')) {
        sb.writeln('Content-Type: application/json');
      }
      sb.writeln();
      sb.writeln(request.body);
    }

    sb.writeln();
    file.writeAsStringSync(sb.toString());
    return file;
  }
}
