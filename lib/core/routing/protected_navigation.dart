import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';

class ProtectedNavigation {
  PendingProtectedNavigation? _pending;

  void open(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    final auth = context.read<AuthController>();
    if (auth.canWrite) {
      Navigator.pushNamed(context, routeName, arguments: arguments);
      return;
    }
    _pending = PendingProtectedNavigation(
      routeName: routeName,
      arguments: arguments,
    );
    Navigator.pushNamed(context, '/login');
  }

  PendingProtectedNavigation? consumePending() {
    final pending = _pending;
    _pending = null;
    return pending;
  }
}

class PendingProtectedNavigation {
  const PendingProtectedNavigation({
    required this.routeName,
    this.arguments,
  });

  final String routeName;
  final Object? arguments;
}
