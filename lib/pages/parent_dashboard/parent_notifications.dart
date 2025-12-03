import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/models/member.dart'; // 👈 add this
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';

class ParentNotificationRegistrar extends StatefulWidget {
  const ParentNotificationRegistrar({super.key});

  @override
  State<ParentNotificationRegistrar> createState() =>
      _ParentNotificationRegistrarState();
}

class _ParentNotificationRegistrarState
    extends State<ParentNotificationRegistrar> {
  bool _initialized = false;
  bool _registering = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized || _registering) return;

    final app = context.watch<AppState>();
    final familyId = app.familyId;

    // 🔍 Figure out which member to treat as "this parent"
    Member? member = app.currentMember;

    // If no currentMember (common in parent view), fall back to a parent/owner
    if (member == null) {
      try {
        member = app.members.firstWhere(
          (m) => m.role == FamilyRole.parent,
        );
      } catch (_) {
        member = null;
      }
    }

    debugPrint(
      'ParentNotificationRegistrar.didChangeDependencies '
      'isReady=${app.isReady} member=${member?.id} familyId=$familyId',
    );

    // Wait until app is fully ready and we actually know who the parent member is.
    if (!app.isReady || member == null || familyId == null) {
      return; // try again on next AppState change
    }

    // Only register for parents/owners, skip child devices entirely.
    if (member.role == FamilyRole.child) {
      debugPrint('ParentNotificationRegistrar: member is child, skipping.');
      _initialized = true;
      return;
    }

    _registering = true;
    _setup(member).then((_) {
      if (!mounted) return;
      _registering = false;
      _initialized = true;
      debugPrint('ParentNotificationRegistrar: setup complete.');
    });
  }

  Future<void> _setup(Member member) async {
    final app = context.read<AppState>();
    final familyId = app.familyId;

    if (familyId == null) {
      debugPrint('ParentNotificationRegistrar._setup: familyId null');
      return;
    }

    debugPrint(
      'ParentNotificationRegistrar._setup for member=${member.id} '
      'family=$familyId',
    );

    final messaging = FirebaseMessaging.instance;

    // Ask for notification permission (esp. iOS, Android 13+ UX)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    debugPrint(
      'ParentNotificationRegistrar: permission status=${settings.authorizationStatus}',
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('ParentNotificationRegistrar: permission denied by user.');
      return;
    }

    // Get current token
    final token = await messaging.getToken();
    debugPrint('ParentNotificationRegistrar: token=$token');

    if (token == null) return;

    // Save token on this parent member document
    await app.updateMember(member.id, {
      'fcmTokens': FieldValue.arrayUnion([token]),
    });
    debugPrint(
      'ParentNotificationRegistrar: token saved to member ${member.id}.',
    );

    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('ParentNotificationRegistrar: token refreshed=$newToken');
      await app.updateMember(member.id, {
        'fcmTokens': FieldValue.arrayUnion([newToken]),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
