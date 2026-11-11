import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'theme/plantpal_colors.dart';

// Local storage key for the last selected appearance.
const String _themePreferenceKey = 'plantpal_theme_mode';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the last selected appearance from this device.
  final preferences = await SharedPreferences.getInstance();

  // Initialize Firebase.
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.linux) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(
          '6Lf3KRIuAAAAAGTTLJD0La_l85o2Z2QlntAPTXkO',
        ),
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleAppAttestWithDeviceCheckFallbackProvider(),
      );
    }
  }

  runApp(PlantPalApp(preferences: preferences));
}

class PlantPalApp extends StatelessWidget {
  final SharedPreferences preferences;

  const PlantPalApp({super.key, required this.preferences});

  ThemeMode _themeFromString(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;

      case 'dark':
        return ThemeMode.dark;

      case 'system':
        return ThemeMode.system;

      default:
        return ThemeMode.light;
    }
  }

  // Read the last appearance selected on this device.
  ThemeMode _localTheme() {
    final savedValue = preferences.getString(_themePreferenceKey);

    return _themeFromString(savedValue);
  }

  // Save a Firebase appearance preference locally.
  //
  // This lets the Login screen use the same appearance
  // after the user logs out.
  void _rememberTheme(String value) {
    if (value != 'light' && value != 'dark' && value != 'system') {
      return;
    }

    final previous = preferences.getString(_themePreferenceKey);

    if (previous == value) return;

    unawaited(preferences.setString(_themePreferenceKey, value));
  }

  // Create either the light or dark PlantPal theme.
  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    final background = isDark
        ? PlantPalColors.darkBackground
        : PlantPalColors.lightBackground;

    final cardColor = isDark
        ? PlantPalColors.darkCard
        : PlantPalColors.lightCard;

    final textColor = isDark
        ? PlantPalColors.darkText
        : PlantPalColors.lightText;

    final secondaryText = isDark
        ? PlantPalColors.darkSecondary
        : PlantPalColors.lightSecondary;

    final accent = isDark ? PlantPalColors.darkAccent : PlantPalColors.forest;

    final borderColor = isDark ? const Color(0xFF3A5444) : PlantPalColors.mint;

    final scheme =
        ColorScheme.fromSeed(
          seedColor: PlantPalColors.forest,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: isDark ? PlantPalColors.darkBackground : Colors.white,
          surface: cardColor,
          onSurface: textColor,
          outline: borderColor,
          outlineVariant: borderColor,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,

      // Main application background.
      scaffoldBackgroundColor: background,

      // Default text colors.
      textTheme: TextTheme(
        headlineSmall: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textColor),
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
        bodySmall: TextStyle(color: secondaryText),
        labelLarge: TextStyle(color: textColor),
      ),

      // Top navigation bar.
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: textColor,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        elevation: 0,
      ),

      // Cards throughout the application.
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      // Text fields.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF304237) : Colors.white,
        labelStyle: TextStyle(color: secondaryText),
        hintStyle: TextStyle(color: secondaryText),
        helperStyle: TextStyle(color: secondaryText),
        prefixIconColor: accent,
        suffixIconColor: accent,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
      ),

      // Main action buttons.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PlantPalColors.forest,
          foregroundColor: Colors.white,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: borderColor),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),

      // Notification and Settings switches.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }

          return null;
        }),
      ),

      // Bottom navigation bar.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: cardColor,
        selectedItemColor: accent,
        unselectedItemColor: secondaryText,
        type: BottomNavigationBarType.fixed,
      ),

      // Popup menus.
      popupMenuTheme: PopupMenuThemeData(
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(color: textColor),
      ),

      // Dialogs.
      dialogTheme: DialogThemeData(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(color: textColor, fontSize: 14),
      ),

      // Dividers.
      dividerTheme: DividerThemeData(color: borderColor, thickness: 1),

      // Icon colors.
      iconTheme: IconThemeData(color: accent),

      // Checkbox styling.
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accent;
          }

          return null;
        }),
      ),
    );
  }

  // Build MaterialApp with the chosen appearance.
  Widget _app({required ThemeMode themeMode, required bool isLinuxDesktop}) {
    return MaterialApp(
      title: 'PlantPal',
      debugShowCheckedModeBanner: false,

      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),

      // Choose light, dark, or system appearance.
      themeMode: themeMode,

      home: isLinuxDesktop ? const HomeScreen() : const AuthWrapper(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLinuxDesktop =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

    // Keep the existing Linux desktop behavior.
    if (isLinuxDesktop) {
      return _app(themeMode: _localTheme(), isLinuxDesktop: true);
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        // IMPORTANT:
        // When logged out, use the appearance stored
        // on this device instead of always using System.
        if (user == null) {
          return _app(themeMode: _localTheme(), isLinuxDesktop: false);
        }

        // When logged in, read the user's Firebase settings.
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          key: ValueKey(user.uid),
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, userSnapshot) {
            final data = userSnapshot.data?.data();
            final rawSettings = data?['settings'];

            final settings = rawSettings is Map ? rawSettings : const {};

            final savedTheme = settings['themeMode'];

            // While Firebase is loading, keep the
            // local preference rather than switching themes.
            if (savedTheme is! String) {
              return _app(themeMode: _localTheme(), isLinuxDesktop: false);
            }

            final themeMode = _themeFromString(savedTheme);

            // Keep local appearance in sync with Firebase.
            _rememberTheme(savedTheme);

            return _app(themeMode: themeMode, isLinuxDesktop: false);
          },
        );
      },
    );
  }
}

// Decide whether to show Home or Login.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        // Firebase is checking login status.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is logged in.
        if (snapshot.hasData) {
          return const HomeScreen();
        }

        // User is logged out.
        return const LoginScreen();
      },
    );
  }
}
