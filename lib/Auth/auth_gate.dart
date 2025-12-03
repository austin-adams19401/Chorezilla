import 'package:chorezilla/models/common.dart';
import 'package:chorezilla/pages/family_setup/parent_setup_screen.dart';
import 'package:chorezilla/pages/kid_pages/kids_home_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:chorezilla/state/app_state.dart';

import 'package:chorezilla/pages/parent_dashboard/parent_dashboard.dart';
import 'package:chorezilla/pages/startup/login_page.dart';
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final user = app.firebaseUser;
    final family = app.family;
    final members = app.members;

    // 1) Not signed in → Login
    if (user == null) {
      return const LoginPage();
    }

    // 2) Wait until we’ve loaded viewMode from SharedPreferences
    if (!app.viewModeLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 3) Signed in but family/members streams still booting → splash loader
    if (!app.bootLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 4) Signed in + streams ready:
    //    No family yet → go to setup flow to create it
    if (family == null) {
      return const ParentSetupPage();
    }

    // 5) Check kids + onboardingComplete
    final hasKids = members.any((m) => m.role == FamilyRole.child && m.active);
    final onboardingComplete = family.onboardingComplete;

    if (!hasKids || !onboardingComplete) {
      return const ParentSetupPage();
    }

    // 6) All set → decide root by view mode
    if (app.viewMode == AppViewMode.kid) {
      return const KidsHomePage();
    } else {
      return const ParentDashboardPage();
    }
  }
}
