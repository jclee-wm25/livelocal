import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'core/config/app_environment.dart';
import 'controllers/auth_controller.dart';
import 'controllers/spot_controller.dart';
import 'controllers/localeats_controller.dart';
import 'controllers/itinerary_controller.dart';
import 'controllers/guide_controller.dart';
import 'controllers/review_controller.dart';
import 'controllers/admin_controller.dart';
import 'controllers/moderation_controller.dart';

import 'welcome_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'constants/app_colors.dart';
import 'repositories/supabase_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Phase 11 will replace these development handlers with a reviewed,
  // privacy-aware production telemetry implementation.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError caught: ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('PlatformDispatcher Error caught: $error');
    return false;
  };

  late final AppConfiguration configuration;
  try {
    configuration = AppConfiguration.fromCompileTime();
  } on AppConfigurationException catch (error) {
    runApp(ConfigurationFailureApp(message: error.message));
    return;
  }

  if (!configuration.isDemo) {
    // Phase 2 is intentionally not authorized yet. Do not partially activate a
    // production/staging backend with the prototype's incomplete RLS contract.
    runApp(
      const ConfigurationFailureApp(
        message:
            'Staging and production activation require the approved Supabase foundation phase.',
      ),
    );
    return;
  }

  SupabaseRepository().configureForDemo();
  runApp(LiveLocalApp(configuration: configuration));
}

class LiveLocalApp extends StatelessWidget {
  const LiveLocalApp({super.key, required this.configuration});

  final AppConfiguration configuration;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthController()),
        ChangeNotifierProvider(create: (_) => SpotController()),
        ChangeNotifierProvider(create: (_) => LocalEatsController()),
        ChangeNotifierProvider(create: (_) => ItineraryController()),
        ChangeNotifierProvider(create: (_) => GuideController()),
        ChangeNotifierProvider(create: (_) => ReviewController()),
        ChangeNotifierProvider(create: (_) => AdminController()),
        ChangeNotifierProvider(create: (_) => ModerationController()),
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
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        initialRoute: '/home',
        builder: (context, child) {
          final content = child ?? const SizedBox.shrink();
          if (!configuration.isDemo) return content;
          return Banner(
            message: 'DEMO',
            location: BannerLocation.topEnd,
            color: AppColors.error,
            child: content,
          );
        },
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const MainNavigationScreen(),
        },
      ),
    );
  }
}

class ConfigurationFailureApp extends StatelessWidget {
  const ConfigurationFailureApp({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'LiveLocal is not configured',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
