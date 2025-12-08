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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final user = app.firebaseUser;
    final family = app.family;
    final members = app.members;

    // 1) Not signed in → Login
    if (user == null) {
      return const LoginPage();
    }

    // 2) Wait until we've loaded viewMode from SharedPreferences
    if (!app.viewModeLoaded) {
      return Scaffold(body: Center(child: CircularProgressIndicator(backgroundColor: cs.secondary,)));
    }

    // 3) Signed in but family/members streams still booting → splash loader
    if (!app.bootLoaded) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(backgroundColor: cs.secondary),
        ),
      );
    }

    // 3.5) Family is boot-loaded, but we DON'T yet know parent PIN state
    // (Firestore family doc hasn't arrived with parentPinHash).
    // → stay on splash instead of flashing ParentSetupPage.
    if (!app.parentPinLoaded) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(backgroundColor: cs.secondary),
        ),
      );
    }

    // 4) Signed in + streams ready:
    //    No family yet → go to setup flow to create it
    if (family == null) {
      return const ParentSetupPage();
    }

    debugPrint(
      'AuthGate state: bootLoaded=${app.bootLoaded} '
      'parentPinLoaded=${app.parentPinLoaded} hasParentPin=${app.hasParentPin} '
      'family=${family.id} kids=${members.length}',
    );


    // 5) Check kids + onboardingComplete + parent PIN
    final hasKids = members.any((m) => m.role == FamilyRole.child && m.active);
    final onboardingComplete = family.onboardingComplete;
    final hasParentPin = app.hasParentPin;

    debugPrint(
      'AuthGate state: bootLoaded=${app.bootLoaded} '
      'parentPinLoaded=${app.parentPinLoaded} hasParentPin=${app.hasParentPin} '
      'family=${family.id} kids=${members.length}',
    );


    // If any of these are missing, stay in Parent Setup
    if (!hasKids || !onboardingComplete || !hasParentPin) {
      return const ParentSetupPage();
    }
    debugPrint(
      'AuthGate state: bootLoaded=${app.bootLoaded} '
      'parentPinLoaded=${app.parentPinLoaded} hasParentPin=${app.hasParentPin} '
      'family=${family.id} kids=${members.length}',
    );


    // 6) All set → decide root by view mode
    if (app.viewMode == AppViewMode.kid) {
      return const KidsHomePage();
    } else {
      return const ParentDashboardPage();
    }
  }
}

