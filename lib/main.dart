import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'constants/app_colors.dart';
import 'controllers/admin_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/guide_controller.dart';
import 'controllers/itinerary_controller.dart';
import 'controllers/localeats_controller.dart';
import 'controllers/moderation_controller.dart';
import 'controllers/notification_controller.dart';
import 'controllers/review_controller.dart';
import 'controllers/spot_controller.dart';
import 'repositories/supabase_repository.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/register_screen.dart';
import 'welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);

    debugPrint(
      'FlutterError caught: ${details.exception}',
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    debugPrint(
      'PlatformDispatcher error caught: $error',
    );

    return true;
  };

  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    debugPrint(
      'Could not load .env file: $error',
    );
  }

  final String? supabaseUrl = dotenv.env['SUPABASE_URL'];

  final String? supabaseKey =
      dotenv.env['SUPABASE_ANON_KEY'] ?? dotenv.env['SUPABASE_PUBLISHABLE_KEY'];

  await SupabaseRepository().initialize(
    url: supabaseUrl,
    publishableKey: supabaseKey,
  );

  runApp(const LiveLocalApp());
}

class LiveLocalApp extends StatelessWidget {
  const LiveLocalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(),
        ),
        ChangeNotifierProvider<SpotController>(
          create: (_) => SpotController(),
        ),
        ChangeNotifierProvider<LocalEatsController>(
          create: (_) => LocalEatsController(),
        ),
        ChangeNotifierProvider<ItineraryController>(
          create: (_) => ItineraryController(),
        ),
        ChangeNotifierProvider<GuideController>(
          create: (_) => GuideController(),
        ),
        ChangeNotifierProvider<ReviewController>(
          create: (_) => ReviewController(),
        ),
        ChangeNotifierProvider<AdminController>(
          create: (_) => AdminController(),
        ),
        ChangeNotifierProvider<NotificationController>(
          create: (_) => NotificationController(),
        ),
        ChangeNotifierProvider<ModerationController>(
          create: (_) => ModerationController(),
        ),
      ],
      child: MaterialApp(
        title: 'LiveLocal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.accent,
            surface: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(
                color: AppColors.primary,
              ),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        home: const AuthGate(),
        routes: {
          '/welcome': (BuildContext context) => const WelcomeScreen(),
          '/login': (BuildContext context) => const LoginScreen(),
          '/register': (BuildContext context) => const RegisterScreen(),
          '/home': (BuildContext context) => const MainNavigationScreen(),
        },
      ),
    );
  }
}
