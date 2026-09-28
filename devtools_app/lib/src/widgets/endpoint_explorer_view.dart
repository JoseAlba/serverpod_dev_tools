import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/endpoint_metadata.dart';
import '../models/http_request_item.dart';
import '../services/devtools_schema_service.dart';

/// Interactive Endpoint Explorer & Caller panel with .http file integration.
class EndpointExplorerView extends StatefulWidget {
  final DevToolsSchemaService service;

  const EndpointExplorerView({super.key, required this.service});

  @override
  State<EndpointExplorerView> createState() => _EndpointExplorerViewState();
}

class _EndpointExplorerViewState extends State<EndpointExplorerView> {
  bool _isLoading = true;
  List<EndpointMetadata> _endpoints = [];
  List<HttpFileCollection> _collections = [];

  EndpointMetadata? _selectedEndpoint;
  MethodMetadata? _selectedMethod;
  HttpRequestItem? _selectedHttpItem;

  final Map<String, TextEditingController> _paramControllers = {};
  final TextEditingController _rawJsonController = TextEditingController();
  final TextEditingController _authController = TextEditingController();
  final TextEditingController _saveFileNameController = TextEditingController(text: 'custom.http');
  final TextEditingController _saveTitleController = TextEditingController();

  bool _isRawJsonMode = false;
  bool _isExecuting = false;
  HttpInvocationResult? _lastResult;

  @override
  void initState() {
    super.initState();
    widget.service.addListener(_onServiceChanged);
    _loadData();
  }

  @override
  void dispose() {
    widget.service.removeListener(_onServiceChanged);
    _rawJsonController.dispose();
    _authController.dispose();
    _saveFileNameController.dispose();
    _saveTitleController.dispose();
    for (final c in _paramControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onServiceChanged() {
    if (mounted && (_endpoints.isEmpty || widget.service.isConnected)) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final endpoints = await widget.service.fetchEndpoints();
    final collections = await widget.service.fetchHttpCollections();

    if (mounted) {
      setState(() {
        _endpoints = endpoints;
        _collections = collections;
        _isLoading = false;

        // Auto-select first method or first http request
        if (_endpoints.isNotEmpty && _endpoints.first.methods.isNotEmpty) {
          _selectMethod(_endpoints.first, _endpoints.first.methods.first);
        } else if (_collections.isNotEmpty && _collections.first.requests.isNotEmpty) {
          _selectHttpItem(_collections.first.requests.first);
        }
      });
    }
  }

  void _selectMethod(EndpointMetadata endpoint, MethodMetadata method) {
    setState(() {
      _selectedEndpoint = endpoint;
      _selectedMethod = method;
      _selectedHttpItem = null;
      _lastResult = null;

      // Reset parameter controllers
      _paramControllers.clear();
      for (final param in method.parameters) {
        _paramControllers[param.name] = TextEditingController(text: param.defaultValue ?? '');
      }

      _updateRawJson();
      _saveTitleController.text = '${method.name} Test';
    });
  }

  void _selectHttpItem(HttpRequestItem item) {
    setState(() {
      _selectedHttpItem = item;
      _selectedEndpoint = null;
      _selectedMethod = null;
      _lastResult = null;

      _isRawJsonMode = true;
      _rawJsonController.text = item.body ?? '{}';
      _saveTitleController.text = item.title;
    });
  }

  void _updateRawJson() {
    final map = <String, dynamic>{};
    _paramControllers.forEach((key, controller) {
      if (controller.text.isNotEmpty) {
        final val = controller.text;
        if (num.tryParse(val) != null) {
          map[key] = num.parse(val);
        } else if (val == 'true' || val == 'false') {
          map[key] = val == 'true';
        } else {
          map[key] = val;
        }
      }
    });
    _rawJsonController.text = const JsonEncoder.withIndent('  ').convert(map);
  }

  Future<void> _executeCall() async {
    setState(() => _isExecuting = true);

    Map<String, dynamic> params = {};
    if (_isRawJsonMode) {
      try {
        if (_rawJsonController.text.trim().isNotEmpty) {
          params = jsonDecode(_rawJsonController.text) as Map<String, dynamic>;
        }
      } catch (e) {
        setState(() {
          _isExecuting = false;
          _lastResult = HttpInvocationResult(
            statusCode: 400,
            statusText: 'Invalid JSON',
            durationMs: 0,
            error: 'Failed to parse JSON body: $e',
          );
        });
        return;
      }
    } else {
      _paramControllers.forEach((k, v) {
        if (v.text.isNotEmpty) {
          final val = v.text;
          if (num.tryParse(val) != null) {
            params[k] = num.parse(val);
          } else if (val == 'true' || val == 'false') {
            params[k] = val == 'true';
          } else {
            params[k] = val;
          }
        }
      });
    }

    final endpointName = _selectedEndpoint?.name ?? _selectedHttpItem?.endpoint ?? 'endpoint';
    final methodName = _selectedMethod?.name ?? _selectedHttpItem?.methodName ?? 'method';

    final result = await widget.service.invokeEndpoint(
      endpoint: endpointName,
      method: methodName,
      parameters: params,
      authToken: _authController.text.trim().isNotEmpty ? _authController.text.trim() : null,
    );

    if (mounted) {
      setState(() {
        _isExecuting = false;
        _lastResult = result;
      });
    }
  }

  Future<void> _saveAsHttp() async {
    final title = _saveTitleController.text.trim().isNotEmpty
        ? _saveTitleController.text.trim()
        : 'Request ${_selectedMethod?.name ?? 'Test'}';
    final fileName = _saveFileNameController.text.trim().isNotEmpty
        ? _saveFileNameController.text.trim()
        : 'custom.http';

    final endpointName = _selectedEndpoint?.name ?? _selectedHttpItem?.endpoint ?? 'endpoint';
    final methodName = _selectedMethod?.name ?? _selectedHttpItem?.methodName ?? 'method';

    final reqItem = HttpRequestItem(
      id: '${endpointName}_$methodName',
      title: title,
      method: 'POST',
      url: '{{baseUrl}}/$endpointName/$methodName',
      headers: {'Content-Type': 'application/json'},
      body: _rawJsonController.text.trim().isNotEmpty ? _rawJsonController.text.trim() : null,
      endpoint: endpointName,
      methodName: methodName,
    );

    final success = await widget.service.saveHttpRequest(
      fileName: fileName,
      request: reqItem,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Saved to $fileName successfully!' : 'Failed to save to $fileName',
          ),
          backgroundColor: success ? Colors.teal : Colors.red,
        ),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Row(
      children: [
        // Left Column: Tree of .http Files and Endpoints
        SizedBox(
          width: 300,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSidebarHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      if (_collections.isEmpty && _endpoints.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.cloud_off, size: 36, color: Colors.white24),
                              const SizedBox(height: 12),
                              const Text(
                                'No endpoints found',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Check that Serverpod is running and reachable.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5)),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.refresh, size: 14),
                                label: const Text('Scan Endpoints', style: TextStyle(fontSize: 12)),
                                onPressed: _loadData,
                              ),
                            ],
                          ),
                        )
                      else ...[
                        if (_collections.isNotEmpty) ...[
                          _buildSectionHeader('SAVED .HTTP COLLECTIONS (${_collections.length})'),
                          for (final col in _collections) _buildCollectionTile(col),
                          const Divider(height: 24),
                        ],
                        _buildSectionHeader('SERVERPOD ENDPOINTS (${_endpoints.length})'),
                        for (final ep in _endpoints) _buildEndpointTile(ep),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Center Column: Request Builder & Typed Parameter Form
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFF181825),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRequestHeaderBar(),
                const SizedBox(height: 16),
                _buildAuthAndConfigBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: _isRawJsonMode ? _buildRawJsonEditor() : _buildTypedParamForm(),
                ),
                const SizedBox(height: 12),
                _buildActionBar(),
              ],
            ),
          ),
        ),

        // Right Column: Response Console
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF11111B),
              border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            padding: const EdgeInsets.all(20),
            child: _buildResponseConsole(),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: Color(0xFF5FD4C4), size: 20),
          const SizedBox(width: 8),
          const Text(
            'Endpoint Explorer',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Reload endpoints & .http files',
            onPressed: _loadData,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildCollectionTile(HttpFileCollection col) {
    return ExpansionTile(
      leading: const Icon(Icons.description, size: 16, color: Color(0xFFF9E2AF)),
      title: Text(col.fileName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      children: [
        for (final req in col.requests)
          ListTile(
            dense: true,
            selected: _selectedHttpItem?.id == req.id,
            selectedTileColor: const Color(0xFF5FD4C4).withValues(alpha: 0.12),
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                req.method,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.tealAccent),
              ),
            ),
            title: Text(req.title, style: const TextStyle(fontSize: 11)),
            onTap: () => _selectHttpItem(req),
          ),
      ],
    );
  }

  Widget _buildEndpointTile(EndpointMetadata ep) {
    final isExpanded = _selectedEndpoint?.name == ep.name;
    return ExpansionTile(
      initiallyExpanded: isExpanded,
      leading: const Icon(Icons.dns, size: 16, color: Color(0xFF89B4FA)),
      title: Text(ep.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      children: [
        for (final method in ep.methods)
          ListTile(
            dense: true,
            selected: _selectedEndpoint?.name == ep.name && _selectedMethod?.name == method.name,
            selectedTileColor: const Color(0xFF5FD4C4).withValues(alpha: 0.12),
            leading: const Icon(Icons.play_circle_outline, size: 14, color: Color(0xFF5FD4C4)),
            title: Text(method.name, style: const TextStyle(fontSize: 12)),
            subtitle: Text(
              '${method.parameters.length} params',
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4)),
            ),
            onTap: () => _selectMethod(ep, method),
          ),
      ],
    );
  }

  Widget _buildRequestHeaderBar() {
    final method = _selectedMethod?.name ?? _selectedHttpItem?.methodName ?? 'Method';
    final endpoint = _selectedEndpoint?.name ?? _selectedHttpItem?.endpoint ?? 'Endpoint';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
          ),
          child: const Text('POST', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.tealAccent)),
        ),
        const SizedBox(width: 12),
        Text(
          '/$endpoint/$method',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
        ),
        const Spacer(),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Form')),
            ButtonSegment(value: true, label: Text('Raw JSON')),
          ],
          selected: {_isRawJsonMode},
          onSelectionChanged: (val) {
            setState(() {
              _isRawJsonMode = val.first;
              if (_isRawJsonMode) _updateRawJson();
            });
          },
        ),
      ],
    );
  }

  Widget _buildAuthAndConfigBar() {
    return TextField(
      controller: _authController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.lock_outline, size: 16),
        labelText: 'Bearer / Session Token (Optional)',
        hintText: 'Paste JWT or authentication token for authorized endpoints',
        isDense: true,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildTypedParamForm() {
    final params = _selectedMethod?.parameters ?? [];

    if (params.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 36, color: Colors.white.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Text(
              'This endpoint method accepts no parameters.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        for (final p in params)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        '${p.type}${p.isNullable ? '?' : ''}',
                        style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.4), fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _paramControllers[p.name],
                    decoration: InputDecoration(
                      hintText: 'Enter ${p.type} value',
                      isDense: true,
                      filled: true,
                      fillColor: Colors.black.withValues(alpha: 0.2),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (_) => _updateRawJson(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRawJsonEditor() {
    return TextField(
      controller: _rawJsonController,
      maxLines: null,
      expands: true,
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      decoration: InputDecoration(
        hintText: '{\n  "key": "value"\n}',
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.25),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildActionBar() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _isExecuting ? null : _executeCall,
          icon: _isExecuting
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.play_arrow),
          label: Text(_isExecuting ? 'Calling...' : 'Execute Request 🚀'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5FD4C4),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _showSaveDialog,
          icon: const Icon(Icons.bookmark_add_outlined, size: 16),
          label: const Text('Save to .http'),
        ),
      ],
    );
  }

  void _showSaveDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Request to .http File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _saveFileNameController,
              decoration: const InputDecoration(
                labelText: 'Target File Name',
                hintText: 'course.http',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _saveTitleController,
              decoration: const InputDecoration(
                labelText: 'Request Title',
                hintText: '5. Custom Course Query',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _saveAsHttp();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseConsole() {
    if (_lastResult == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.terminal, size: 40, color: Colors.white.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              'Execute a request to view live Serverpod responses.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            ),
          ],
        ),
      );
    }

    final res = _lastResult!;
    final isSuccess = res.statusCode >= 200 && res.statusCode < 300;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSuccess ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: isSuccess ? Colors.green : Colors.red),
              ),
              child: Text(
                '${res.statusCode} ${res.statusText}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSuccess ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${res.durationMs} ms', style: const TextStyle(fontSize: 12)),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              tooltip: 'Copy JSON Response',
              onPressed: () {
                final text = res.rawResponse ?? jsonEncode(res.body);
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Response copied to clipboard!')),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('RESPONSE BODY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                res.rawResponse ?? (res.body != null ? const JsonEncoder.withIndent('  ').convert(res.body) : res.error ?? 'Empty response'),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
