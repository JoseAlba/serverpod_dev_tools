/// Represents a parsed HTTP variable declared in a `.http` file (e.g. `@baseUrl = http://localhost:8080`).
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
  /// Unique identifier within the collection (e.g. `'homework_gradeSubmission'`).
  final String id;

  /// Human-readable title from the comment block (e.g. `'3. Grade Homework Submission'`).
  final String title;

  /// HTTP method (e.g. `'POST'`, `'GET'`).
  final String method;

  /// Target URL or endpoint path (e.g. `'{{baseUrl}}/homework/gradeSubmission'`).
  final String url;

  /// Associated request headers.
  final Map<String, String> headers;

  /// Request body payload as string (typically JSON).
  final String? body;

  /// Optional endpoint name extracted from the path.
  final String? endpoint;

  /// Optional method name extracted from the path.
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

/// Represents a full `.http` file collection (e.g. `homework.http`, `course.http`).
class HttpFileCollection {
  /// File name (e.g. `'homework.http'`).
  final String fileName;

  /// Relative or absolute file path.
  final String filePath;

  /// File-level description or header comments.
  final String? description;

  /// Declared file-level variables (e.g. `@baseUrl`, `@submissionUuid`).
  final List<HttpVariable> variables;

  /// List of request blocks contained in this file.
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
