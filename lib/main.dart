import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'constants/app_colors.dart';
import 'repositories/supabase_repository.dart';
import 'features/auth/data/demo_auth_repository.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/auth/domain/auth_repository.dart';
import 'features/auth/presentation/password_reset_screen.dart';
import 'features/auth/presentation/session_gate.dart';
import 'features/profile/data/demo_account_repository.dart';
import 'features/profile/data/supabase_account_repository.dart';
import 'features/profile/domain/account_repository.dart';
import 'features/profile/presentation/account_controller.dart';
import 'screens/notifications_screen.dart';

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

  late final AuthRepository authRepository;
  late final AccountRepository accountRepository;
  try {
    if (configuration.isDemo) {
      SupabaseRepository().configureForDemo();
      final demoAuthRepository = DemoAuthRepository();
      authRepository = demoAuthRepository;
      accountRepository = DemoAccountRepository(demoAuthRepository);
    } else {
      await Supabase.initialize(
        url: configuration.supabaseUrl!,
        publishableKey: configuration.supabasePublishableKey!,
      );
      SupabaseRepository().attachToInitializedSupabase();
      final supabaseAuthRepository = SupabaseAuthRepository(
        client: Supabase.instance.client,
        redirectUrl: configuration.authRedirectUrl,
      );
      authRepository = supabaseAuthRepository;
      accountRepository = SupabaseAccountRepository(
        client: Supabase.instance.client,
        authRepository: supabaseAuthRepository,
      );
    }
  } catch (error) {
    if (kDebugMode) {
      debugPrint('Backend initialization failed: $error');
    }
    runApp(
      const ConfigurationFailureApp(
        message:
            'The configured backend could not be initialized. Check the environment settings and try again.',
      ),
    );
    return;
  }

  runApp(
    LiveLocalApp(
      configuration: configuration,
      authRepository: authRepository,
      accountRepository: accountRepository,
    ),
  );
}

class LiveLocalApp extends StatelessWidget {
  const LiveLocalApp({
    super.key,
    required this.configuration,
    required this.authRepository,
    required this.accountRepository,
  });

  final AppConfiguration configuration;
  final AuthRepository authRepository;
  final AccountRepository accountRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfiguration>.value(value: configuration),
        ChangeNotifierProvider(
          create: (_) =>
              AuthController(repository: authRepository)..initialize(),
        ),
        ChangeNotifierProvider(
          create: (context) => AccountController(
            repository: accountRepository,
            authController: context.read<AuthController>(),
          ),
        ),
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
          '/password-reset': (context) => const PasswordResetScreen(),
          '/notifications': (context) => const NotificationsScreen(),
          '/home': (context) => const SessionGate(),
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
