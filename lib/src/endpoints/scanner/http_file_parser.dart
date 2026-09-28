import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/http_request_item.dart';

/// Parses `.http` / `.rest` files adhering to the standard RFC 7230 / VS Code REST Client format.
class HttpFileParser {
  /// Resolves the most appropriate `.http` directory by checking candidate locations.
  static Directory resolveHttpDirectory(Directory? initial) {
    if (initial != null && initial.existsSync()) return initial;

    final candidates = [
      ?initial,
      Directory('http'),
      Directory('studio_server/http'),
      Directory('../studio_server/http'),
      Directory('../http'),
      Directory('../../http'),
      Directory('apps/studio/studio_server/http'),
      Directory('../../apps/studio/studio_server/http'),
      Directory('../learn_os/apps/studio/studio_server/http'),
    ];

    for (final candidate in candidates) {
      if (candidate.existsSync()) {
        final hasHttpFiles = candidate
            .listSync(recursive: true)
            .whereType<File>()
            .any((f) => f.path.endsWith('.http') || f.path.endsWith('.rest'));
        if (hasHttpFiles) return candidate;
      }
    }

    // Check immediate subdirectories (e.g. apps/studio -> studio_server/http)
    try {
      for (final entity in Directory.current.listSync(recursive: false)) {
        if (entity is Directory) {
          final subHttp = Directory(p.join(entity.path, 'http'));
          if (subHttp.existsSync()) return subHttp;
        }
      }
    } catch (_) {}

    return initial ?? Directory('http');
  }

  /// Scans a directory for all `.http` files and parses them into [HttpFileCollection]s.
  static List<HttpFileCollection> scanDirectory(Directory dir) {
    final targetDir = resolveHttpDirectory(dir);
    if (!targetDir.existsSync()) return [];

    final collections = <HttpFileCollection>[];
    final files = targetDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.http') || f.path.endsWith('.rest'))
        .toList();

    // Sort files alphabetically
    files.sort((a, b) => a.path.compareTo(b.path));

    for (final file in files) {
      final collection = parseFile(file);
      if (collection != null) {
        collections.add(collection);
      }
    }

    return collections;
  }

  /// Parses a single `.http` file.
  static HttpFileCollection? parseFile(File file) {
    if (!file.existsSync()) return null;

    final content = file.readAsStringSync();
    return parseContent(
      content: content,
      fileName: p.basename(file.path),
      filePath: file.path,
    );
  }

  /// Parses raw string content of a `.http` file.
  static HttpFileCollection parseContent({
    required String content,
    required String fileName,
    required String filePath,
  }) {
    final lines = content.split('\n');
    final variables = <HttpVariable>[];
    final requests = <HttpRequestItem>[];

    String? fileDescription;
    final variableMap = <String, String>{};

    var i = 0;
    while (i < lines.length) {
      final line = lines[i].trim();

      // Check for file-level description or header
      if (line.startsWith('###') && fileDescription == null && variables.isEmpty && requests.isEmpty) {
        final titleCandidate = line.substring(3).trim();
        // If the next non-empty line is a variable declaration, this first ### is a file title
        var j = i + 1;
        while (j < lines.length && lines[j].trim().isEmpty) {
          j++;
        }
        if (j < lines.length && lines[j].trim().startsWith('@')) {
          fileDescription = titleCandidate;
          i = j;
          continue;
        }
      }

      // Check for variables: @varName = value
      if (line.startsWith('@')) {
        final eqIdx = line.indexOf('=');
        if (eqIdx != -1) {
          final varName = line.substring(1, eqIdx).trim();
          final varValue = line.substring(eqIdx + 1).trim();
          final variable = HttpVariable(name: varName, value: varValue);
          variables.add(variable);
          variableMap[varName] = varValue;
        }
        i++;
        continue;
      }

      // Check for request block: starts with ### or METHOD
      if (line.startsWith('###') || _isHttpMethod(line)) {
        String title = 'Request ${requests.length + 1}';
        if (line.startsWith('###')) {
          title = line.substring(3).trim();
          i++;
        }

        // Skip blank lines to reach method line
        while (i < lines.length && lines[i].trim().isEmpty) {
          i++;
        }
        if (i >= lines.length) break;

        final methodLine = lines[i].trim();
        final parts = methodLine.split(RegExp(r'\s+'));
        if (parts.isEmpty || !_isHttpMethod(parts[0])) {
          i++;
          continue;
        }

        final method = parts[0].toUpperCase();
        final url = parts.length > 1 ? parts[1] : '';
        i++;

        // Read headers
        final headers = <String, String>{};
        while (i < lines.length) {
          final hLine = lines[i].trim();
          if (hLine.isEmpty || hLine.startsWith('###')) break;
          final colonIdx = hLine.indexOf(':');
          if (colonIdx != -1) {
            final hName = hLine.substring(0, colonIdx).trim();
            final hVal = hLine.substring(colonIdx + 1).trim();
            headers[hName] = hVal;
          }
          i++;
        }

        // Skip blank lines to reach body
        while (i < lines.length && lines[i].trim().isEmpty) {
          i++;
        }

        // Read body until next ### or end of file
        final bodyLines = <String>[];
        while (i < lines.length && !lines[i].trim().startsWith('###')) {
          bodyLines.add(lines[i]);
          i++;
        }

        final body = bodyLines.join('\n').trim();

        // Extract endpoint & method from URL path (e.g. {{baseUrl}}/homework/gradeSubmission)
        String? endpoint;
        String? methodName;
        final cleanUrl = _resolveVariables(url, variableMap);
        final uri = Uri.tryParse(cleanUrl);
        if (uri != null && uri.pathSegments.isNotEmpty) {
          if (uri.pathSegments.length >= 2) {
            endpoint = uri.pathSegments[uri.pathSegments.length - 2];
            methodName = uri.pathSegments.last;
          } else {
            endpoint = uri.pathSegments.last;
          }
        }

        final reqId = '${p.basenameWithoutExtension(fileName)}_${requests.length + 1}';
        requests.add(
          HttpRequestItem(
            id: reqId,
            title: title.isNotEmpty ? title : 'Request ${requests.length + 1}',
            method: method,
            url: url,
            headers: headers,
            body: body.isNotEmpty ? body : null,
            endpoint: endpoint,
            methodName: methodName,
          ),
        );
        continue;
      }

      i++;
    }

    return HttpFileCollection(
      fileName: fileName,
      filePath: filePath,
      description: fileDescription,
      variables: variables,
      requests: requests,
    );
  }

  static bool _isHttpMethod(String text) {
    final firstWord = text.split(RegExp(r'\s+')).first.toUpperCase();
    return const {'GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'}
        .contains(firstWord);
  }

  static String _resolveVariables(String text, Map<String, String> variables) {
    var result = text;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }
}
