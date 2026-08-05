import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';

class ProtectedNavigation {
  String? _pendingRoute;

  void open(BuildContext context, String routeName) {
    final auth = context.read<AuthController>();
    if (auth.canWrite) {
      Navigator.pushNamed(context, routeName);
      return;
    }
    _pendingRoute = routeName;
    Navigator.pushNamed(context, '/login');
  }

  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }
}
