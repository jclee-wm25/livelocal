import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../welcome_screen.dart';
import 'main_navigation_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = context.watch<AuthController>();

    if (authController.isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (authController.isAuthenticated) {
      return const MainNavigationScreen();
    }

    return const WelcomeScreen();
  }
}
