import 'package:flutter/material.dart';

class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({super.key, required this.title, required this.label, this.initial});

  final String title;
  final String label;
  final String? initial;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Valider'),
        ),
      ],
    );
  }
}

Future<String?> askText(BuildContext context, String title, String label, {String? initial}) {
  return showDialog<String>(
    context: context,
    builder: (context) => TextPromptDialog(title: title, label: label, initial: initial),
  );
}
