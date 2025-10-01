import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'themes/app_theme.dart';
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'pages/family_setup_page.dart';
import 'pages/parent_dashboard/parent_dashboard.dart';
import 'pages/child_dashboard/child_dashboard.dart';
import 'state/app_state.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const Chorezilla(),
    ),
  );
}

class Chorezilla extends StatelessWidget {
  const Chorezilla({super.key});

  @override
  Widget build(BuildContext context) {
    // const bool isLoggedIn = false; 
    // TODO: implement actual auth
    final startRoute = '/login';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // Named routes
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/family-setup': (_) => const FamilySetupPage(),
        '/parent': (_) => const ParentDashboardPage(),
        '/kid': (_) => const ChildDashboardPage(),
      },

      initialRoute: startRoute,
    );
  }
}
