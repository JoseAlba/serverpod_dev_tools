import 'package:serverpod/serverpod.dart';
import 'package:serverpod_dev_tools/serverpod_dev_tools.dart';
import 'package:test/test.dart';

class _MockServerpod implements Serverpod {
  final String _runMode;
  _MockServerpod({this._runMode = 'development'});

  @override
  String get runMode => _runMode;

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
  group('Serverpod DevTools Security & Localhost Lockout Tests', () {
    test('ServerpodDevTools.initialize skips in production run mode', () {
      final prodPod = _MockServerpod(runMode: ServerpodRunMode.production);
      ServerpodDevTools.initialize(prodPod);

      // Verify that initialization did not proceed
      expect(ServerpodDevTools.isEnabled, isFalse);
    });

    test('ServerpodDevTools.initialize skips in staging run mode', () {
      final stagingPod = _MockServerpod(runMode: ServerpodRunMode.staging);
      ServerpodDevTools.initialize(stagingPod);

      expect(ServerpodDevTools.isEnabled, isFalse);
    });

    test('ServerpodDevToolsRoute returns 403 Forbidden in production mode', () async {
      final prodPod = _MockServerpod(runMode: 'production');
      final route = ServerpodDevToolsRoute(pod: prodPod);
      final req = _MockRequest(
        url: Uri.parse('http://localhost:8082/serverpod_dev_tools/api/schema'),
        headers: Headers.fromMap({
          'host': ['localhost:8082'],
        }),
      );

      final result = await route.handleCall(_MockSession(), req);
      expect(result, isA<Response>());
      final res = result as Response;
      expect(res.statusCode, equals(403));
      final body = await res.readAsString();
      expect(body, contains('disabled in release/production mode'));
    });

    test('ServerpodDevToolsRoute rejects external Host headers with 403 Forbidden', () async {
      final devPod = _MockServerpod(runMode: 'development');
      final route = ServerpodDevToolsRoute(pod: devPod);
      final req = _MockRequest(
        url: Uri.parse('http://localhost:8082/serverpod_dev_tools/api/schema'),
        headers: Headers.fromMap({
          'host': ['malicious-domain.com'],
        }),
      );

      final result = await route.handleCall(_MockSession(), req);
      expect(result, isA<Response>());
      final res = result as Response;
      expect(res.statusCode, equals(403));
      final body = await res.readAsString();
      expect(body, contains('strictly restricted to localhost'));
    });

    test('ServerpodDevToolsRoute rejects external IP addresses with 403 Forbidden', () async {
      final devPod = _MockServerpod(runMode: 'development');
      final route = ServerpodDevToolsRoute(pod: devPod);
      final req = _MockRequest(
        url: Uri.parse('http://localhost:8082/serverpod_dev_tools/api/schema'),
        headers: Headers.fromMap({
          'host': ['localhost:8082'],
        }),
        connectionInfo: ConnectionInfo(
          remote: SocketAddress(
            address: IPv4Address.fromOctets(192, 168, 1, 150),
            port: 54321,
          ),
          localPort: 8082,
        ),
      );

      final result = await route.handleCall(_MockSession(), req);
      expect(result, isA<Response>());
      final res = result as Response;
      expect(res.statusCode, equals(403));
      final body = await res.readAsString();
      expect(body, contains('strictly restricted to localhost'));
    });

    test('ServerpodDevToolsRoute allows loopback CORS origins and rejects external origins', () async {
      final devPod = _MockServerpod(runMode: 'development');
      final route = ServerpodDevToolsRoute(pod: devPod);

      // 1. Allowed localhost origin
      final reqLocalhost = _MockRequest(
        method: Method.options,
        url: Uri.parse('http://localhost:8082/serverpod_dev_tools/api/schema'),
        headers: Headers.fromMap({
          'host': ['localhost:8082'],
          'origin': ['http://localhost:3000'],
        }),
      );
      final res1 = (await route.handleCall(_MockSession(), reqLocalhost)) as Response;
      expect(res1.statusCode, equals(200));
      expect(res1.headers['access-control-allow-origin']?.firstOrNull, equals('http://localhost:3000'));

      // 2. Allowed devtools:// origin
      final reqDevtools = _MockRequest(
        method: Method.options,
        url: Uri.parse('http://localhost:8082/serverpod_dev_tools/api/schema'),
        headers: Headers.fromMap({
          'host': ['localhost:8082'],
          'origin': ['devtools://devtools'],
        }),
      );
      final res2 = (await route.handleCall(_MockSession(), reqDevtools)) as Response;
      expect(res2.statusCode, equals(200));
      expect(res2.headers['access-control-allow-origin']?.firstOrNull, equals('devtools://devtools'));

      // 3. Rejected external origin
      final reqEvil = _MockRequest(
        method: Method.options,
        url: Uri.parse('http://localhost:8082/serverpod_dev_tools/api/schema'),
        headers: Headers.fromMap({
          'host': ['localhost:8082'],
          'origin': ['https://evil-hacker.com'],
        }),
      );
      final res3 = (await route.handleCall(_MockSession(), reqEvil)) as Response;
      expect(res3.statusCode, equals(200));
      // access-control-allow-origin MUST NOT echo the external origin
      expect(res3.headers['access-control-allow-origin'], isNull);
    });

    test('DatabaseDataAccessor identifies sensitive columns', () {
      // Sensitive columns
      expect(DatabaseDataAccessor.isSensitiveColumn('password'), isTrue);
      expect(DatabaseDataAccessor.isSensitiveColumn('password_hash'), isTrue);
      expect(DatabaseDataAccessor.isSensitiveColumn('userSecret'), isTrue);
      expect(DatabaseDataAccessor.isSensitiveColumn('authToken'), isTrue);
      expect(DatabaseDataAccessor.isSensitiveColumn('verification_code'), isTrue);
      expect(DatabaseDataAccessor.isSensitiveColumn('private_key'), isTrue);
      expect(DatabaseDataAccessor.isSensitiveColumn('api_key'), isTrue);

      // Safe columns & foreign keys
      expect(DatabaseDataAccessor.isSensitiveColumn('id'), isFalse);
      expect(DatabaseDataAccessor.isSensitiveColumn('user_id'), isFalse);
      expect(DatabaseDataAccessor.isSensitiveColumn('token_id'), isFalse);
      expect(DatabaseDataAccessor.isSensitiveColumn('password_reset_id'), isFalse);
      expect(DatabaseDataAccessor.isSensitiveColumn('email'), isFalse);
      expect(DatabaseDataAccessor.isSensitiveColumn('created_at'), isFalse);
      expect(DatabaseDataAccessor.isSensitiveColumn('name'), isFalse);
    });
  });
}
