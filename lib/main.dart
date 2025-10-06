import 'package:chorezilla/pages/child_dashboard/child_dashboard.dart';
import 'package:chorezilla/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:chorezilla/firebase_options.dart';
import 'state/app_state.dart';

// Screens
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'pages/family_setup/parent_setup_screen.dart';
import 'pages/family_setup/add_kids_page.dart';
import 'Auth/kid_join_page.dart';
import 'pages/parent_dashboard/parent_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  }

final appState = AppState();
await appState.loadTheme();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,             
      child: const ChorezillaApp(),
    ),
  );
}

class ChorezillaApp extends StatelessWidget {
  const ChorezillaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: app.themeMode,
      debugShowCheckedModeBanner: false,
      title: 'Chorezilla',
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/parent-setup': (_) => const ParentSetupScreen(),
        '/add-kids': (_) => const AddKidsPage(),
        '/kid-join': (_) => const KidJoinPage(),
        '/parent': (_) => const ParentDashboardPage(),
        '/kids' : (_) => const ChildDashboardPage(),
      },
    );
  }
}

/// Splashes briefly while Firebase restores the session, then routes.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final user = snap.data;
        if (user == null) {
          return const LoginPage();
        }

        // You can preload family/profile here if your AppState exposes a method.
        //context.read<AppState>().loadFamilyFromFirestore(user.uid);

        return const ParentDashboardPage();
      },
    );
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
