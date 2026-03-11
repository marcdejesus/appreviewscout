import 'package:flutter/material.dart';

class AddAppDialog extends StatefulWidget {
  const AddAppDialog({super.key});

  @override
  State<AddAppDialog> createState() => _AddAppDialogState();
}

class _AddAppDialogState extends State<AddAppDialog> {
  final _controller = TextEditingController();
  bool _downloadScreenshots = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Play Store App'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Play Store URL',
              hintText: 'https://play.google.com/store/apps/details?id=...',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _downloadScreenshots,
            title: const Text('Download screenshots'),
            onChanged: (value) => setState(() => _downloadScreenshots = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _AddAppDialogResult(
                url: _controller.text.trim(),
                downloadScreenshots: _downloadScreenshots,
              ),
            );
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _AddAppDialogResult {
  const _AddAppDialogResult({
    required this.url,
    required this.downloadScreenshots,
  });

  final String url;
  final bool downloadScreenshots;
}

Future<(String, bool)?> showAddAppDialog(BuildContext context) async {
  final result = await showDialog<_AddAppDialogResult>(
    context: context,
    builder: (_) => const AddAppDialog(),
  );
  if (result == null || result.url.isEmpty) {
    return null;
  }
  return (result.url, result.downloadScreenshots);
}
