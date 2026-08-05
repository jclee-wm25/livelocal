import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../core/config/app_environment.dart';
import '../core/routing/protected_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _showError = false;
  String _errorMessage = '';
  bool _obscurePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  InputDecoration _fieldDecoration({
    required IconData prefixIcon,
    required String labelText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      prefixIcon: Icon(prefixIcon, color: AppColors.primary),
      labelText: labelText,
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }

  void _clearError() {
    if (!_showError) return;
    setState(() {
      _showError = false;
      _errorMessage = '';
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final currentForm = _formKey.currentState;
    if (currentForm == null || !currentForm.validate()) return;
    final authCtrl = context.read<AuthController>();
    if (authCtrl.isLoading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _showError = false;
      _errorMessage = '';
    });
    final success = await authCtrl.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      final navigator = Navigator.of(context);
      final pending = context.read<ProtectedNavigation>().consumePending();
      navigator.pushNamedAndRemoveUntil('/home', (route) => false);
      if (pending != null && authCtrl.canWrite) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          navigator.pushNamed(
            pending.routeName,
            arguments: pending.arguments,
          );
        });
      }
    } else {
      setState(() {
        _showError = true;
        _errorMessage = authCtrl.errorMessage ??
            'Invalid email or password. Please try again.';
      });
    }
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, '/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();
    final isSubmitting = authController.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: isSubmitting ? null : _goBack,
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
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Log in to continue exploring',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                if (_showError) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        onChanged: (_) => _clearError(),
                        decoration: _fieldDecoration(
                          prefixIcon: Icons.email_outlined,
                          labelText: 'Email Address',
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty) {
                            return 'Email address is required';
                          }
                          final emailPattern = RegExp(
                            r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
                          );
                          if (!emailPattern.hasMatch(email)) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !isSubmitting,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onChanged: (_) => _clearError(),
                        onFieldSubmitted: (_) {
                          if (!isSubmitting) _handleLogin();
                        },
                        decoration: _fieldDecoration(
                          prefixIcon: Icons.lock_outline,
                          labelText: 'Password',
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: AppColors.primary,
                            ),
                            onPressed: isSubmitting
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
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pushNamed(context, '/password-reset'),
                    child: const Text('Forgot password?'),
                  ),
                ),
                if (context.read<AppConfiguration>().isDemo) ...[
                  const Text(
                    'Demo mode uses the fixed password 123456 and does not contact production services.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
