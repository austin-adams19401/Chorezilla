import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/models/common.dart';

import 'package:chorezilla/auth/login_page.dart';
import 'package:chorezilla/pages/family_setup/parent_setup_screen.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = FirebaseAuth.instance.currentUser;

    // 1) Not signed in
    if (user == null) {
      return const LoginPage();
    }

    // 2) Signed in, but AppState hasn't finished bootstrapping Firestore user/family
    if (!app.isReady) {
      return const _Splash();
    }

    // 3) Onboarding decision: if no kids yet, send to setup
    final hasAnyKids = app.members.any((m) => m.role == FamilyRole.child && m.active);
    if (!hasAnyKids) {
      return const ParentSetupPage();
    }

    // 4) All good → main app
    return const ParentDashboardPage();
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(width: 56, height: 56, child: CircularProgressIndicator()),
      ),
    );
  }
}
