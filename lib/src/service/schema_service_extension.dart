import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:serverpod/serverpod.dart';

import '../database/database_data_accessor.dart';
import '../endpoints/caller/endpoint_caller.dart';
import '../endpoints/models/http_request_item.dart';
import '../endpoints/scanner/endpoint_scanner.dart';
import '../endpoints/scanner/http_file_parser.dart';
import '../endpoints/scanner/http_file_writer.dart';
import '../models/schema_graph.dart';
import '../parser/spy_yaml_scanner.dart';

/// Handles Dart VM Service RPC extension registrations for DevTools communication.
class SchemaServiceExtension {
  static const String extGetSchema = 'ext.serverpod_dev_tools.getSchema';
  static const String extGetTableData = 'ext.serverpod_dev_tools.getTableData';
  static const String extGetDatabaseStats = 'ext.serverpod_dev_tools.getDatabaseStats';
  static const String extGetEndpoints = 'ext.serverpod_dev_tools.getEndpoints';
  static const String extGetHttpCollections = 'ext.serverpod_dev_tools.getHttpCollections';
  static const String extInvokeEndpoint = 'ext.serverpod_dev_tools.invokeEndpoint';
  static const String extSaveHttpRequest = 'ext.serverpod_dev_tools.saveHttpRequest';
  static const String extGenerateMockData = 'ext.serverpod_dev_tools.generateMockData';
  static const String extGetDependencyOrder = 'ext.serverpod_dev_tools.getDependencyOrder';

  // Legacy aliases for backwards compatibility
  static const String legacyExtGetSchema = 'ext.serverpod_schema_visualizer.getSchema';
  static const String legacyExtGetTableData = 'ext.serverpod_schema_visualizer.getTableData';
  static const String legacyExtGetDatabaseStats = 'ext.serverpod_schema_visualizer.getDatabaseStats';
  static const String legacyExtGetEndpoints = 'ext.serverpod_schema_visualizer.getEndpoints';
  static const String legacyExtGetHttpCollections = 'ext.serverpod_schema_visualizer.getHttpCollections';
  static const String legacyExtInvokeEndpoint = 'ext.serverpod_schema_visualizer.invokeEndpoint';
  static const String legacyExtSaveHttpRequest = 'ext.serverpod_schema_visualizer.saveHttpRequest';

  final Serverpod pod;
  final SpyYamlScanner scanner;
  final Directory modelsDirectory;
  final Directory httpDirectory;
  final EndpointScanner endpointScanner;
  final EndpointCaller endpointCaller;

  SchemaGraph? _cachedSchema;

  SchemaServiceExtension({
    required this.pod,
    SpyYamlScanner? scanner,
    Directory? modelsDirectory,
    Directory? httpDirectory,
  })  : scanner = scanner ?? SpyYamlScanner(),
        modelsDirectory = SpyYamlScanner.resolveModelsDirectory(modelsDirectory),
        httpDirectory = HttpFileParser.resolveHttpDirectory(httpDirectory),
        endpointScanner = EndpointScanner(pod),
        endpointCaller = EndpointCaller(pod);

  /// Registers all VM service extensions with `dart:developer`.
  void register() {
    _registerSchemaExtensions();
    _registerEndpointExtensions();
  }

  void _registerSchemaExtensions() {
    // 1. getSchema
    Future<developer.ServiceExtensionResponse> handleGetSchema(String method, Map<String, String> parameters) async {
      try {
        final forceRefresh = parameters['forceRefresh'] == 'true';
        if (_cachedSchema == null || forceRefresh) {
          _cachedSchema = await _loadSchema();
        }

        return developer.ServiceExtensionResponse.result(
          jsonEncode(_cachedSchema!.toJson()),
        );
      } catch (e, st) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to load schema: $e\n$st',
        );
      }
    }

    _safeRegisterExtension(extGetSchema, handleGetSchema);
    _safeRegisterExtension(legacyExtGetSchema, handleGetSchema);

    // 2. getTableData
    Future<developer.ServiceExtensionResponse> handleGetTableData(String method, Map<String, String> parameters) async {
      Session? session;
      try {
        final tableName = parameters['table'];
        if (tableName == null || tableName.isEmpty) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required "table" parameter',
          );
        }

        final limit = int.tryParse(parameters['limit'] ?? '50') ?? 50;
        final offset = int.tryParse(parameters['offset'] ?? '0') ?? 0;
        final sortBy = parameters['sortBy'];
        final sortAscending = parameters['sortAscending'] != 'false';
        final searchQuery = parameters['search'];

        session = await pod.createSession();
        final dbAccessor = DatabaseDataAccessor(session.db);

        final page = await dbAccessor.fetchTableData(
          tableName: tableName,
          limit: limit,
          offset: offset,
          sortBy: sortBy,
          sortAscending: sortAscending,
          searchQuery: searchQuery,
        );

        return developer.ServiceExtensionResponse.result(
          jsonEncode(page.toJson()),
        );
      } catch (e, st) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to fetch table data: $e\n$st',
        );
      } finally {
        await session?.close();
      }
    }

    _safeRegisterExtension(extGetTableData, handleGetTableData);
    _safeRegisterExtension(legacyExtGetTableData, handleGetTableData);

    // 3. getDatabaseStats
    Future<developer.ServiceExtensionResponse> handleGetDatabaseStats(String method, Map<String, String> parameters) async {
      Session? session;
      try {
        session = await pod.createSession();
        final dbAccessor = DatabaseDataAccessor(session.db);
        final stats = await dbAccessor.fetchDatabaseStats();

        return developer.ServiceExtensionResponse.result(
          jsonEncode(stats),
        );
      } catch (e, st) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to fetch database stats: $e\n$st',
        );
      } finally {
        await session?.close();
      }
    }

    _safeRegisterExtension(extGetDatabaseStats, handleGetDatabaseStats);
    _safeRegisterExtension(legacyExtGetDatabaseStats, handleGetDatabaseStats);
  }

  void _registerEndpointExtensions() {
    // 4. getEndpoints
    Future<developer.ServiceExtensionResponse> handleGetEndpoints(String method, Map<String, String> parameters) async {
      try {
        final endpoints = endpointScanner.scanEndpoints();
        return developer.ServiceExtensionResponse.result(
          jsonEncode({
            'endpoints': endpoints.map((e) => e.toJson()).toList(),
          }),
        );
      } catch (e, st) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to scan endpoints: $e\n$st',
        );
      }
    }

    _safeRegisterExtension(extGetEndpoints, handleGetEndpoints);
    _safeRegisterExtension(legacyExtGetEndpoints, handleGetEndpoints);

    // 5. getHttpCollections
    Future<developer.ServiceExtensionResponse> handleGetHttpCollections(String method, Map<String, String> parameters) async {
      try {
        final collections = HttpFileParser.scanDirectory(httpDirectory);
        return developer.ServiceExtensionResponse.result(
          jsonEncode({
            'collections': collections.map((c) => c.toJson()).toList(),
          }),
        );
      } catch (e, st) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to scan .http files: $e\n$st',
        );
      }
    }

    _safeRegisterExtension(extGetHttpCollections, handleGetHttpCollections);
    _safeRegisterExtension(legacyExtGetHttpCollections, handleGetHttpCollections);

    // 6. invokeEndpoint
    Future<developer.ServiceExtensionResponse> handleInvokeEndpoint(String method, Map<String, String> parameters) async {
      try {
        final endpoint = parameters['endpoint'] ?? '';
        final methodName = parameters['method'] ?? '';
        final authToken = parameters['authToken'];
        final baseUrl = parameters['baseUrl'];
        final paramsJson = parameters['parameters'];

        Map<String, dynamic> paramsMap = {};
        if (paramsJson != null && paramsJson.isNotEmpty) {
          try {
            paramsMap = jsonDecode(paramsJson) as Map<String, dynamic>;
          } catch (_) {}
        }

        final result = await endpointCaller.invoke(
          endpoint: endpoint,
          method: methodName,
          parameters: paramsMap,
          authToken: authToken,
          baseUrl: baseUrl,
        );

        return developer.ServiceExtensionResponse.result(
          jsonEncode(result.toJson()),
        );
      } catch (e, st) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Endpoint invocation failed: $e\n$st',
        );
      }
    }

    _safeRegisterExtension(extInvokeEndpoint, handleInvokeEndpoint);
    _safeRegisterExtension(legacyExtInvokeEndpoint, handleInvokeEndpoint);

    // 7. saveHttpRequest
    Future<developer.ServiceExtensionResponse> handleSaveHttpRequest(String method, Map<String, String> parameters) async {
      try {
        final fileName = parameters['fileName'] ?? 'custom.http';
        final requestJson = parameters['request'];
        if (requestJson == null) {
          return developer.ServiceExtensionResponse.error(
            developer.ServiceExtensionResponse.invalidParams,
            'Missing required "request" parameter',
          );
        }

        final reqItem = HttpRequestItem.fromJson(jsonDecode(requestJson));
        final file = HttpFileWriter.saveRequestToFile(
          httpDirectory: httpDirectory,
          fileName: fileName,
          request: reqItem,
        );

        return developer.ServiceExtensionResponse.result(
          jsonEncode({
            'success': true,
            'filePath': file.path,
          }),
        );
      } catch (e, st) {
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          'Failed to save .http request: $e\n$st',
        );
      }
    }

    _safeRegisterExtension(extSaveHttpRequest, handleSaveHttpRequest);
    _safeRegisterExtension(legacyExtSaveHttpRequest, handleSaveHttpRequest);
  }

  void _safeRegisterExtension(String name, developer.ServiceExtensionHandler handler) {
    try {
      developer.registerExtension(name, handler);
      stdout.writeln('[ServerpodDevTools] Registered VM service extension: $name');
    } catch (e) {
      stdout.writeln('[ServerpodDevTools] Warning: Could not register $name: $e');
    }
  }

  Future<SchemaGraph> _loadSchema() async {
    stdout.writeln('[ServerpodDevTools] Scanning models directory: ${modelsDirectory.path}');
    var graph = await scanner.scanDirectory(modelsDirectory);
    if (graph.tables.isEmpty) {
      final altDir = Directory('lib/src');
      if (altDir.existsSync()) {
        stdout.writeln('[ServerpodDevTools] Models directory had 0 tables, scanning alt directory: ${altDir.path}');
        graph = await scanner.scanDirectory(altDir);
      }
    }
    stdout.writeln('[ServerpodDevTools] Discovered ${graph.tables.length} models/tables and ${graph.relations.length} relations.');

    Session? session;
    try {
      session = await pod.createSession();
      final dbAccessor = DatabaseDataAccessor(session.db);
      final stats = await dbAccessor.fetchDatabaseStats();

      final updatedTables = graph.tables.map((table) {
        final count = stats[table.tableName];
        if (count != null) {
          return table.copyWith(rowCount: count);
        }
        return table;
      }).toList();

      return graph.copyWith(tables: updatedTables);
    } catch (e) {
      stdout.writeln('[ServerpodDevTools] Database row count fetch skipped or failed: $e');
      return graph;
    } finally {
      await session?.close();
    }
  }
}
