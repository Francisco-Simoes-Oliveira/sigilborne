import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'pages/character_session.dart';
import 'pages/login_page.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const SigilborneApp());
}

class SigilborneApp extends StatelessWidget {
  const SigilborneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sigilborne',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, this.auth, this.apiService});

  final FirebaseAuth? auth;
  final ApiService? apiService;

  @override
  Widget build(BuildContext context) {
    final firebaseAuth = auth ?? FirebaseAuth.instance;
    return StreamBuilder<User?>(
      stream: firebaseAuth.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text(
                'Não foi possível verificar a sessão. Reabra o aplicativo.',
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          return CharacterSession(
            key: ValueKey(user.uid),
            userId: user.uid,
            onSignOut: firebaseAuth.signOut,
            apiService: apiService,
          );
        }

        return const LoginPage();
      },
    );
  }
}
