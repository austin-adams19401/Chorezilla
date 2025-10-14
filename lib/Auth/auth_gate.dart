import 'package:chorezilla/models/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:chorezilla/state/app_state.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_dashboard.dart';
import 'package:chorezilla/pages/family_setup/parent_setup_screen.dart';
import 'package:chorezilla/auth/login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final user = FirebaseAuth.instance.currentUser;

    // Not signed in → Login
    if (user == null) {
      return const LoginPage();
    }

    // Signed in but still booting streams → splash loader
    if (!app.bootLoaded || app.family == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Loaded: pick Setup or Dashboard
    final hasKids = app.members.any((m) => m.role == FamilyRole.child && m.active);
    if (!hasKids) {
      return const ParentSetupPage();
    }

    return const ParentDashboardPage();
  }
}
