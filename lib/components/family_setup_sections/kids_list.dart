import 'package:flutter/material.dart';

class KidItem {
  final String id;
  final String name;
  final String avatar;
  final String role;
  const KidItem({required this.id, required this.name, required this.avatar, required this.role});
}

class KidsListRow extends StatelessWidget {
  final List<KidItem> kids;
  final Future<void> Function(String kidId) onRemove;

  const KidsListRow({
    super.key,
    required this.kids,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Current Kids', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (kids.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('No kids yet.'),
          ),
        ...kids.map((k) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text(k.avatar, style: const TextStyle(fontSize: 24)),
              title: Text(k.name),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => onRemove(k.id),
                tooltip: 'Remove',
              ),
            )),
      ],
    );
  }
}
