
import 'package:flutter/material.dart';

class AddKidPickerRow extends StatefulWidget {
  final Future<void> Function({required String name, required String avatar}) onAdd;
  final List<String> avatars; 

  const AddKidPickerRow({
    super.key,
    required this.onAdd,
    required this.avatars,
  });

  @override
  State<AddKidPickerRow> createState() => _AddKidPickerRowState();
}

class _AddKidPickerRowState extends State<AddKidPickerRow> {
  final _nameCtrl = TextEditingController();
  late String _avatar;

  @override
  void initState() {
    super.initState();
    _avatar = widget.avatars.first;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Add Kid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(labelText: 'Child name'),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 144,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.avatars.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final em = widget.avatars[i];
              final selected = em == _avatar;
              return ChoiceChip(
                label: Text(em, style: const TextStyle(fontSize: 20)),
                selected: selected,
                onSelected: (_) => setState(() => _avatar = em),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please enter a name')),
              );
              return;
            }
            await widget.onAdd(name: name, avatar: _avatar);
            _nameCtrl.clear();
          },
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Add Kids'),
        ),
      ],
    );
  }
}
