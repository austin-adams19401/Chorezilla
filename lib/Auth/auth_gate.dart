
import 'package:chorezilla/Auth/login_page.dart';
import 'package:chorezilla/pages/family_setup/parent_setup_screen.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_dashboard.dart';
import 'package:chorezilla/state/app_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Splashes briefly while Firebase restores the session, then routes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    switch (app.authState) {
      case AuthState.unknown:
        return SplashScreen();
      case AuthState.signedOut:
        return const LoginPage();
      case AuthState.needsFamilySetup:
        return const ParentSetupScreen();
      case AuthState.ready:
        return const ParentDashboardPage();
      default: return SplashScreen();
    }
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
