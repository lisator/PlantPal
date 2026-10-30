
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final TextEditingController emailController =
      TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;

  // PlantPal colors.
  // These colors only affect the Forgot Password screen.
  static const Color _forest = Color(0xFF315F43);
  static const Color _sage = Color(0xFF83AD8A);
  static const Color _pale = Color(0xFFF6F8F2);
  static const Color _mint = Color(0xFFE0EBDD);
  static const Color _ink = Color(0xFF24372A);

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  // Send a password reset link to the email entered by the user.
  Future<void> _sendResetEmail() async {
    final String email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your email.'),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Firebase sends the password reset email.
      await _authService.sendPasswordResetEmail(email);

      if (!mounted) return;

      // Keep the original success message.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password reset request sent. Check your email inbox and spam folder.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Keep the original error handling.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset failed: $e'),
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
    // Apply the PlantPal colors to this screen only.
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _forest,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _sage),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: _forest,
              width: 2,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: _pale,
        appBar: AppBar(
          title: const Text(
            'Reset Password',
            style: TextStyle(
              color: _forest,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: _pale,
          surfaceTintColor: _pale,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // PlantPal password reset header.
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: const BoxDecoration(
                      color: _mint,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset_outlined,
                      color: _forest,
                      size: 60,
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Forgot Password?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _forest,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Enter your email address and Firebase will send you a password reset link.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _ink,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Password reset form.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: _mint),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Reset Your Password',
                          style: TextStyle(
                            color: _forest,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'We will send a reset link to your email.',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Email input field.
                        TextField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!_isLoading) {
                              _sendResetEmail();
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'Enter your email address',
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: _forest,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Send the password reset email.
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _forest,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isLoading
                                ? null
                                : _sendResetEmail,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons.send_outlined,
                                  ),
                            label: Text(
                              _isLoading
                                  ? 'Sending...'
                                  : 'Send Reset Link',
                              style: const TextStyle(
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

                  // Return to the Login screen.
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back,
                      color: _forest,
                    ),
                    label: const Text(
                      'Back to Login',
                      style: TextStyle(
                        color: _forest,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
