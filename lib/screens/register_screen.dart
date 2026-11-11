import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/plantpal_colors.dart';

import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController nameController = TextEditingController();

  final TextEditingController usernameController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  final AuthService _authService = AuthService();
  final DatabaseService _databaseService = DatabaseService();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Check that the password meets the required rules.
  bool _isStrongPassword(String password) {
    return password.length >= 8 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]'));
  }

  // Check that the username uses valid characters.
  bool _validUsername(String username) {
    return RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username);
  }

  // Create the user's account using Firebase.
  Future<void> _register() async {
    final String name = nameController.text.trim();
    final String username = usernameController.text.trim();
    final String email = emailController.text.trim();
    final String password = passwordController.text;
    final String confirmPassword = confirmPasswordController.text;

    if (name.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields.')),
      );
      return;
    }

    if (!_validUsername(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Username must be 3-20 characters and only '
            'contain letters, numbers, or underscores.',
          ),
        ),
      );
      return;
    }

    if (!_isStrongPassword(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password must be at least 8 characters and '
            'contain an uppercase letter, lowercase letter, '
            'and number.',
          ),
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bool available = await _databaseService.isUsernameAvailable(
        username,
      );

      if (!available) {
        throw Exception('That username is already taken.');
      }

      final user = await _authService.signUpWithEmailAndPassword(
        email,
        password,
      );

      if (user == null) {
        throw Exception('Unable to create account.');
      }

      await user.updateDisplayName(name);

      await _databaseService.addUser(
        uid: user.uid,
        email: user.email ?? email,
        displayName: name,
        username: username,
      );

      await _authService.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Registration failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Shared decoration for the registration text fields.
  InputDecoration _fieldDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffixIcon,
  }) {
    final accent = PlantPalColors.accent(context);
    final border = PlantPalColors.border(context);
    final isDark = PlantPalColors.isDark(context);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: PlantPalColors.secondaryText(context)),
      hintStyle: TextStyle(color: PlantPalColors.secondaryText(context)),
      floatingLabelStyle: TextStyle(color: accent),
      prefixIcon: Icon(icon, color: accent),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: isDark ? const Color(0xFF304237) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: accent, width: 2),
      ),
    );
  }

  // Build the registration screen.
  @override
  Widget build(BuildContext context) {
    final background = PlantPalColors.background(context);
    final cardColor = PlantPalColors.card(context);
    final textColor = PlantPalColors.text(context);
    final secondaryText = PlantPalColors.secondaryText(context);
    final accent = PlantPalColors.accent(context);
    final borderColor = PlantPalColors.border(context);
    final softBackground = PlantPalColors.softBackground(context);

    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // PlantPal registration header.
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: softBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.eco_outlined, size: 60, color: accent),
                ),

                const SizedBox(height: 16),

                Text(
                  'Join the PlantPal Community',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Create an account and start your plant journey!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: secondaryText),
                ),

                const SizedBox(height: 24),

                // Registration form.
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Name
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: textColor),
                        cursorColor: accent,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Name',
                          icon: Icons.badge_outlined,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Username
                      TextField(
                        controller: usernameController,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: textColor),
                        cursorColor: accent,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Username',
                          hint: 'Example: plantlover22',
                          icon: Icons.person_outline,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Email
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: textColor),
                        cursorColor: accent,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Email',
                          icon: Icons.email_outlined,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Password
                      TextField(
                        controller: passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.next,
                        style: TextStyle(color: textColor),
                        cursorColor: accent,
                        decoration: _fieldDecoration(
                          context,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show passwords'
                                : 'Hide passwords',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: accent,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Use at least 8 characters, including an '
                        'uppercase letter, lowercase letter, '
                        'and number.',
                        style: TextStyle(color: secondaryText, fontSize: 12),
                      ),

                      const SizedBox(height: 14),

                      // Confirm Password
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        style: TextStyle(color: textColor),
                        cursorColor: accent,
                        onSubmitted: (_) {
                          if (!_isLoading) _register();
                        },
                        decoration: _fieldDecoration(
                          context,
                          label: 'Confirm Password',
                          icon: Icons.verified_user_outlined,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show passwords'
                                : 'Hide passwords',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: accent,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Create Account button.
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: PlantPalColors.forest,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: PlantPalColors.sage,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _isLoading ? null : _register,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  'Already have an account?',
                  style: TextStyle(color: textColor),
                ),

                // Back to Login
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                  child: Text(
                    'Log In',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
