import 'dart:convert';
import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/endpoint_metadata.dart';
import '../models/http_request_item.dart';
import '../schema_models.dart';

/// Connection mode between DevTools and Serverpod backend.
enum DevToolsConnectionMode {
  vmService,
  httpRest,
  disconnected,
}

/// Handles dual-mode communication between the DevTools Extension web UI
/// and the running Serverpod server:
/// 1. Direct Dart VM Service RPC (when DevTools is attached to the Serverpod server VM).
/// 2. Automatic HTTP REST fallback (when DevTools is attached to Flutter web client or standalone).
class DevToolsSchemaService extends ChangeNotifier {
  static const String extGetSchema = 'ext.serverpod_dev_tools.getSchema';
  static const String extGetTableData = 'ext.serverpod_dev_tools.getTableData';
  static const String extGetDatabaseStats = 'ext.serverpod_dev_tools.getDatabaseStats';
  static const String extGetEndpoints = 'ext.serverpod_dev_tools.getEndpoints';
  static const String extGetHttpCollections = 'ext.serverpod_dev_tools.getHttpCollections';
  static const String extInvokeEndpoint = 'ext.serverpod_dev_tools.invokeEndpoint';
  static const String extSaveHttpRequest = 'ext.serverpod_dev_tools.saveHttpRequest';

  // Legacy aliases
  static const String legacyExtGetSchema = 'ext.serverpod_schema_visualizer.getSchema';
  static const String legacyExtGetTableData = 'ext.serverpod_schema_visualizer.getTableData';
  static const String legacyExtGetDatabaseStats = 'ext.serverpod_schema_visualizer.getDatabaseStats';
  static const String legacyExtGetEndpoints = 'ext.serverpod_schema_visualizer.getEndpoints';
  static const String legacyExtGetHttpCollections = 'ext.serverpod_schema_visualizer.getHttpCollections';

  // Default candidate WebServer base URLs to probe
  static const List<String> defaultCandidateUrls = [
    'http://localhost:8082/serverpod_dev_tools/api',
    'http://localhost:8080/serverpod_dev_tools/api',
    'http://127.0.0.1:8082/serverpod_dev_tools/api',
    'http://127.0.0.1:8080/serverpod_dev_tools/api',
  ];

  /// Active Serverpod WebServer API base URL for HTTP REST fallback.
  String _serverBaseUrl = defaultCandidateUrls.first;
  String get serverBaseUrl => _serverBaseUrl;

  /// Active connection mode.
  DevToolsConnectionMode _connectionMode = DevToolsConnectionMode.disconnected;
  DevToolsConnectionMode get connectionMode => _connectionMode;

  /// Last error encountered during VM service or HTTP communication, if any.
  String? lastError;

  /// Roundtrip latency in milliseconds from the last successful ping/request.
  int? lastLatencyMs;

  /// Whether DevTools is actively connected via VM Service or HTTP REST.
  bool get isConnected => _connectionMode != DevToolsConnectionMode.disconnected;

  /// Discovered Serverpod Server VM Service URI (if reported by REST endpoint)
  String? _serverVmServiceUri;
  String? get serverVmServiceUri => _serverVmServiceUri;

  /// Whether DevTools has an active VM Service connection.
  bool get isVmConnected => serviceManager.connectedState.value.connected && serviceManager.service != null;

  /// Checks whether the provided URL points strictly to localhost / 127.0.0.1 / ::1.
  static bool isLocalhostUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    final host = uri.host.toLowerCase();
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '::1' ||
        host == '[::1]';
  }

  /// Updates the target HTTP REST server base URL and notifies listeners.
  ///
  /// Strictly enforces that [url] targets a localhost address.
  void setServerBaseUrl(String url) {
    var cleaned = url.trim();
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    if (!cleaned.endsWith('/api') && !cleaned.endsWith('/serverpod_dev_tools')) {
      cleaned = '$cleaned/serverpod_dev_tools/api';
    }
    if (!isLocalhostUrl(cleaned)) {
      throw ArgumentError(
        'DevTools connections are strictly restricted to localhost (127.0.0.1). Remote URL "$url" is not permitted.',
      );
    }
    _serverBaseUrl = cleaned;
    notifyListeners();
  }

  /// Sets the active connection mode and notifies listeners.
  void _setConnectionMode(DevToolsConnectionMode mode) {
    if (_connectionMode != mode) {
      _connectionMode = mode;
      notifyListeners();
    }
  }

  /// Checks if an error is a Dart VM Service "Method not found" (-32601) error.
  bool _isMethodNotFoundError(Object error) {
    final str = error.toString();
    return str.contains('-32601') || str.contains('Method not found') || str.contains('Unknown method');
  }

  /// Fetches the parsed [SchemaGraph] using VM Service RPC, falling back to HTTP REST.
  Future<SchemaGraph> fetchSchema({bool forceRefresh = false}) async {
    lastError = null;
    final stopwatch = Stopwatch()..start();

    // 1. Try VM Service RPC first if connected to a VM
    if (isVmConnected) {
      try {
        var response = await serviceManager.service!.callServiceExtension(
          extGetSchema,
          args: {'forceRefresh': forceRefresh.toString()},
        ).catchError((_) => serviceManager.service!.callServiceExtension(
          legacyExtGetSchema,
          args: {'forceRefresh': forceRefresh.toString()},
        ));

        final jsonStr = response.json?['result'] ?? response.json?['value'];
        if (jsonStr != null) {
          final decoded = jsonDecode(jsonStr as String) as Map<String, dynamic>;
          stopwatch.stop();
          lastLatencyMs = stopwatch.elapsedMilliseconds;
          _setConnectionMode(DevToolsConnectionMode.vmService);
          return SchemaGraph.fromJson(decoded);
        }
      } catch (e) {
        if (!_isMethodNotFoundError(e)) {
          debugPrint('[DevToolsSchemaService] VM Service error calling $extGetSchema: $e');
        }
        // If method not found, DevTools is attached to Flutter app instead of server VM.
        // Fall through to HTTP REST fallback!
      }
    }

    // 2. Try HTTP REST fallback
    final httpResult = await _fetchSchemaHttp(forceRefresh: forceRefresh);
    if (httpResult != null) {
      stopwatch.stop();
      lastLatencyMs = stopwatch.elapsedMilliseconds;
      _setConnectionMode(DevToolsConnectionMode.httpRest);
      return httpResult;
    }

    // 3. Both failed
    _setConnectionMode(DevToolsConnectionMode.disconnected);
    lastError ??= 'Cannot connect to Serverpod server.\n'
        '• VM Service: DevTools is not connected to Serverpod server VM (it may be attached to Flutter app).\n'
        '• HTTP REST: Unable to reach Serverpod WebServer at $_serverBaseUrl.';
    return const SchemaGraph(tables: []);
  }

  Future<SchemaGraph?> _fetchSchemaHttp({bool forceRefresh = false}) async {
    final urlsToTry = <String>[
      _serverBaseUrl,
      ...defaultCandidateUrls.where((u) => u != _serverBaseUrl),
    ];

    String? lastHttpError;

    for (final baseUrl in urlsToTry) {
      try {
        // Probe root status endpoint to discover server metadata and VM Service URI
        try {
          final statusUri = Uri.parse(baseUrl);
          final statusRes = await http.get(statusUri).timeout(const Duration(seconds: 2));
          if (statusRes.statusCode == 200) {
            final statusJson = jsonDecode(statusRes.body);
            if (statusJson is Map<String, dynamic> && statusJson['serverVmUri'] is String) {
              _serverVmServiceUri = statusJson['serverVmUri'] as String;
            }
          }
        } catch (_) {
          // Status probe is non-critical
        }

        final uri = Uri.parse('$baseUrl/schema?forceRefresh=$forceRefresh');
        final response = await http.get(uri).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body) as Map<String, dynamic>;
          _serverBaseUrl = baseUrl;
          lastError = null;
          return SchemaGraph.fromJson(decoded);
        } else {
          try {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic> && decoded['error'] != null) {
              lastHttpError = 'Server returned HTTP ${response.statusCode}: ${decoded['error']}';
            } else {
              lastHttpError = 'Server returned HTTP ${response.statusCode}';
            }
          } catch (_) {
            lastHttpError = 'Server returned HTTP ${response.statusCode}';
          }
        }
      } catch (e) {
        lastHttpError = 'Connection failed to $baseUrl: $e';
      }
    }

    if (lastHttpError != null) {
      lastError = lastHttpError;
    }
    return null;
  }

  /// Fetches live paginated records for [tableName].
  Future<TableDataPage> fetchTableData({
    required String tableName,
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool descending = false,
  }) async {
    // 1. Try VM Service if in VM mode
    if (_connectionMode == DevToolsConnectionMode.vmService && isVmConnected) {
      try {
        final args = <String, String>{
          'table': tableName,
          'limit': limit.toString(),
          'offset': offset.toString(),
          'descending': descending.toString(),
        };
        if (orderBy != null) args['orderBy'] = orderBy;

        final response = await serviceManager.service!.callServiceExtension(
          extGetTableData,
          args: args,
        ).catchError((_) => serviceManager.service!.callServiceExtension(
          legacyExtGetTableData,
          args: args,
        ));

        final jsonStr = response.json?['result'] ?? response.json?['value'];
        if (jsonStr != null) {
          final decoded = jsonDecode(jsonStr as String) as Map<String, dynamic>;
          return TableDataPage.fromJson(decoded);
        }
      } catch (e) {
        if (!_isMethodNotFoundError(e)) {
          debugPrint('[DevToolsSchemaService] Error calling $extGetTableData: $e');
        }
      }
    }

    // 2. HTTP REST fallback
    try {
      final queryParams = <String, String>{
        'table': tableName,
        'limit': limit.toString(),
        'offset': offset.toString(),
        'sortAscending': (!descending).toString(),
      };
      if (orderBy != null) queryParams['sortBy'] = orderBy;

      final uri = Uri.parse('$_serverBaseUrl/data').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return TableDataPage.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('[DevToolsSchemaService] HTTP error fetching table data: $e');
    }

    return TableDataPage(
      tableName: tableName,
      columns: const [],
      rows: const [],
      totalRows: 0,
      page: 0,
      pageSize: limit,
      executionDurationMs: 0.0,
    );
  }

  /// Fetches all registered Serverpod endpoints and callable RPC methods.
  Future<List<EndpointMetadata>> fetchEndpoints() async {
    // 1. Try VM Service if in VM mode
    if (_connectionMode == DevToolsConnectionMode.vmService && isVmConnected) {
      try {
        final response = await serviceManager.service!.callServiceExtension(
          extGetEndpoints,
        ).catchError((_) => serviceManager.service!.callServiceExtension(
          legacyExtGetEndpoints,
        ));
        final jsonStr = response.json?['result'] ?? response.json?['value'];
        if (jsonStr != null) {
          final decoded = jsonDecode(jsonStr as String) as Map<String, dynamic>;
          final list = decoded['endpoints'] as List<dynamic>?;
          return list?.map((e) => EndpointMetadata.fromJson(e as Map<String, dynamic>)).toList() ?? [];
        }
      } catch (e) {
        if (!_isMethodNotFoundError(e)) {
          debugPrint('[DevToolsSchemaService] Error calling $extGetEndpoints: $e');
        }
      }
    }

    // 2. HTTP REST fallback
    try {
      final uri = Uri.parse('$_serverBaseUrl/endpoints');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final list = decoded['endpoints'] as List<dynamic>?;
        return list?.map((e) => EndpointMetadata.fromJson(e as Map<String, dynamic>)).toList() ?? [];
      }
    } catch (e) {
      debugPrint('[DevToolsSchemaService] HTTP error fetching endpoints: $e');
    }

    return const [];
  }

  /// Fetches saved `.http` file collections from `*_server/http/*.http`.
  Future<List<HttpFileCollection>> fetchHttpCollections() async {
    // 1. Try VM Service if in VM mode
    if (_connectionMode == DevToolsConnectionMode.vmService && isVmConnected) {
      try {
        final response = await serviceManager.service!.callServiceExtension(
          extGetHttpCollections,
        ).catchError((_) => serviceManager.service!.callServiceExtension(
          legacyExtGetHttpCollections,
        ));
        final jsonStr = response.json?['result'] ?? response.json?['value'];
        if (jsonStr != null) {
          final decoded = jsonDecode(jsonStr as String) as Map<String, dynamic>;
          final list = decoded['collections'] as List<dynamic>?;
          return list?.map((c) => HttpFileCollection.fromJson(c as Map<String, dynamic>)).toList() ?? [];
        }
      } catch (e) {
        if (!_isMethodNotFoundError(e)) {
          debugPrint('[DevToolsSchemaService] Error calling $extGetHttpCollections: $e');
        }
      }
    }

    // 2. HTTP REST fallback
    try {
      final uri = Uri.parse('$_serverBaseUrl/http');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final list = decoded['collections'] as List<dynamic>?;
        return list?.map((c) => HttpFileCollection.fromJson(c as Map<String, dynamic>)).toList() ?? [];
      }
    } catch (e) {
      debugPrint('[DevToolsSchemaService] HTTP error fetching http collections: $e');
    }

    return const [];
  }

  /// Invokes an endpoint method or HTTP request and returns metrics and body.
  Future<HttpInvocationResult> invokeEndpoint({
    required String endpoint,
    required String method,
    Map<String, dynamic> parameters = const {},
    String? authToken,
    String? baseUrl,
  }) async {
    // 1. Try VM Service if in VM mode
    if (_connectionMode == DevToolsConnectionMode.vmService && isVmConnected) {
      try {
        final response = await serviceManager.service!.callServiceExtension(
          extInvokeEndpoint,
          args: {
            'endpoint': endpoint,
            'method': method,
            'parameters': jsonEncode(parameters),
            'authToken': ?authToken,
            'baseUrl': ?baseUrl,
          },
        );

        final jsonStr = response.json?['result'] ?? response.json?['value'];
        if (jsonStr != null) {
          final decoded = jsonDecode(jsonStr as String) as Map<String, dynamic>;
          return HttpInvocationResult.fromJson(decoded);
        }
      } catch (e) {
        if (!_isMethodNotFoundError(e)) {
          return HttpInvocationResult(
            statusCode: 500,
            statusText: 'Service Extension Error',
            durationMs: 0,
            error: e.toString(),
          );
        }
      }
    }

    // 2. HTTP REST fallback
    try {
      final uri = Uri.parse('$_serverBaseUrl/invoke');
      final payload = jsonEncode({
        'endpoint': endpoint,
        'method': method,
        'parameters': parameters,
        'authToken': ?authToken,
        'baseUrl': ?baseUrl,
      });

      final response = await http.post(
        uri,
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: payload,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return HttpInvocationResult.fromJson(decoded);
      } else {
        return HttpInvocationResult(
          statusCode: response.statusCode,
          statusText: 'HTTP Error',
          durationMs: 0,
          error: response.body,
        );
      }
    } catch (e) {
      return HttpInvocationResult(
        statusCode: 0,
        statusText: 'Network Error',
        durationMs: 0,
        error: e.toString(),
      );
    }
  }

  /// Saves or appends a request to a `.http` file on disk.
  Future<bool> saveHttpRequest({
    required String fileName,
    required HttpRequestItem request,
  }) async {
    // 1. Try VM Service if in VM mode
    if (_connectionMode == DevToolsConnectionMode.vmService && isVmConnected) {
      try {
        final response = await serviceManager.service!.callServiceExtension(
          extSaveHttpRequest,
          args: {
            'fileName': fileName,
            'request': jsonEncode(request.toJson()),
          },
        );
        final jsonStr = response.json?['result'] ?? response.json?['value'];
        if (jsonStr != null) {
          final decoded = jsonDecode(jsonStr as String) as Map<String, dynamic>;
          return decoded['success'] == true;
        }
      } catch (e) {
        if (!_isMethodNotFoundError(e)) {
          debugPrint('[DevToolsSchemaService] Error calling $extSaveHttpRequest: $e');
        }
      }
    }

    // 2. HTTP REST fallback
    try {
      final uri = Uri.parse('$_serverBaseUrl/save_http');
      final response = await http.post(
        uri,
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'fileName': fileName,
          'request': request.toJson(),
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        return decoded['success'] == true;
      }
    } catch (e) {
      debugPrint('[DevToolsSchemaService] HTTP error saving request: $e');
    }

    return false;
  }
}
