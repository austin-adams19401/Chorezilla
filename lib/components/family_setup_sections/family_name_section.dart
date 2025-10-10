import 'package:flutter/material.dart';

class FamilyNameRow extends StatelessWidget {
  final String initialName;
  final ValueChanged<String> onChanged;
  final VoidCallback onSave;
  final bool saving;
  final String? errorText;

  const FamilyNameRow({
    super.key,
    required this.initialName,
    required this.onChanged,
    required this.onSave,
    this.saving = false,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: initialName);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Family Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: 'Family name',
            hintText: 'e.g., The Adams Family',
            errorText: errorText,
          ),
          onChanged: onChanged,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save),
          label: Text(saving ? 'Saving…' : 'Save name'),
        ),
      ],
    );
  }
}
