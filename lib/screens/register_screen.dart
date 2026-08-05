import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String selectedRole = 'tourist';
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  InputDecoration _fieldDecoration({
    required IconData prefixIcon,
    required String labelText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      prefixIcon: Icon(
        prefixIcon,
        color: AppColors.primary,
      ),
      labelText: labelText,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String label,
    required bool isLoading,
  }) {
    final bool isSelected = selectedRole == role;

    return Expanded(
      child: GestureDetector(
        onTap: isLoading
            ? null
            : () {
                setState(() {
                  selectedRole = role;
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 90,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.selectedBg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? AppColors.primary : Colors.grey,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? AppColors.primary : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    final FormState? currentForm = _formKey.currentState;

    if (currentForm == null || !currentForm.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final AuthController authCtrl = context.read<AuthController>();

    if (authCtrl.isLoading) {
      return;
    }

    final bool success = await authCtrl.register(
      _emailController.text.trim(),
      _passwordController.text,
      _fullNameController.text.trim(),
      selectedRole,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created successfully!',
          ),
          backgroundColor: AppColors.primary,
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            authCtrl.errorMessage ??
                'Unable to create account. Please try again.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/welcome',
      );
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authCtrl = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: authCtrl.isLoading ? null : _goBack,
        ),
        title: const Text(
          'LiveLocal',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create your account',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Join thousands discovering authentic Malaysia',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'I am a',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildRoleCard(
                    role: 'tourist',
                    icon: Icons.backpack,
                    label: 'Tourist',
                    isLoading: authCtrl.isLoading,
                  ),
                  const SizedBox(width: 12),
                  _buildRoleCard(
                    role: 'influencer',
                    icon: Icons.star,
                    label: 'Influencer',
                    isLoading: authCtrl.isLoading,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _fullNameController,
                      enabled: !authCtrl.isLoading,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [
                        AutofillHints.name,
                      ],
                      decoration: _fieldDecoration(
                        prefixIcon: Icons.person_outline,
                        labelText: 'Full Name',
                      ),
                      validator: (value) {
                        final String name = value?.trim() ?? '';

                        if (name.isEmpty) {
                          return 'Full name is required';
                        }

                        if (name.length < 2) {
                          return 'Full name must contain at least 2 characters';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      enabled: !authCtrl.isLoading,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      autofillHints: const [
                        AutofillHints.email,
                      ],
                      decoration: _fieldDecoration(
                        prefixIcon: Icons.email_outlined,
                        labelText: 'Email Address',
                      ),
                      validator: (value) {
                        final String email = value?.trim() ?? '';

                        if (email.isEmpty) {
                          return 'Email address is required';
                        }

                        final RegExp emailPattern = RegExp(
                          r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                        );

                        if (!emailPattern.hasMatch(email)) {
                          return 'Please enter a valid email address';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      enabled: !authCtrl.isLoading,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      decoration: _fieldDecoration(
                        prefixIcon: Icons.lock_outline,
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.primary,
                          ),
                          onPressed: authCtrl.isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }

                        if (value.length < 6) {
                          return 'Password must contain at least 6 characters';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      enabled: !authCtrl.isLoading,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.newPassword,
                      ],
                      onFieldSubmitted: (_) {
                        if (!authCtrl.isLoading) {
                          _handleRegister();
                        }
                      },
                      decoration: _fieldDecoration(
                        prefixIcon: Icons.lock_outline,
                        labelText: 'Confirm Password',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: AppColors.primary,
                          ),
                          onPressed: authCtrl.isLoading
                              ? null
                              : () {
                                  setState(() {
                                    _obscureConfirm = !_obscureConfirm;
                                  });
                                },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }

                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }

                        return null;
                      },
                    ),
                  ],
                ),
              ),
              if (selectedRole == 'influencer') ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warnBgLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Influencer accounts require admin approval before activation',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade800,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: authCtrl.isLoading ? null : _handleRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authCtrl.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                  ),
                  TextButton(
                    onPressed: authCtrl.isLoading
                        ? null
                        : () {
                            Navigator.pushReplacementNamed(
                              context,
                              '/login',
                            );
                          },
                    child: const Text(
                      'Log in',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
