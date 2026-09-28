/// Metadata model describing a Serverpod endpoint, its methods, and parameter signatures.
class EndpointMetadata {
  /// Name of the endpoint as registered in Serverpod (e.g. `'course'`, `'homework'`).
  final String name;

  /// Optional documentation or comment for the endpoint.
  final String? description;

  /// List of callable RPC methods registered on this endpoint.
  final List<MethodMetadata> methods;

  const EndpointMetadata({
    required this.name,
    this.description,
    this.methods = const [],
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    if (description != null) 'description': description,
    'methods': methods.map((m) => m.toJson()).toList(),
  };

  factory EndpointMetadata.fromJson(Map<String, dynamic> json) =>
      EndpointMetadata(
        name: json['name'] as String,
        description: json['description'] as String?,
        methods: (json['methods'] as List<dynamic>?)
                ?.map((m) => MethodMetadata.fromJson(m as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Metadata model describing a single callable method on an endpoint.
class MethodMetadata {
  /// Method identifier (e.g. `'createCourse'`, `'getSubmissions'`).
  final String name;

  /// Dart return type description (e.g. `'Future<List<HomeworkSubmission>>'`).
  final String returnType;

  /// Optional documentation string.
  final String? description;

  /// List of parameter signatures accepted by this method.
  final List<ParameterMetadata> parameters;

  const MethodMetadata({
    required this.name,
    required this.returnType,
    this.description,
    this.parameters = const [],
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'returnType': returnType,
    if (description != null) 'description': description,
    'parameters': parameters.map((p) => p.toJson()).toList(),
  };

  factory MethodMetadata.fromJson(Map<String, dynamic> json) => MethodMetadata(
    name: json['name'] as String,
    returnType: json['returnType'] as String? ?? 'dynamic',
    description: json['description'] as String?,
    parameters: (json['parameters'] as List<dynamic>?)
            ?.map((p) => ParameterMetadata.fromJson(p as Map<String, dynamic>))
            .toList() ??
        const [],
  );
}

/// Metadata model describing a single parameter of an endpoint method.
class ParameterMetadata {
  /// Parameter name (e.g. `'courseUuid'`, `'status'`).
  final String name;

  /// Dart type name (e.g. `'String'`, `'int'`, `'UuidValue'`, `'Course'`).
  final String type;

  /// Whether the parameter is nullable.
  final bool isNullable;

  /// Whether the parameter is a named argument.
  final bool isNamed;

  /// Default value as a string representation if present.
  final String? defaultValue;

  const ParameterMetadata({
    required this.name,
    required this.type,
    this.isNullable = false,
    this.isNamed = false,
    this.defaultValue,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type,
    'isNullable': isNullable,
    'isNamed': isNamed,
    if (defaultValue != null) 'defaultValue': defaultValue,
  };

  factory ParameterMetadata.fromJson(Map<String, dynamic> json) =>
      ParameterMetadata(
        name: json['name'] as String,
        type: json['type'] as String,
        isNullable: json['isNullable'] as bool? ?? false,
        isNamed: json['isNamed'] as bool? ?? false,
        defaultValue: json['defaultValue'] as String?,
      );
}
