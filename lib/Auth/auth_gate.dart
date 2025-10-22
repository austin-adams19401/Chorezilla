import 'package:chorezilla/models/common.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:chorezilla/state/app_state.dart';


import 'package:chorezilla/pages/family_setup/add_kids_page.dart';
import 'package:chorezilla/pages/family_setup/parent_setup_page.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_dashboard.dart';
import 'package:chorezilla/pages/startup/login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.idTokenChanges(),
      builder: (context, snap) {
        final user = snap.data;

        // 1) Not signed in → Login
        if (user == null) {
          return const LoginPage();
        }

        // 2) Signed in but app still booting streams → splash loader
        if (!app.bootLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 3) Signed in + boot done:
        //    No family yet → go to setup flow to create it
        if (app.family == null) {
          return const ParentSetupPage();
        }

        // 4) Family exists. If no active kids yet → finish setup
        final hasKids = app.members.any(
          (m) => m.role == FamilyRole.child && m.active,
        );
        if (!hasKids) {
          return const AddKidsPage();
        }

        // 5) All set → dashboard
        return const ParentDashboardPage();
      },
    );
  }
}
