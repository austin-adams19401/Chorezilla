//Auth
import 'package:chorezilla/Auth/auth_gate.dart';
import 'package:chorezilla/Auth/kid_join_page.dart';
import 'package:chorezilla/auth/login_page.dart';
import 'package:chorezilla/auth/register_page.dart';
//Pages
import 'package:chorezilla/pages/child_dashboard/child_dashboard.dart';
import 'package:chorezilla/pages/family_setup/add_kids_page.dart';
import 'package:chorezilla/pages/family_setup/edit_family.dart';
import 'package:chorezilla/pages/family_setup/parent_setup_screen.dart';
import 'package:chorezilla/pages/parent_dashboard/parent_dashboard.dart';
import 'package:chorezilla/themes/app_theme.dart';
//Flutter libraries
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
//Firebase
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:chorezilla/firebase_options.dart';
//App State
import 'package:chorezilla/state/app_state.dart';

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
        '/edit': (_) => const EditFamilyPage(),
        '/add-kids': (_) => const AddKidsPage(),
        '/kid-join': (_) => const KidJoinPage(),
        '/parent': (_) => const ParentDashboardPage(),
        '/kids' : (_) => const ChildDashboardPage(),
      },
    );
  }
}
