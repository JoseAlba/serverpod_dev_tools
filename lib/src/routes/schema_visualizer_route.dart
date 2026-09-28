import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../database/database_data_accessor.dart';
import '../endpoints/caller/endpoint_caller.dart';
import '../endpoints/models/http_request_item.dart';
import '../endpoints/scanner/endpoint_scanner.dart';
import '../endpoints/scanner/http_file_parser.dart';
import '../endpoints/scanner/http_file_writer.dart';
import '../mock/mock_data_generator.dart';
import '../mock/topological_sorter.dart';
import '../models/schema_graph.dart';
import '../parser/spy_yaml_scanner.dart';

/// Serverpod WebServer [Route] providing HTTP REST endpoints for the Serverpod DevTools suite.
class ServerpodDevToolsRoute extends Route {
  final Serverpod pod;
  final SpyYamlScanner scanner;
  final Directory modelsDirectory;
  final Directory httpDirectory;
  final EndpointScanner endpointScanner;
  final EndpointCaller endpointCaller;
  final bool forceEnable;

  SchemaGraph? _cachedSchema;

  ServerpodDevToolsRoute({
    required this.pod,
    SpyYamlScanner? scanner,
    Directory? modelsDirectory,
    Directory? httpDirectory,
    this.forceEnable = false,
  })  : scanner = scanner ?? SpyYamlScanner(),
        modelsDirectory = modelsDirectory ?? Directory('lib/src/models'),
        httpDirectory = httpDirectory ?? Directory('http'),
        endpointScanner = EndpointScanner(pod),
        endpointCaller = EndpointCaller(pod),
        super(
          methods: const {
            Method.get,
            Method.post,
            Method.options,
            Method.put,
            Method.delete,
            Method.patch,
          },
        );

  /// Validates whether an origin header is an allowed local loopback or DevTools extension origin.
  static bool _isAllowedLoopbackOrigin(String origin) {
    if (origin.isEmpty) return true;
    final parsed = Uri.tryParse(origin);
    if (parsed == null) return false;
    final scheme = parsed.scheme.toLowerCase();
    final host = parsed.host.toLowerCase();

    // DevTools & IDE extension protocols
    if (scheme == 'devtools' ||
        scheme == 'chrome-extension' ||
        scheme == 'vscode-webview') {
      return true;
    }

    // Local loopback origins
    if ((scheme == 'http' || scheme == 'https') &&
        (host == 'localhost' || host == '127.0.0.1' || host == '::1' || host == '[::1]')) {
      return true;
    }

    return false;
  }

  /// Attempts to discover the Serverpod server Dart VM Service URI from standard project locations.
  static String? findServerVmServiceUri() {
    try {
      final candidates = [
        File('.dart_tool/serverpod/vm-service-info.pod.json'),
        File('apps/studio/studio_server/.dart_tool/serverpod/vm-service-info.pod.json'),
        File('../apps/studio/studio_server/.dart_tool/serverpod/vm-service-info.pod.json'),
        File('../../apps/studio/studio_server/.dart_tool/serverpod/vm-service-info.pod.json'),
      ];
      for (final file in candidates) {
        if (file.existsSync()) {
          final content = file.readAsStringSync();
          final data = jsonDecode(content) as Map<String, dynamic>;
          final uri = data['uri'] as String?;
          if (uri != null && uri.isNotEmpty) {
            return uri;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  FutureOr<Result> handleCall(Session session, Request request) async {
    try {
      // 1. Release & Production Lockout Guard
      const isReleaseMode = bool.fromEnvironment('dart.vm.product');
      final isProduction = pod.runMode == ServerpodRunMode.production ||
          pod.runMode == 'production' ||
          pod.runMode == ServerpodRunMode.staging ||
          pod.runMode == 'staging';
      final isForceEnabled = forceEnable == true;

      if (!isForceEnabled && (isReleaseMode || isProduction)) {
        return Response.forbidden(
          body: Body.fromString(jsonEncode({
            'error': 'Serverpod DevTools is disabled in release/production mode for security.',
          })),
          headers: Headers.fromMap({
            'content-type': ['application/json; charset=utf-8'],
          }),
        );
      }

      // 2. Strict Localhost Host & IP Validation Guard
      final uri = request.url;
      final uriHost = uri.host.toLowerCase();
      final rawHostHeader = (request.headers['host']?.firstOrNull ?? '').toLowerCase();
      final hostHeaderName = rawHostHeader.contains(':') ? rawHostHeader.split(':').first : rawHostHeader;

      final isUriHostValid = uriHost.isEmpty ||
          uriHost == 'localhost' ||
          uriHost == '127.0.0.1' ||
          uriHost == '::1' ||
          uriHost == '[::1]';

      final isHostHeaderValid = hostHeaderName.isEmpty ||
          hostHeaderName == 'localhost' ||
          hostHeaderName == '127.0.0.1' ||
          hostHeaderName == '::1' ||
          hostHeaderName == '[::1]';

      final isHostValid = isUriHostValid && isHostHeaderValid;

      final remoteAddress = request.connectionInfo.remote.address.toString().toLowerCase();
      final isRemoteIpValid = remoteAddress.isEmpty ||
          remoteAddress == '127.0.0.1' ||
          remoteAddress == '::1' ||
          remoteAddress == '::ffff:127.0.0.1' ||
          remoteAddress == '0.0.0.0' ||
          remoteAddress == '::' ||
          remoteAddress.contains('localhost');

      if (!isForceEnabled && (!isHostValid || !isRemoteIpValid)) {
        return Response.forbidden(
          body: Body.fromString(jsonEncode({
            'error': 'Serverpod DevTools is strictly restricted to localhost (127.0.0.1).',
          })),
          headers: Headers.fromMap({
            'content-type': ['application/json; charset=utf-8'],
          }),
        );
      }

      // 3. Loopback & DevTools CORS Whitelist
      final originHeader = request.headers['origin']?.firstOrNull ?? '';
      final isOriginAllowed = _isAllowedLoopbackOrigin(originHeader);

      final corsHeadersMap = <String, List<String>>{
        'content-type': ['application/json; charset=utf-8'],
        'access-control-allow-methods': ['GET, POST, OPTIONS, PUT, DELETE, PATCH'],
        'access-control-allow-headers': [
          'content-type, authorization, accept, origin, x-requested-with'
        ],
        'access-control-max-age': ['86400'],
      };

      if (isOriginAllowed && originHeader.isNotEmpty) {
        corsHeadersMap['access-control-allow-origin'] = [originHeader];
      } else if (originHeader.isEmpty) {
        // Direct same-origin or local CLI calls (e.g. curl)
        corsHeadersMap['access-control-allow-origin'] = ['*'];
      }

      final corsHeaders = Headers.fromMap(corsHeadersMap);

      if (request.method == Method.options) {
        return Response.ok(headers: corsHeaders);
      }

      final path = uri.path;

      // 0. GET /api or /status -> Return REST API Index & Server Runtime Info
      if (path == '/serverpod_dev_tools/api' ||
          path == '/serverpod_dev_tools/api/' ||
          path.endsWith('/status') ||
          path.endsWith('/api') ||
          path.endsWith('/api/')) {
        final serverVmUri = findServerVmServiceUri();
        final base = path.endsWith('/') ? path.substring(0, path.length - 1) : path;
        final apiPrefix = base.endsWith('/status') ? base.replaceAll('/status', '') : base;

        return Response.ok(
          body: Body.fromString(jsonEncode({
            'name': 'Serverpod DevTools REST API',
            'status': 'online',
            'version': '0.1.0',
            'runMode': pod.runMode,
            'serverVmUri': serverVmUri,
            'webServerPort': pod.config.webServer?.port ?? 8082,
            'apiServerPort': pod.config.apiServer.port,
            'endpoints': {
              'root': apiPrefix,
              'status': '$apiPrefix/status',
              'schema': '$apiPrefix/schema',
              'endpoints': '$apiPrefix/endpoints',
              'data': '$apiPrefix/data?table=<tableName>',
              'stats': '$apiPrefix/stats',
              'http': '$apiPrefix/http',
              'invoke': '$apiPrefix/invoke',
              'mock': '$apiPrefix/mock',
              'order': '$apiPrefix/order',
            },
          })),
          headers: corsHeaders,
        );
      }

      // 1. GET /schema -> Return full SchemaGraph JSON
      if (path.endsWith('/schema')) {
        try {
          if (_cachedSchema == null) {
            var scanDir = modelsDirectory;
            if (!await scanDir.exists()) {
              scanDir = Directory.current;
            }
            _cachedSchema = await scanner.scanDirectory(scanDir);
          }

          return Response.ok(
            body: Body.fromString(jsonEncode(_cachedSchema!.toJson())),
            headers: corsHeaders,
          );
        } catch (e, st) {
          return Response.internalServerError(
            body: Body.fromString(jsonEncode({
              'error': e.toString(),
              'stackTrace': st.toString(),
            })),
            headers: corsHeaders,
          );
        }
      }

      // 2. GET /data?table=tableName&limit=50&offset=0 -> Return TableDataPage JSON
    if (path.endsWith('/data')) {
      final queryParams = uri.queryParameters;
      final tableName = queryParams['table'];

      if (tableName == null || tableName.isEmpty) {
        return Response.badRequest(
          body: Body.fromString(jsonEncode({'error': 'Missing "table" query parameter'})),
          headers: corsHeaders,
        );
      }

      final limit = int.tryParse(queryParams['limit'] ?? '50') ?? 50;
      final offset = int.tryParse(queryParams['offset'] ?? '0') ?? 0;
      final sortBy = queryParams['sortBy'];
      final sortAscending = queryParams['sortAscending'] != 'false';
      final searchQuery = queryParams['search'];

      try {
        final dbAccessor = DatabaseDataAccessor(session.db);
        final page = await dbAccessor.fetchTableData(
          tableName: tableName,
          limit: limit,
          offset: offset,
          sortBy: sortBy,
          sortAscending: sortAscending,
          searchQuery: searchQuery,
        );

        return Response.ok(
          body: Body.fromString(jsonEncode(page.toJson())),
          headers: corsHeaders,
        );
      } catch (e, st) {
        return Response.internalServerError(
          body: Body.fromString(jsonEncode({'error': e.toString(), 'stackTrace': st.toString()})),
          headers: corsHeaders,
        );
      }
    }

    // 3. GET /stats -> Return row counts
    if (path.endsWith('/stats')) {
      try {
        final dbAccessor = DatabaseDataAccessor(session.db);
        final stats = await dbAccessor.fetchDatabaseStats();
        return Response.ok(
          body: Body.fromString(jsonEncode(stats)),
          headers: corsHeaders,
        );
      } catch (e) {
        return Response.internalServerError(
          body: Body.fromString(jsonEncode({'error': e.toString()})),
          headers: corsHeaders,
        );
      }
    }

    // 4. GET /endpoints -> Return list of endpoints and methods
    if (path.endsWith('/endpoints')) {
      try {
        final endpoints = endpointScanner.scanEndpoints();
        return Response.ok(
          body: Body.fromString(jsonEncode({'endpoints': endpoints.map((e) => e.toJson()).toList()})),
          headers: corsHeaders,
        );
      } catch (e) {
        return Response.internalServerError(
          body: Body.fromString(jsonEncode({'error': e.toString()})),
          headers: corsHeaders,
        );
      }
    }

    // 5. GET /http or /http-collections -> Return parsed .http collections
    if (path.endsWith('/http') || path.endsWith('/http-collections') || path.endsWith('/collections')) {
      try {
        final collections = HttpFileParser.scanDirectory(httpDirectory);
        return Response.ok(
          body: Body.fromString(jsonEncode({'collections': collections.map((c) => c.toJson()).toList()})),
          headers: corsHeaders,
        );
      } catch (e) {
        return Response.internalServerError(
          body: Body.fromString(jsonEncode({'error': e.toString()})),
          headers: corsHeaders,
        );
      }
    }

    // 6. POST /invoke -> Invoke endpoint
    if ((path.endsWith('/invoke') || path.endsWith('/invoke/')) && request.method == Method.post) {
      try {
        final rawBody = await request.readAsString();
        final bodyJson = jsonDecode(rawBody) as Map<String, dynamic>;

        final endpoint = bodyJson['endpoint'] as String? ?? '';
        final method = bodyJson['method'] as String? ?? '';
        final authToken = bodyJson['authToken'] as String?;
        final baseUrl = bodyJson['baseUrl'] as String?;
        final params = (bodyJson['parameters'] as Map<String, dynamic>?) ?? {};

        final result = await endpointCaller.invoke(
          endpoint: endpoint,
          method: method,
          parameters: params,
          authToken: authToken,
          baseUrl: baseUrl,
        );

        return Response.ok(
          body: Body.fromString(jsonEncode(result.toJson())),
          headers: corsHeaders,
        );
      } catch (e) {
        return Response.internalServerError(
          body: Body.fromString(jsonEncode({'error': e.toString()})),
          headers: corsHeaders,
        );
      }
    }

    // 7. POST /save_http -> Save .http request
    if ((path.endsWith('/save_http') || path.endsWith('/save_http/')) && request.method == Method.post) {
      try {
        final rawBody = await request.readAsString();
        final bodyJson = jsonDecode(rawBody) as Map<String, dynamic>;

        final fileName = bodyJson['fileName'] as String? ?? 'custom.http';
        final requestMap = bodyJson['request'] as Map<String, dynamic>;
        final reqItem = HttpRequestItem.fromJson(requestMap);

        final file = HttpFileWriter.saveRequestToFile(
          httpDirectory: httpDirectory,
          fileName: fileName,
          request: reqItem,
        );

        return Response.ok(
          body: Body.fromString(jsonEncode({'success': true, 'filePath': file.path})),
          headers: corsHeaders,
        );
      } catch (e) {
        return Response.internalServerError(
          body: Body.fromString(jsonEncode({'error': e.toString()})),
          headers: corsHeaders,
        );
      }
    }

    // 8. POST /mock -> Generate mock data
    if (path.endsWith('/mock') && request.method == Method.post) {
      try {
        _cachedSchema ??= await scanner.scanDirectory(modelsDirectory);

        final rawBody = await request.readAsString();
        final bodyJson = (jsonDecode(rawBody) as Map<String, dynamic>?) ?? {};

        final rowsPerTable = (bodyJson['rowsPerTable'] as int?) ?? 3;
        final seedLiveDb = bodyJson['seedLiveDb'] == true;

        final genResult = MockDataGenerator.generate(
          graph: _cachedSchema!,
          rowsPerTable: rowsPerTable,
        );

        Map<String, int>? liveStats;
        if (seedLiveDb) {
          final accessor = DatabaseDataAccessor(session.db);
          liveStats = await genResult.seedDatabase(accessor);
        }

        return Response.ok(
          body: Body.fromString(jsonEncode({
            'success': true,
            'rows': genResult.rows,
            'sqlScript': genResult.toSqlScript(),
            'dartScript': genResult.toDartSeedScript(),
            'liveSeedStats': ?liveStats,
          })),
          headers: corsHeaders,
        );
      } catch (e) {
        return Response.internalServerError(
          body: Body.fromString(jsonEncode({'error': e.toString()})),
          headers: corsHeaders,
        );
      }
    }

    // 9. GET /order or /dependency_order -> Return topological table dependency order
    if (path.endsWith('/order') || path.endsWith('/dependency_order')) {
      try {
        _cachedSchema ??= await scanner.scanDirectory(modelsDirectory);
        final ordered = TopologicalSorter.sortTables(_cachedSchema!);
        return Response.ok(
          body: Body.fromString(jsonEncode({'order': ordered.map((t) => t.tableName).toList()})),
          headers: corsHeaders,
        );
      } catch (e) {
        return Response.internalServerError(
          body: Body.fromString(jsonEncode({'error': e.toString()})),
          headers: corsHeaders,
        );
      }
    }

    return Response.notFound(
      body: Body.fromString(jsonEncode({'error': 'Not found: $path'})),
      headers: corsHeaders,
    );
    } catch (e, st) {
      return Response.internalServerError(
        body: Body.fromString(jsonEncode({
          'error': e.toString(),
          'stackTrace': st.toString(),
        })),
        headers: Headers.fromMap({
          'content-type': ['application/json; charset=utf-8'],
          'access-control-allow-origin': ['*'],
          'access-control-allow-methods': ['GET, POST, OPTIONS, PUT, DELETE, PATCH'],
          'access-control-allow-headers': [
            'content-type, authorization, accept, origin, x-requested-with'
          ],
        }),
      );
    }
  }
}

/// Backwards-compatible alias for [ServerpodDevToolsRoute].
typedef SchemaVisualizerRoute = ServerpodDevToolsRoute;
