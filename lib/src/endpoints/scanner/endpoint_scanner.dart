import 'package:serverpod/serverpod.dart';

import '../models/endpoint_metadata.dart';

/// Introspects a running [Serverpod] instance's registered endpoints, methods, and parameters.
///
/// This is completely generic and works with ANY Serverpod server by reading
/// [server.endpoints.connectors].
class EndpointScanner {
  final Serverpod pod;

  const EndpointScanner(this.pod);

  /// Scans and returns all registered endpoints with their callable methods and parameters.
  List<EndpointMetadata> scanEndpoints() {
    final connectors = pod.server.endpoints.connectors;
    final result = <EndpointMetadata>[];

    for (final entry in connectors.entries) {
      final endpointName = entry.key;
      final connector = entry.value;

      final methods = <MethodMetadata>[];

      for (final methodEntry in connector.methodConnectors.entries) {
        final methodName = methodEntry.key;
        final methodConnector = methodEntry.value;

        final params = <ParameterMetadata>[];
        for (final paramEntry in methodConnector.params.entries) {
          final paramName = paramEntry.key;
          final paramDesc = paramEntry.value;

          final typeStr = paramDesc.type.toString();
          final isNullable = paramDesc.nullable;

          params.add(
            ParameterMetadata(
              name: paramName,
              type: typeStr,
              isNullable: isNullable,
              isNamed: true,
            ),
          );
        }

        methods.add(
          MethodMetadata(
            name: methodName,
            returnType: 'Future<dynamic>',
            parameters: params,
          ),
        );
      }

      // Sort methods alphabetically for clean UI presentation
      methods.sort((a, b) => a.name.compareTo(b.name));

      result.add(
        EndpointMetadata(
          name: endpointName,
          methods: methods,
        ),
      );
    }

    // Sort endpoints alphabetically
    result.sort((a, b) => a.name.compareTo(b.name));
    return result;
  }
}
