import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/themes/app_theme.dart';

/// Devices & Profiles
/// Lets a parent see devices linked to the family and choose which profiles
/// can use each device. Also lets them "link this device" to the family.
///
/// Firestore shape:
/// families/{familyId}/devices/{deviceId} {
///   deviceId: string,
///   name: string,
///   platform: string,
///   lastSeen: Timestamp,
///   assignedMemberIds: string[]
/// }
class DevicesProfilesPage extends StatefulWidget {
  const DevicesProfilesPage({super.key});

  @override
  State<DevicesProfilesPage> createState() => _DevicesProfilesPageState();
}

class _DevicesProfilesPageState extends State<DevicesProfilesPage> {
  String? _localDeviceId;

  @override
  void initState() {
    super.initState();
    _ensureLocalDeviceId();
  }

  Future<void> _ensureLocalDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('cz_device_id');
    if (id == null) {
      id = _generateStableId();
      await prefs.setString('cz_device_id', id);
    }
    if (mounted) setState(() => _localDeviceId = id);
  }

  String _generateStableId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(12, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final String? familyId = app.familyId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Devices'),
        centerTitle: false,
      ),
      body: familyId == null
          ? const _CenteredNote(
              icon: Icons.error_outline,
              message: 'No family selected. Open or create a family first.',
            )
          : _DevicesBody(
              familyId: familyId,
              localDeviceId: _localDeviceId,
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body
// ─────────────────────────────────────────────────────────────────────────────

class _DevicesBody extends StatelessWidget {
  const _DevicesBody({
    required this.familyId,
    required this.localDeviceId,
  });

  final String familyId;
  final String? localDeviceId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('families')
          .doc(familyId)
          .collection('devices')
          .orderBy('name')
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return _CenteredNote(
            icon: Icons.error_outline,
            message: 'Error loading devices: ${snap.error}',
          );
        }

        final docs = snap.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _ThisDeviceCard(
              familyId: familyId,
              localDeviceId: localDeviceId,
              linkedDoc: docs.where((d) => d.id == localDeviceId).firstOrNull,
            ),
            const SizedBox(height: 28),
            _SectionHeader(
              icon: Icons.devices_rounded,
              title: 'Family Devices',
              count: docs.length,
            ),
            const SizedBox(height: 12),
            if (docs.isEmpty)
              const _CenteredNote(
                icon: Icons.devices_other_rounded,
                message: 'No devices linked yet.\nLink this device to get started.',
              )
            else
              ...docs.map(
                (doc) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _DeviceCard(
                    doc: doc,
                    familyId: familyId,
                    isThisDevice: doc.id == localDeviceId,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// This Device card
// ─────────────────────────────────────────────────────────────────────────────

class _ThisDeviceCard extends StatelessWidget {
  const _ThisDeviceCard({
    required this.familyId,
    required this.localDeviceId,
    required this.linkedDoc,
  });

  final String familyId;
  final String? localDeviceId;
  final QueryDocumentSnapshot<Map<String, dynamic>>? linkedDoc;

  bool get _isLinked => localDeviceId != null && linkedDoc != null;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final platform = linkedDoc?.data()['platform'] as String?;
    final deviceName = linkedDoc?.data()['name'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isLinked
            ? AppTheme.zillaGreen.withAlpha(15)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isLinked ? AppTheme.zillaGreen.withAlpha(80) : cs.outlineVariant,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _isLinked
                  ? AppTheme.zillaGreen.withAlpha(30)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _platformIcon(platform),
              size: 28,
              color: _isLinked ? AppTheme.zillaGreen : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      deviceName ?? 'This device',
                      style: ts.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    if (_isLinked)
                      _StatusBadge(label: 'Linked', color: AppTheme.zillaGreen)
                    else
                      _StatusBadge(label: 'Not linked', color: cs.onSurfaceVariant),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isLinked
                      ? 'This device is linked to your family.'
                      : 'Link this device so family members can use it.',
                  style: ts.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  icon: Icon(_isLinked ? Icons.sync_rounded : Icons.link_rounded, size: 18),
                  label: Text(_isLinked ? 'Relink / Update' : 'Link this device'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isLinked ? AppTheme.zillaGreen : cs.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _linkDevice(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _linkDevice(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    var id = localDeviceId ?? prefs.getString('cz_device_id');
    if (id == null) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(12, (_) => rnd.nextInt(256));
      id = base64UrlEncode(bytes).replaceAll('=', '');
      await prefs.setString('cz_device_id', id);
    }

    if (!context.mounted) return;

    final ref = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('devices')
        .doc(id);

    await ref.set({
      'deviceId': id,
      'name': linkedDoc?.data()['name'] ?? 'Device ${id.substring(0, 5)}',
      'platform': Theme.of(context).platform.toString().split('.').last,
      'lastSeen': FieldValue.serverTimestamp(),
      'assignedMemberIds': FieldValue.arrayUnion([]),
    }, SetOptions(merge: true));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device linked to family.')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Device card (family device list)
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.doc,
    required this.familyId,
    required this.isThisDevice,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String familyId;
  final bool isThisDevice;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    final d = doc.data();
    final id = d['deviceId'] as String? ?? doc.id;
    final name = (d['name'] as String?)?.trim().isNotEmpty == true
        ? d['name'] as String
        : 'Device ${id.substring(0, 5)}';
    final assigned = List<String>.from(d['assignedMemberIds'] ?? const []);
    final platform = d['platform'] as String?;
    final lastSeen = d['lastSeen'] as Timestamp?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isThisDevice
            ? cs.primaryContainer.withAlpha(60)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: isThisDevice
            ? Border.all(color: cs.primary.withAlpha(60), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          // Platform icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isThisDevice
                  ? cs.primary.withAlpha(20)
                  : cs.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _platformIcon(platform),
              size: 22,
              color: isThisDevice ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: ts.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isThisDevice) ...[
                      const SizedBox(width: 6),
                      _StatusBadge(label: 'This device', color: cs.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      _formatLastSeen(lastSeen),
                      style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(width: 10),
                    Icon(Icons.people_outline_rounded,
                        size: 12, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      assigned.isEmpty
                          ? 'No profiles'
                          : '${assigned.length} profile${assigned.length == 1 ? '' : 's'}',
                      style: ts.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionIconButton(
                icon: Icons.drive_file_rename_outline_rounded,
                tooltip: 'Rename',
                onPressed: () => _showRenameDialog(context, name),
              ),
              const SizedBox(width: 4),
              _ActionIconButton(
                icon: Icons.manage_accounts_rounded,
                tooltip: 'Assign profiles',
                onPressed: () => _showAssignSheet(context, assigned),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(BuildContext context, String currentName) async {
    final ctrl = TextEditingController(text: currentName);
    final newName = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Device name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await doc.reference.set({'name': newName}, SetOptions(merge: true));
    }
  }

  Future<void> _showAssignSheet(
    BuildContext context,
    List<String> currentAssigned,
  ) async {
    final app = context.read<AppState>();
    final all = app.members
        .map((m) => (id: m.id, name: m.displayName, role: m.role))
        .toList();
    final selected = currentAssigned.toSet();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 12,
              left: 16,
              right: 16,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Assign profiles to this device',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: all.length,
                    itemBuilder: (_, i) {
                      final m = all[i];
                      final checked = selected.contains(m.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) {
                          if (v == true) {
                            selected.add(m.id);
                          } else {
                            selected.remove(m.id);
                          }
                          (ctx as Element).markNeedsBuild();
                        },
                        title: Text(m.name),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Save'),
                      onPressed: () async {
                        await doc.reference.set(
                          {'assignedMemberIds': selected.toList()},
                          SetOptions(merge: true),
                        );
                        if (context.mounted) Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

IconData _platformIcon(String? platform) {
  switch (platform?.toLowerCase()) {
    case 'ios':
      return Icons.phone_iphone_rounded;
    case 'android':
      return Icons.phone_android_rounded;
    case 'macos':
      return Icons.laptop_mac_rounded;
    case 'windows':
      return Icons.computer_rounded;
    case 'linux':
      return Icons.computer_rounded;
    default:
      return Icons.devices_rounded;
  }
}

String _formatLastSeen(Timestamp? ts) {
  if (ts == null) return 'Never seen';
  final dt = ts.toDate();
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.month}/${dt.day}/${dt.year}';
}

// ─────────────────────────────────────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  final IconData icon;
  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          title,
          style: ts.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        if (count > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: ts.labelSmall?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: cs.onSurfaceVariant.withAlpha(120)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
