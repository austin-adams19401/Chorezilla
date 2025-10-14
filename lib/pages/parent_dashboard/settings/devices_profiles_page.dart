
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chorezilla/state/app_state.dart';

/// Devices & Profiles
/// Lets a parent see devices linked to the family and choose which profiles (members)
/// can use each device. Also lets them "link this device" to the family.
///
/// Firestore (assumed shape — tweak to match your schema):
/// families/{familyId}/devices/{deviceId} {
///   deviceId: string,
///   name: string,
///   platform: string,
///   lastSeen: Timestamp,
///   assignedMemberIds: string[]
/// }
/// families/{familyId}/members/{memberId} {
///   memberId: string,
///   displayName: string,
///   role: 'parent' | 'child' | ...
///   avatar: string (emoji or url) — optional
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

  /// Small, dependency-free id generator. Good enough for local device identity.
  String _generateStableId() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(12, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    // TODO: update to your actual family id accessor
    final String? familyId = app.familyId; // or app.currentFamilyId

    return Scaffold(
      appBar: AppBar(
        title: const Text('Devices & Profiles'),
      ),
      body: familyId == null
          ? const _CenteredNote(
              icon: Icons.error_outline,
              message: 'No family selected. Open or create a family first.',
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LinkThisDeviceCard(
                    familyId: familyId,
                    localDeviceId: _localDeviceId,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _DevicesList(
                      familyId: familyId,
                      localDeviceId: _localDeviceId,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _LinkThisDeviceCard extends StatelessWidget {
  const _LinkThisDeviceCard({
    required this.familyId,
    required this.localDeviceId,
  });

  final String familyId;
  final String? localDeviceId;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices_other_rounded),
                const SizedBox(width: 8),
                const Text(
                  'This device',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (localDeviceId != null)
                  Chip(
                    label: const Text('Linked'),
                    avatar: const Icon(Icons.link_rounded, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              localDeviceId == null
                  ? 'Not linked yet'
                  : 'ID: $localDeviceId',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.link_rounded),
                  label: Text(localDeviceId == null ? 'Link this device' : 'Relink / Update'),
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    var id = localDeviceId ?? prefs.getString('cz_device_id');
                    if (id == null) {
                      // Should not happen, but regenerate if needed
                      final rnd = Random.secure();
                      final bytes = List<int>.generate(12, (_) => rnd.nextInt(256));
                      id = base64UrlEncode(bytes).replaceAll('=', '');
                      await prefs.setString('cz_device_id', id);
                    }

                    final ref = FirebaseFirestore.instance
                        .collection('families')
                        .doc(familyId)
                        .collection('devices')
                        .doc(id);

                    await ref.set({
                      'deviceId': id,
                      'name': 'Device ${id.substring(0, 5)}',
                      'platform': Theme.of(context).platform.toString().split('.').last,
                      'lastSeen': FieldValue.serverTimestamp(),
                      'assignedMemberIds': FieldValue.arrayUnion([]),
                    }, SetOptions(merge: true));

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Device linked to family.')),
                      );
                    }
                  },
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Mark active'),
                  onPressed: localDeviceId == null
                      ? null
                      : () async {
                          final ref = FirebaseFirestore.instance
                              .collection('families')
                              .doc(familyId)
                              .collection('devices')
                              .doc(localDeviceId);
                          await ref.set({
                            'lastSeen': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicesList extends StatelessWidget {
  const _DevicesList({
    required this.familyId,
    required this.localDeviceId,
  });

  final String familyId;
  final String? localDeviceId;

  @override
  Widget build(BuildContext context) {
    final devicesRef = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('devices')
        .orderBy('name');

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: devicesRef.snapshots(),
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
        if (docs.isEmpty) {
          return const _CenteredNote(
            icon: Icons.devices_other_rounded,
            message: 'No devices linked yet.\nTap "Link this device" to get started.',
          );
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final d = docs[i].data();
            final id = d['deviceId'] as String? ?? docs[i].id;
            final name = (d['name'] as String?)?.trim().isNotEmpty == true
                ? d['name'] as String
                : 'Device ${id.substring(0, 5)}';
            final assigned = List<String>.from(d['assignedMemberIds'] ?? const []);
            final isThisDevice = (id == localDeviceId);

            return Card(
              child: ListTile(
                leading: Icon(isThisDevice ? Icons.phone_android_rounded : Icons.devices_rounded),
                title: Text(name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isThisDevice) const Text('This device', style: TextStyle(fontStyle: FontStyle.italic)),
                    Text('Allowed profiles: ${assigned.isEmpty ? 'None' : assigned.length}'),
                  ],
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'Rename',
                      icon: const Icon(Icons.drive_file_rename_outline_rounded),
                      onPressed: () async {
                        final ctrl = TextEditingController(text: name);
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
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
                            ],
                          ),
                        );
                        if (newName != null && newName.isNotEmpty) {
                          await docs[i].reference.set({'name': newName}, SetOptions(merge: true));
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Assign profiles',
                      icon: const Icon(Icons.manage_accounts_rounded),
                      onPressed: () => _showAssignSheet(context, familyId, docs[i].reference, assigned),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showAssignSheet(
    BuildContext context,
    String familyId,
    DocumentReference<Map<String, dynamic>> deviceRef,
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
                const Text('Assign profiles to this device', style: TextStyle(fontWeight: FontWeight.w600)),
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
                          // force rebuild within bottom sheet
                          (ctx as Element).markNeedsBuild();
                        },
                        title: Text(m.name),
                        //subtitle: m.role.isEmpty ? null : Text(m.role as String),
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
                        await deviceRef.set(
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

class _CenteredNote extends StatelessWidget {
  const _CenteredNote({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 28, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
