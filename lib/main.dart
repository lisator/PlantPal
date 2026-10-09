

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb || defaultTargetPlatform != TargetPlatform.linux) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const PlantPalApp());
}

class PlantPalApp extends StatelessWidget {
  const PlantPalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isLinuxDesktop = !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    return MaterialApp(
      title: 'PlantPal',
      // Firebase isn't set up on Linux desktop, so skip login and go straight home
      home: isLinuxDesktop ? const HomeScreen() : const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        // Show a loading indicator while Firebase resolves the local session token
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If a session exists, route directly to HomeScreen
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // Otherwise, show the LoginScreen
        return const LoginScreen();
      },
    );
  }
}
