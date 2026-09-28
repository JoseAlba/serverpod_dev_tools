import 'dart:io';
import 'package:serverpod/serverpod.dart';

import 'src/routes/schema_visualizer_route.dart';
import 'src/service/schema_service_extension.dart';

// Database & Core Models
export 'src/database/database_data_accessor.dart';
export 'src/models/field_node.dart';
export 'src/models/index_node.dart';
export 'src/models/relation_edge.dart';
export 'src/models/schema_graph.dart';
export 'src/models/table_data_page.dart';
export 'src/models/table_node.dart';

// Schema Parsers
export 'src/parser/relation_resolver.dart';
export 'src/parser/spy_yaml_parser.dart';
export 'src/parser/spy_yaml_scanner.dart';

// Endpoints & .http Workspace Suite
export 'src/endpoints/caller/endpoint_caller.dart';
export 'src/endpoints/models/endpoint_metadata.dart';
export 'src/endpoints/models/http_request_item.dart';
export 'src/endpoints/scanner/endpoint_scanner.dart';
export 'src/endpoints/scanner/http_file_parser.dart';
export 'src/endpoints/scanner/http_file_writer.dart';

// Mock Data Generator & Seeder
export 'src/mock/mock_data_generator.dart';
export 'src/mock/mock_value_inferer.dart';
export 'src/mock/topological_sorter.dart';

// Web Routes & VM Service Extensions
export 'src/routes/schema_visualizer_route.dart';
export 'src/service/schema_service_extension.dart';

/// Entry point to initialize and enable the Serverpod DevTools suite.
class ServerpodDevTools {
  static SchemaServiceExtension? _serviceExtension;

  /// Whether Serverpod DevTools has been initialized.
  static bool get isEnabled => _serviceExtension != null;

  /// Initializes Serverpod DevTools on the running [Serverpod] instance.
  ///
  /// This registers Dart VM Service extensions for Dart DevTools:
  /// - `ext.serverpod_dev_tools.getSchema`
  /// - `ext.serverpod_dev_tools.getTableData`
  /// - `ext.serverpod_dev_tools.getDatabaseStats`
  /// - `ext.serverpod_dev_tools.getEndpoints`
  /// - `ext.serverpod_dev_tools.getHttpCollections`
  /// - `ext.serverpod_dev_tools.invokeEndpoint`
  /// - `ext.serverpod_dev_tools.saveHttpRequest`
  /// - `ext.serverpod_dev_tools.generateMockData`
  /// - `ext.serverpod_dev_tools.getDependencyOrder`
  ///
  /// If [enableWebRoute] is true, also registers HTTP REST routes under
  /// `[webRoutePath]/api/**` on [pod.webServer].
  ///
  /// **Security Notice**:
  /// By default, DevTools is automatically DISABLED in release mode
  /// (`dart.vm.product`) and in production/staging environments
  /// (`pod.runMode == 'production' || pod.runMode == 'staging'`).
  /// Pass [forceEnable] = `true` only if explicitly required for testing.
  static void initialize(
    Serverpod pod, {
    Directory? modelsDirectory,
    Directory? httpDirectory,
    bool enableWebRoute = true,
    String webRoutePath = '/serverpod_dev_tools',
    bool forceEnable = false,
  }) {
    // 1. Check Dart VM release mode
    const isReleaseMode = bool.fromEnvironment('dart.vm.product');

    // 2. Check Serverpod run mode (production / staging)
    final isProduction = pod.runMode == ServerpodRunMode.production ||
        pod.runMode == 'production' ||
        pod.runMode == ServerpodRunMode.staging ||
        pod.runMode == 'staging';

    final isForceEnabled = forceEnable == true;
    if (!isForceEnabled && (isReleaseMode || isProduction)) {
      stdout.writeln(
        '[ServerpodDevTools] Skipped initialization: Serverpod DevTools is disabled in release/production mode for security.',
      );
      return;
    }

    _serviceExtension = SchemaServiceExtension(
      pod: pod,
      modelsDirectory: modelsDirectory,
      httpDirectory: httpDirectory,
    );
    _serviceExtension!.register();
    stdout.writeln(
      '[ServerpodDevTools] Initialized successfully.\n'
      '  Models directory: ${_serviceExtension!.modelsDirectory.path}\n'
      '  HTTP directory: ${_serviceExtension!.httpDirectory.path}',
    );

    if (enableWebRoute) {
      final route = ServerpodDevToolsRoute(
        pod: pod,
        modelsDirectory: modelsDirectory,
        httpDirectory: httpDirectory,
        forceEnable: isForceEnabled,
      );
      pod.webServer.addRoute(route, '$webRoutePath/api');
      pod.webServer.addRoute(route, '$webRoutePath/api/**');
      stdout.writeln(
        '  DevTools HTTP REST API: http://localhost:${pod.config.webServer?.port ?? 8082}$webRoutePath/api\n'
        '  Server VM Service URI: .dart_tool/serverpod/vm-service-info.pod.json',
      );
    }
  }
}

/// Backwards compatibility alias for [ServerpodDevTools].
typedef ServerpodSchemaVisualizer = ServerpodDevTools;
