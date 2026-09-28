import 'dart:convert';
import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../models/http_request_item.dart';

/// Executes calls against Serverpod endpoints and records execution metrics.
class EndpointCaller {
  final Serverpod pod;

  const EndpointCaller(this.pod);

  /// Invokes an endpoint method over the local Serverpod HTTP RPC protocol.
  Future<HttpInvocationResult> invoke({
    required String endpoint,
    required String method,
    Map<String, dynamic> parameters = const {},
    Map<String, String> headers = const {},
    String? authToken,
    String? baseUrl,
  }) async {
    final client = HttpClient();
    final stopwatch = Stopwatch()..start();

    final port = pod.config.apiServer.port;
    final host = pod.config.apiServer.publicHost.isNotEmpty
        ? pod.config.apiServer.publicHost
        : 'localhost';

    final effectiveBase = baseUrl?.isNotEmpty == true
        ? baseUrl!
        : 'http://$host:$port';

    final url = Uri.parse('$effectiveBase/$endpoint/$method');

    try {
      final request = await client.postUrl(url);

      // Set standard Serverpod JSON headers
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json; charset=utf-8');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      if (authToken != null && authToken.isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      }

      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }

      final payloadJson = jsonEncode(parameters);
      request.write(payloadJson);

      final response = await request.close();
      stopwatch.stop();

      final responseBody = await response.transform(utf8.decoder).join();
      final respHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        respHeaders[name] = values.join('; ');
      });

      dynamic parsedBody;
      try {
        parsedBody = jsonDecode(responseBody);
      } catch (_) {
        parsedBody = responseBody;
      }

      return HttpInvocationResult(
        statusCode: response.statusCode,
        statusText: response.reasonPhrase,
        durationMs: stopwatch.elapsedMilliseconds,
        headers: respHeaders,
        body: parsedBody,
        rawResponse: responseBody,
      );
    } catch (e, stack) {
      stopwatch.stop();
      return HttpInvocationResult(
        statusCode: 500,
        statusText: 'Internal Error',
        durationMs: stopwatch.elapsedMilliseconds,
        error: '$e\n$stack',
        rawResponse: e.toString(),
      );
    } finally {
      client.close();
    }
  }

  /// Invokes a raw [HttpRequestItem] directly (e.g. from a `.http` file).
  Future<HttpInvocationResult> invokeRequestItem(
    HttpRequestItem item, {
    Map<String, String> variableMap = const {},
    String? authToken,
  }) async {
    final client = HttpClient();
    final stopwatch = Stopwatch()..start();

    final resolvedUrl = _resolveVariables(item.url, variableMap);
    final url = Uri.parse(resolvedUrl);

    try {
      final request = await client.openUrl(item.method, url);

      for (final entry in item.headers.entries) {
        request.headers.set(entry.key, _resolveVariables(entry.value, variableMap));
      }

      if (authToken != null && authToken.isNotEmpty && !item.headers.containsKey(HttpHeaders.authorizationHeader)) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $authToken');
      }

      if (item.body != null && item.body!.isNotEmpty) {
        final resolvedBody = _resolveVariables(item.body!, variableMap);
        request.write(resolvedBody);
      }

      final response = await request.close();
      stopwatch.stop();

      final responseBody = await response.transform(utf8.decoder).join();
      final respHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        respHeaders[name] = values.join('; ');
      });

      dynamic parsedBody;
      try {
        parsedBody = jsonDecode(responseBody);
      } catch (_) {
        parsedBody = responseBody;
      }

      return HttpInvocationResult(
        statusCode: response.statusCode,
        statusText: response.reasonPhrase,
        durationMs: stopwatch.elapsedMilliseconds,
        headers: respHeaders,
        body: parsedBody,
        rawResponse: responseBody,
      );
    } catch (e, stack) {
      stopwatch.stop();
      return HttpInvocationResult(
        statusCode: 500,
        statusText: 'Request Failed',
        durationMs: stopwatch.elapsedMilliseconds,
        error: '$e\n$stack',
        rawResponse: e.toString(),
      );
    } finally {
      client.close();
    }
  }

  static String _resolveVariables(String text, Map<String, String> variables) {
    var result = text;
    for (final entry in variables.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    return result;
  }
}
