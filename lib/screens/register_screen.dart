import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController usernameController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController
      confirmPasswordController =
      TextEditingController();

  final AuthService _authService =
      AuthService();

  final DatabaseService _databaseService =
      DatabaseService();

  bool _isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  bool _isStrongPassword(
    String password,
  ) {
    return password.length >= 8 &&
        password.contains(
          RegExp(r'[A-Z]'),
        ) &&
        password.contains(
          RegExp(r'[a-z]'),
        ) &&
        password.contains(
          RegExp(r'[0-9]'),
        );
  }

  bool _validUsername(
    String username,
  ) {
    return RegExp(
      r'^[a-zA-Z0-9_]{3,20}$',
    ).hasMatch(username);
  }

  Future<void> _register() async {
    final String name =
        nameController.text.trim();

    final String username =
        usernameController.text.trim();

    final String email =
        emailController.text.trim();

    final String password =
        passwordController.text;

    final String confirmPassword =
        confirmPasswordController.text;

    if (name.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete all fields.',
          ),
        ),
      );

      return;
    }

    if (!_validUsername(username)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Username must be 3-20 characters and only contain letters, numbers, or underscores.',
          ),
        ),
      );

      return;
    }

    if (!_isStrongPassword(password)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Password must be at least 8 characters and contain an uppercase letter, lowercase letter, and number.',
          ),
        ),
      );

      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Passwords do not match.'),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final bool available =
          await _databaseService
              .isUsernameAvailable(
        username,
      );

      if (!available) {
        throw Exception(
          'That username is already taken.',
        );
      }

      final user =
          await _authService
              .signUpWithEmailAndPassword(
        email,
        password,
      );

      if (user == null) {
        throw Exception(
          'Unable to create account.',
        );
      }

      await user.updateDisplayName(name);

      await _databaseService.addUser(
        uid: user.uid,
        email:
            user.email ?? email,
        displayName: name,
        username: username,
      );

      await _authService.signOut();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Account created successfully!',
          ),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const LoginScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Registration failed: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Create Your PlantPal Account',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              TextField(
                controller:
                    nameController,
                decoration:
                    const InputDecoration(
                  labelText: 'Name',
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              TextField(
                controller:
                    usernameController,
                decoration:
                    const InputDecoration(
                  labelText: 'Username',
                  hintText:
                      'Example: plantlover22',
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              TextField(
                controller:
                    emailController,
                keyboardType:
                    TextInputType
                        .emailAddress,
                decoration:
                    const InputDecoration(
                  labelText: 'Email',
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 16,
              ),

              TextField(
                controller:
                    passwordController,
                obscureText: true,
                decoration:
                    const InputDecoration(
                  labelText: 'Password',
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              const Text(
                'Password must be at least 8 characters and contain an uppercase letter, lowercase letter, and number.',
              ),

              const SizedBox(
                height: 16,
              ),

              TextField(
                controller:
                    confirmPasswordController,
                obscureText: true,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Confirm Password',
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : _register,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Register',
                        ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              const Text(
                'Already have an account?',
              ),

              TextButton(
                onPressed: () {
                  Navigator
                      .pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              const LoginScreen(),
                    ),
                  );
                },
                child:
                    const Text('Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}