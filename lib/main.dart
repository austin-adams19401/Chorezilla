import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'themes/app_theme.dart';
import 'auth/login_page.dart';
import 'auth/register_page.dart';
import 'pages/family_setup_page.dart';
import 'pages/parent_dashboard/parent_dashboard.dart';
import 'pages/child_dashboard/child_dashboard.dart';
import 'state/app_state.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
  try {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  } catch (_) {}
}

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
