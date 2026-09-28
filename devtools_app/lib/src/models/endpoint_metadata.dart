/// Metadata model describing a Serverpod endpoint, its methods, and parameter signatures.
class EndpointMetadata {
  final String name;
  final String? description;
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
  final String name;
  final String returnType;
  final String? description;
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
  final String name;
  final String type;
  final bool isNullable;
  final bool isNamed;
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
