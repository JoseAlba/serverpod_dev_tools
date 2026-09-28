/// Represents a parsed HTTP variable declared in a `.http` file.
class HttpVariable {
  final String name;
  final String value;

  const HttpVariable({required this.name, required this.value});

  Map<String, dynamic> toJson() => {'name': name, 'value': value};

  factory HttpVariable.fromJson(Map<String, dynamic> json) => HttpVariable(
    name: json['name'] as String,
    value: json['value'] as String,
  );
}

/// Represents a single runnable request item inside a `.http` file.
class HttpRequestItem {
  final String id;
  final String title;
  final String method;
  final String url;
  final Map<String, String> headers;
  final String? body;
  final String? endpoint;
  final String? methodName;

  const HttpRequestItem({
    required this.id,
    required this.title,
    required this.method,
    required this.url,
    this.headers = const {},
    this.body,
    this.endpoint,
    this.methodName,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'method': method,
    'url': url,
    'headers': headers,
    if (body != null) 'body': body,
    if (endpoint != null) 'endpoint': endpoint,
    if (methodName != null) 'methodName': methodName,
  };

  factory HttpRequestItem.fromJson(Map<String, dynamic> json) =>
      HttpRequestItem(
        id: json['id'] as String,
        title: json['title'] as String,
        method: json['method'] as String,
        url: json['url'] as String,
        headers: (json['headers'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            const {},
        body: json['body'] as String?,
        endpoint: json['endpoint'] as String?,
        methodName: json['methodName'] as String?,
      );
}

/// Represents a full `.http` file collection.
class HttpFileCollection {
  final String fileName;
  final String filePath;
  final String? description;
  final List<HttpVariable> variables;
  final List<HttpRequestItem> requests;

  const HttpFileCollection({
    required this.fileName,
    required this.filePath,
    this.description,
    this.variables = const [],
    this.requests = const [],
  });

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'filePath': filePath,
    if (description != null) 'description': description,
    'variables': variables.map((v) => v.toJson()).toList(),
    'requests': requests.map((r) => r.toJson()).toList(),
  };

  factory HttpFileCollection.fromJson(Map<String, dynamic> json) =>
      HttpFileCollection(
        fileName: json['fileName'] as String,
        filePath: json['filePath'] as String,
        description: json['description'] as String?,
        variables: (json['variables'] as List<dynamic>?)
                ?.map((v) => HttpVariable.fromJson(v as Map<String, dynamic>))
                .toList() ??
            const [],
        requests: (json['requests'] as List<dynamic>?)
                ?.map((r) => HttpRequestItem.fromJson(r as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Execution result of invoking an endpoint or HTTP request.
class HttpInvocationResult {
  final int statusCode;
  final String statusText;
  final int durationMs;
  final Map<String, String> headers;
  final dynamic body;
  final String? rawResponse;
  final String? error;

  const HttpInvocationResult({
    required this.statusCode,
    required this.statusText,
    required this.durationMs,
    this.headers = const {},
    this.body,
    this.rawResponse,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'statusCode': statusCode,
    'statusText': statusText,
    'durationMs': durationMs,
    'headers': headers,
    'body': body,
    if (rawResponse != null) 'rawResponse': rawResponse,
    if (error != null) 'error': error,
  };

  factory HttpInvocationResult.fromJson(Map<String, dynamic> json) =>
      HttpInvocationResult(
        statusCode: json['statusCode'] as int? ?? 200,
        statusText: json['statusText'] as String? ?? 'OK',
        durationMs: json['durationMs'] as int? ?? 0,
        headers: (json['headers'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            const {},
        body: json['body'],
        rawResponse: json['rawResponse'] as String?,
        error: json['error'] as String?,
      );
}
