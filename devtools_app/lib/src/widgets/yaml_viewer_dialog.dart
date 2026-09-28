import 'package:flutter/material.dart';
import '../schema_models.dart';

import '../controllers/canvas_controller.dart';

/// Dialog allowing developers to paste custom .spy.yaml text and instantly visualize it.
class YamlViewerDialog extends StatefulWidget {
  final CanvasController controller;

  const YamlViewerDialog({
    super.key,
    required this.controller,
  });

  static Future<void> show(BuildContext context, CanvasController controller) {
    return showDialog(
      context: context,
      builder: (ctx) => YamlViewerDialog(controller: controller),
    );
  }

  @override
  State<YamlViewerDialog> createState() => _YamlViewerDialogState();
}

class _YamlViewerDialogState extends State<YamlViewerDialog> {
  late final TextEditingController _textController;
  String? _statusMessage;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: _sampleYaml);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _visualize() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;

    try {
      final scanner = SpyYamlScanner();
      final graph = scanner.parseString(text);

      if (graph.tables.isEmpty) {
        setState(() {
          _isError = true;
          _statusMessage = 'No models with a "class:" or "table:" key found.';
        });
        return;
      }

      widget.controller.setGraph(graph);
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Visualized ${graph.tables.length} tables and ${graph.relations.length} relations!',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() {
        _isError = true;
        _statusMessage = 'Parse error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.code, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'YAML Schema Importer',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Paste one or more .spy.yaml definitions separated by "---", then tap Visualize.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _statusMessage!,
                style: TextStyle(
                  color: _isError ? Colors.red : Colors.green,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _textController.text = _sampleYaml,
                  child: const Text('Reset to Sample'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _visualize,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Visualize'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const String _sampleYaml = '''
class: Company
table: company
fields:
  uuid: UuidValue
  name: String
  foundedDate: DateTime?
indexes:
  company_uuid_idx:
    fields: uuid
    unique: true
---
class: Address
table: address
fields:
  street: String
  city: String
---
class: Employee
table: employee
fields:
  name: String
  company: Company?, relation(parent=company)
  address: Address?, relation(parent=address)
indexes:
  employee_address_unique_idx:
    fields: address
    unique: true
---
class: Project
table: project
fields:
  title: String
  lead: Employee?, relation(parent=employee)
''';
}
