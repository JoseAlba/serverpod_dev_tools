import 'dart:convert';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_dev_tools/serverpod_dev_tools.dart';
import 'package:test/test.dart';

class _MockApiConfig implements ServerConfig {
  @override
  int get port => 8080;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockWebConfig implements ServerConfig {
  @override
  int get port => 8082;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockServerpodConfig implements ServerpodConfig {
  @override
  ServerConfig get apiServer => _MockApiConfig();

  @override
  ServerConfig? get webServer => _MockWebConfig();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockServerpod implements Serverpod {
  @override
  String get runMode => 'development';

  @override
  ServerpodConfig get config => _MockServerpodConfig();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockRequest implements Request {
  @override
  final Method method;
  @override
  final Uri url;
  @override
  final Headers headers;
  @override
  final ConnectionInfo connectionInfo;

  _MockRequest({
    this.method = Method.get,
    required this.url,
    Headers? headers,
    ConnectionInfo? connectionInfo,
  })  : headers = headers ?? Headers.empty(),
        connectionInfo = connectionInfo ?? ConnectionInfo.empty;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSession implements Session {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('ServerpodDevToolsRoute Configuration & CORS Tests', () {
    test('ServerpodDevToolsRoute explicitly enables GET, POST, OPTIONS, PUT, DELETE, PATCH', () {
      final mockPod = _MockServerpod();
      final route = ServerpodDevToolsRoute(pod: mockPod);

      // Verify that all required HTTP methods are enabled on the route
      expect(route.methods, contains(Method.get));
      expect(route.methods, contains(Method.post));
      expect(route.methods, contains(Method.options));
      expect(route.methods, contains(Method.put));
      expect(route.methods, contains(Method.delete));
      expect(route.methods, contains(Method.patch));
      expect(route.methods.length, equals(6));
    });

    test('GET /serverpod_dev_tools/api returns 200 OK with API index JSON and CORS headers', () async {
      final mockPod = _MockServerpod();
      final route = ServerpodDevToolsRoute(pod: mockPod);

      final req = _MockRequest(
        method: Method.get,
        url: Uri.parse('http://localhost:8082/serverpod_dev_tools/api'),
        headers: Headers.fromMap({
          'host': ['localhost:8082'],
          'origin': ['http://localhost:5000'],
        }),
      );

      final result = await route.handleCall(_MockSession(), req);
      expect(result, isA<Response>());
      final res = result as Response;
      expect(res.statusCode, equals(200));
      expect(res.headers['access-control-allow-origin']?.firstOrNull, equals('http://localhost:5000'));

      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['status'], equals('online'));
      expect(body['name'], equals('Serverpod DevTools REST API'));
      expect(body['endpoints'], isA<Map<String, dynamic>>());
      expect(body['endpoints']['schema'], contains('/schema'));
      expect(body['endpoints']['endpoints'], contains('/endpoints'));
    });

    test('GET /serverpod_dev_tools/api/status returns server info and discovery paths', () async {
      final mockPod = _MockServerpod();
      final route = ServerpodDevToolsRoute(pod: mockPod);

      final req = _MockRequest(
        method: Method.get,
        url: Uri.parse('http://localhost:8082/serverpod_dev_tools/api/status'),
        headers: Headers.fromMap({
          'host': ['localhost:8082'],
        }),
      );

      final result = await route.handleCall(_MockSession(), req);
      expect(result, isA<Response>());
      final res = result as Response;
      expect(res.statusCode, equals(200));

      final body = jsonDecode(await res.readAsString()) as Map<String, dynamic>;
      expect(body['status'], equals('online'));
      expect(body['runMode'], equals('development'));
      expect(body['webServerPort'], equals(8082));
      expect(body['apiServerPort'], equals(8080));
    });
  });
}
