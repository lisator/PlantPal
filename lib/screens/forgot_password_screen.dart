import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen
    extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final TextEditingController emailController =
      TextEditingController();

  final AuthService _authService =
      AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    emailController.dispose();

    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    final String email =
        emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Please enter your email.'),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authService
          .sendPasswordResetEmail(email);

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset request sent. Check your email inbox and spam folder.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('Reset failed: $e'),
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text(
                'Forgot Password',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                'Enter your email address and Firebase will send you a password reset link.',
                textAlign:
                    TextAlign.center,
              ),

              const SizedBox(height: 30),

              TextField(
                controller:
                    emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration:
                    const InputDecoration(
                  labelText: 'Email',
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child:
                    ElevatedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : _sendResetEmail,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Send Reset Link',
                        ),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Back to Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}