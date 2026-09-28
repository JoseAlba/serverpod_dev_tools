import 'package:devtools_extensions/devtools_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'src/controllers/canvas_controller.dart';
import 'src/services/devtools_schema_service.dart';
import 'src/widgets/endpoint_explorer_view.dart';
import 'src/widgets/er_canvas.dart';
import 'src/widgets/sidebar_panel.dart';
import 'src/widgets/yaml_viewer_dialog.dart';

void main() {
  runApp(const ServerpodDevToolsApp());
}

/// Root widget for the Serverpod DevTools Extension.
class ServerpodDevToolsApp extends StatelessWidget {
  const ServerpodDevToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DevToolsExtension(
      child: MaterialApp(
        title: 'Serverpod DevTools',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF5FD4C4),
        ),
        home: const ServerpodDevToolsMainScreen(),
      ),
    );
  }
}

class ServerpodDevToolsMainScreen extends StatefulWidget {
  const ServerpodDevToolsMainScreen({super.key});

  @override
  State<ServerpodDevToolsMainScreen> createState() => _ServerpodDevToolsMainScreenState();
}

class _ServerpodDevToolsMainScreenState extends State<ServerpodDevToolsMainScreen> {
  final _service = DevToolsSchemaService();
  final _controller = CanvasController();
  bool _isLoading = true;
  int _activeTabIndex = 0; // 0: Schema Canvas, 1: Endpoint Caller

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceUpdate);
    _loadSchema();
  }

  @override
  void dispose() {
    _service.removeListener(_onServiceUpdate);
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _loadSchema({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    final graph = await _service.fetchSchema(forceRefresh: forceRefresh);
    if (mounted) {
      _controller.setGraph(graph);
      setState(() => _isLoading = false);
    }
  }

  void _showConnectionSettingsDialog() {
    final initialUrl = _service.serverBaseUrl;
    final urlController = TextEditingController(text: initialUrl);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final theme = Theme.of(dialogCtx);
          final colorScheme = theme.colorScheme;
          final currentBaseUrl = urlController.text.trim();
          final isValidLocalhost = DevToolsSchemaService.isLocalhostUrl(currentBaseUrl);
          final links = _getServerpodLinks(isValidLocalhost ? currentBaseUrl : initialUrl);

          return AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            title: const Row(
              children: [
                Icon(Icons.tune, color: Color(0xFF5FD4C4), size: 22),
                SizedBox(width: 10),
                Text('Server Connection Settings', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SizedBox(
              width: 580,
              height: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Serverpod DevTools operates in Dual-Mode:\n'
                      '1. Direct VM Service RPC (if DevTools is attached to the Serverpod server VM).\n'
                      '2. HTTP REST Fallback (if DevTools is attached to the Flutter app or browser).',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Serverpod WebServer API URL',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: urlController,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: InputDecoration(
                        hintText: 'http://localhost:8082/serverpod_dev_tools/api',
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        filled: true,
                        fillColor: Colors.black26,
                        errorText: (!isValidLocalhost && currentBaseUrl.isNotEmpty)
                            ? 'Security Restriction: DevTools only permits connections to localhost or 127.0.0.1'
                            : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('Port 8082 (Default)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              urlController.text = 'http://localhost:8082/serverpod_dev_tools/api';
                            });
                          },
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          label: const Text('Port 8080 (API)', style: TextStyle(fontSize: 11)),
                          onPressed: () {
                            setDialogState(() {
                              urlController.text = 'http://localhost:8080/serverpod_dev_tools/api';
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Row(
                      children: [
                        Icon(Icons.link_rounded, size: 16, color: Color(0xFF5FD4C4)),
                        SizedBox(width: 8),
                        Text(
                          'Active Serverpod URLs & Endpoints',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Click any URL or the open icon to launch in a new browser tab:',
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    for (final link in links)
                      _ServerpodUrlCard(
                        link: link,
                        onOpen: () => _launchExternalUrl(dialogCtx, link.url),
                        onCopy: () => _copyUrlToClipboard(dialogCtx, link.url),
                      ),
                    if (_service.serverVmServiceUri != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF34D399)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Server VM Service Discovered:',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                                  ),
                                  SelectableText(
                                    _service.serverVmServiceUri!,
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.white70),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 16),
                              tooltip: 'Copy VM Service URI',
                              onPressed: () => _copyUrlToClipboard(dialogCtx, _service.serverVmServiceUri!),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.white54),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Server VM Service URI is saved in:\n'
                              'studio_server/.dart_tool/serverpod/vm-service-info.pod.json',
                              style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Save & Reconnect'),
                onPressed: isValidLocalhost
                    ? () {
                        Navigator.of(ctx).pop();
                        _service.setServerBaseUrl(urlController.text.trim());
                        _loadSchema(forceRefresh: true);
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConnectionBadge() {
    final mode = _service.connectionMode;
    final (label, tooltip, color, icon) = switch (mode) {
      DevToolsConnectionMode.vmService => (
        'VM Service${_service.lastLatencyMs != null ? ' (${_service.lastLatencyMs}ms)' : ''}',
        'Connected directly to Serverpod server VM Service RPC',
        Colors.greenAccent,
        Icons.hub,
      ),
      DevToolsConnectionMode.httpRest => (
        'HTTP REST${_service.lastLatencyMs != null ? ' (${_service.lastLatencyMs}ms)' : ''}',
        'Connected via HTTP REST (Companion App Mode attached to Flutter client)',
        const Color(0xFF5FD4C4),
        Icons.language,
      ),
      DevToolsConnectionMode.disconnected => (
        'Disconnected',
        'Not connected. Click to inspect connection settings and URLs.',
        Colors.amberAccent,
        Icons.cloud_off,
      ),
    };

    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _showConnectionSettingsDialog,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isConnected = _service.isConnected;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF181825),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              const Icon(Icons.hub, color: Color(0xFF5FD4C4), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Serverpod DevTools',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(width: 32),
              SegmentedButton<int>(
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.schema, size: 16),
                    label: Text('Schema Canvas'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.flash_on, size: 16),
                    label: Text('Endpoint Caller'),
                  ),
                ],
                selected: {_activeTabIndex},
                onSelectionChanged: (val) {
                  setState(() => _activeTabIndex = val.first);
                },
              ),
              const Spacer(),
              _buildConnectionBadge(),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.tune, size: 18),
                tooltip: 'Server Connection Settings',
                onPressed: _showConnectionSettingsDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh Schema & Data',
                onPressed: () => _loadSchema(forceRefresh: true),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (!isConnected || _service.lastError != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade900.withValues(alpha: 0.25),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _service.lastError ??
                          'Not connected to Serverpod. Ensure Serverpod is running and reachable via VM Service or HTTP REST.',
                      style: const TextStyle(fontSize: 12, color: Colors.amberAccent),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showConnectionSettingsDialog,
                    icon: const Icon(Icons.tune, size: 14),
                    label: const Text('Settings', style: TextStyle(fontSize: 12)),
                  ),
                  TextButton.icon(
                    onPressed: () => _loadSchema(forceRefresh: true),
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text('Retry', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : IndexedStack(
                    index: _activeTabIndex,
                    children: [
                      // Tab 0: Schema Canvas
                      ListenableBuilder(
                        listenable: _controller,
                        builder: (context, _) {
                          return Row(
                            children: [
                              SidebarPanel(
                                controller: _controller,
                                service: _service,
                                onRefresh: () => _loadSchema(forceRefresh: true),
                                onOpenYamlViewer: () =>
                                    YamlViewerDialog.show(context, _controller),
                              ),
                              Expanded(
                                child: ERCanvas(
                                  controller: _controller,
                                  service: _service,
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      // Tab 1: Endpoint Explorer & Caller (.http)
                      EndpointExplorerView(service: _service),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Metadata model for an active Serverpod endpoint or web URL.
class _ServerpodEndpointLink {
  final String label;
  final String category;
  final String url;
  final String description;
  final IconData icon;

  const _ServerpodEndpointLink({
    required this.label,
    required this.category,
    required this.url,
    required this.description,
    required this.icon,
  });
}

/// Compact card rendering a clickable Serverpod URL with badge, open, and copy actions.
class _ServerpodUrlCard extends StatelessWidget {
  final _ServerpodEndpointLink link;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  const _ServerpodUrlCard({
    required this.link,
    required this.onOpen,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          _ServerpodCategoryBadge(category: link.category),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(link.icon, size: 14, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      link.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                InkWell(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(4),
                  child: Text(
                    link.url,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  link.description,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new, size: 16),
            tooltip: 'Open in new browser tab',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: onOpen,
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 16),
            tooltip: 'Copy URL to clipboard',
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

/// Category badge styling for HTTP methods and resource types.
class _ServerpodCategoryBadge extends StatelessWidget {
  final String category;

  const _ServerpodCategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final color = switch (category) {
      'GET' => const Color(0xFF60A5FA),
      'POST' => const Color(0xFF34D399),
      'REST' => const Color(0xFFA78BFA),
      'APP' => const Color(0xFFFBBF24),
      'CONFIG' => const Color(0xFFF472B6),
      'API' => const Color(0xFF38BDF8),
      _ => const Color(0xFF9CA3AF),
    };

    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Computes the list of active Serverpod endpoints dynamically from the active base URL.
List<_ServerpodEndpointLink> _getServerpodLinks(String baseUrlText) {
  final parsed = Uri.tryParse(baseUrlText) ?? Uri.parse('http://localhost:8082/serverpod_dev_tools/api');
  final scheme = parsed.scheme.isNotEmpty ? parsed.scheme : 'http';
  final rawHost = parsed.host.isNotEmpty ? parsed.host.toLowerCase() : 'localhost';
  final host = (rawHost == '127.0.0.1' || rawHost == '::1' || rawHost == 'localhost') ? rawHost : 'localhost';
  final webPort = parsed.hasPort ? parsed.port : 8082;
  const apiPort = 8080;

  final webBase = '$scheme://$host:$webPort';
  final apiBase = '$scheme://$host:$apiPort';
  final devToolsApi = '$webBase/serverpod_dev_tools/api';

  return [
    _ServerpodEndpointLink(
      label: 'DevTools REST API Root',
      category: 'REST',
      url: devToolsApi,
      description: 'DevTools Suite REST API base URL',
      icon: Icons.api_outlined,
    ),
    _ServerpodEndpointLink(
      label: 'Schema Graph JSON',
      category: 'GET',
      url: '$devToolsApi/schema',
      description: 'Full database models and relationship graph JSON',
      icon: Icons.schema_outlined,
    ),
    _ServerpodEndpointLink(
      label: 'RPC Endpoints & Methods',
      category: 'GET',
      url: '$devToolsApi/endpoints',
      description: 'Discovered Serverpod endpoints and parameter metadata',
      icon: Icons.code_rounded,
    ),
    _ServerpodEndpointLink(
      label: 'HTTP Workspace Collections',
      category: 'GET',
      url: '$devToolsApi/http',
      description: 'Scanned .http files and request collections',
      icon: Icons.http_rounded,
    ),
    _ServerpodEndpointLink(
      label: 'Database Row Statistics',
      category: 'GET',
      url: '$devToolsApi/stats',
      description: 'Live PostgreSQL row counts and table stats',
      icon: Icons.table_rows_outlined,
    ),
    _ServerpodEndpointLink(
      label: 'Endpoint Invoke Gateway',
      category: 'POST',
      url: '$devToolsApi/invoke',
      description: 'HTTP POST gateway for executing Serverpod RPCs',
      icon: Icons.play_arrow_outlined,
    ),
    _ServerpodEndpointLink(
      label: 'Serverpod Web Server Root',
      category: 'WEB',
      url: '$webBase/',
      description: 'Default Serverpod web server home page',
      icon: Icons.language_outlined,
    ),
    _ServerpodEndpointLink(
      label: 'Teacher Studio Web App',
      category: 'APP',
      url: '$webBase/app',
      description: 'Hosted Flutter Web Teacher Studio application',
      icon: Icons.dashboard_outlined,
    ),
    _ServerpodEndpointLink(
      label: 'Frontend Runtime Config',
      category: 'CONFIG',
      url: '$webBase/app/assets/assets/config.json',
      description: 'Dynamic AppConfig JSON served to client',
      icon: Icons.settings_ethernet_outlined,
    ),
    _ServerpodEndpointLink(
      label: 'Serverpod API Server (RPC)',
      category: 'API',
      url: '$apiBase/',
      description: 'Main binary/JSON Serverpod RPC port',
      icon: Icons.dns_outlined,
    ),
  ];
}

/// Opens the given URL in a new browser tab.
Future<void> _launchExternalUrl(BuildContext context, String url) async {
  try {
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url in browser')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening $url: $e')),
      );
    }
  }
}

/// Copies the given URL string to the system clipboard and provides user feedback.
void _copyUrlToClipboard(BuildContext context, String url) {
  Clipboard.setData(ClipboardData(text: url));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Copied to clipboard: $url'),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

