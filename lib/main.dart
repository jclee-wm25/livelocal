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
import 'features/spots/data/demo_spot_repository.dart';
import 'features/spots/data/supabase_spot_repository.dart';
import 'features/spots/domain/spot_repository.dart';
import 'core/routing/protected_navigation.dart';
import 'screens/submit_spot_screen.dart';
import 'features/reviews/data/demo_review_repository.dart';
import 'features/reviews/data/supabase_review_repository.dart';
import 'features/reviews/domain/review_repository.dart';
import 'features/admin/data/demo_admin_repository.dart';
import 'features/admin/data/supabase_admin_repository.dart';
import 'features/admin/domain/admin_repository.dart';
import 'features/influencer_applications/data/demo_influencer_application_repository.dart';
import 'features/influencer_applications/data/supabase_influencer_application_repository.dart';
import 'features/influencer_applications/domain/influencer_application_repository.dart';
import 'features/influencer_applications/presentation/creator_application_screen.dart';
import 'features/influencer_applications/presentation/influencer_application_controller.dart';
import 'features/restaurants/data/demo_local_eats_repository.dart';
import 'features/restaurants/data/supabase_local_eats_repository.dart';
import 'features/restaurants/domain/local_eats_repository.dart';
import 'screens/restaurant_detail_screen.dart';
import 'screens/saved_places_screen.dart';
import 'screens/spot_detail_screen.dart';
import 'screens/guide_detail_screen.dart';
import 'features/itinerary/data/demo_saved_itinerary_repository.dart';
import 'features/itinerary/data/supabase_saved_itinerary_repository.dart';
import 'features/itinerary/domain/saved_itinerary_repository.dart';
import 'features/guides/data/demo_guide_repository.dart';
import 'features/guides/data/supabase_guide_repository.dart';
import 'features/guides/domain/guide_repository.dart';
import 'features/notifications/data/demo_notification_repository.dart';
import 'features/notifications/data/supabase_notification_repository.dart';
import 'features/notifications/domain/notification_repository.dart';
import 'features/notifications/presentation/notification_controller.dart';
import 'features/moderation/data/demo_moderation_repository.dart';
import 'features/moderation/data/supabase_moderation_repository.dart';
import 'features/moderation/domain/moderation_repository.dart';
import 'app/theme/app_theme.dart';
import 'features/moderation/presentation/blocked_users_screen.dart';
import 'screens/my_submissions_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Raw exception details are development-only. Production telemetry remains
  // deliberately unconfigured until a privacy-reviewed provider is approved.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Unhandled platform error: $error');
    }
    // Do not convert an unhandled failure into a false successful state.
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
  late final SpotRepository spotRepository;
  late final ReviewRepository reviewRepository;
  late final AdminRepository adminRepository;
  late final InfluencerApplicationRepository influencerApplicationRepository;
  late final LocalEatsRepository localEatsRepository;
  late final SavedItineraryRepository savedItineraryRepository;
  late final GuideRepository guideRepository;
  late final NotificationRepository notificationRepository;
  late final ModerationRepository moderationRepository;
  try {
    if (configuration.isDemo) {
      final demoAuthRepository = DemoAuthRepository();
      authRepository = demoAuthRepository;
      final demoAccountRepository = DemoAccountRepository(demoAuthRepository);
      accountRepository = demoAccountRepository;
      spotRepository = DemoSpotRepository(demoAuthRepository);
      reviewRepository = DemoReviewRepository(demoAuthRepository);
      adminRepository =
          DemoAdminRepository(demoAuthRepository, demoAccountRepository);
      influencerApplicationRepository =
          DemoInfluencerApplicationRepository(demoAuthRepository);
      localEatsRepository = DemoLocalEatsRepository(demoAuthRepository);
      savedItineraryRepository =
          DemoSavedItineraryRepository(demoAuthRepository);
      guideRepository = DemoGuideRepository(demoAuthRepository);
      notificationRepository = DemoNotificationRepository(demoAuthRepository);
      moderationRepository = DemoModerationRepository(demoAuthRepository);
    } else {
      await Supabase.initialize(
        url: configuration.supabaseUrl!,
        publishableKey: configuration.supabasePublishableKey!,
      );
      final supabaseAuthRepository = SupabaseAuthRepository(
        client: Supabase.instance.client,
        redirectUrl: configuration.authRedirectUrl,
      );
      authRepository = supabaseAuthRepository;
      accountRepository = SupabaseAccountRepository(
        client: Supabase.instance.client,
        authRepository: supabaseAuthRepository,
      );
      spotRepository = SupabaseSpotRepository(Supabase.instance.client);
      reviewRepository = SupabaseReviewRepository(Supabase.instance.client);
      adminRepository = SupabaseAdminRepository(Supabase.instance.client);
      influencerApplicationRepository =
          SupabaseInfluencerApplicationRepository(Supabase.instance.client);
      localEatsRepository =
          SupabaseLocalEatsRepository(Supabase.instance.client);
      savedItineraryRepository =
          SupabaseSavedItineraryRepository(Supabase.instance.client);
      guideRepository = SupabaseGuideRepository(Supabase.instance.client);
      notificationRepository =
          SupabaseNotificationRepository(Supabase.instance.client);
      moderationRepository =
          SupabaseModerationRepository(Supabase.instance.client);
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
      spotRepository: spotRepository,
      reviewRepository: reviewRepository,
      adminRepository: adminRepository,
      influencerApplicationRepository: influencerApplicationRepository,
      localEatsRepository: localEatsRepository,
      savedItineraryRepository: savedItineraryRepository,
      guideRepository: guideRepository,
      notificationRepository: notificationRepository,
      moderationRepository: moderationRepository,
    ),
  );
}

class LiveLocalApp extends StatelessWidget {
  const LiveLocalApp({
    super.key,
    required this.configuration,
    required this.authRepository,
    required this.accountRepository,
    required this.spotRepository,
    required this.reviewRepository,
    required this.adminRepository,
    required this.influencerApplicationRepository,
    required this.localEatsRepository,
    required this.savedItineraryRepository,
    required this.guideRepository,
    required this.notificationRepository,
    required this.moderationRepository,
  });

  final AppConfiguration configuration;
  final AuthRepository authRepository;
  final AccountRepository accountRepository;
  final SpotRepository spotRepository;
  final ReviewRepository reviewRepository;
  final AdminRepository adminRepository;
  final InfluencerApplicationRepository influencerApplicationRepository;
  final LocalEatsRepository localEatsRepository;
  final SavedItineraryRepository savedItineraryRepository;
  final GuideRepository guideRepository;
  final NotificationRepository notificationRepository;
  final ModerationRepository moderationRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfiguration>.value(value: configuration),
        Provider<ProtectedNavigation>(create: (_) => ProtectedNavigation()),
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
        ChangeNotifierProvider(
          create: (_) => SpotController(repository: spotRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => LocalEatsController(repository: localEatsRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              ItineraryController(repository: savedItineraryRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => GuideController(repository: guideRepository),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              NotificationController(repository: notificationRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => ReviewController(repository: reviewRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => AdminController(repository: adminRepository),
        ),
        ChangeNotifierProvider(
          create: (_) => InfluencerApplicationController(
            repository: influencerApplicationRepository,
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => ModerationController(repository: moderationRepository),
        ),
      ],
      child: MaterialApp(
        title: 'LiveLocal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
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
          '/blocked-users': (context) => const BlockedUsersScreen(),
          '/my-submissions': (context) => const MySubmissionsScreen(),
          '/submit-spot': (context) => const SubmitSpotScreen(),
          '/creator-application': (context) => const CreatorApplicationScreen(),
          '/restaurant-detail': (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;
            if (arguments is! RestaurantDetailArguments) {
              return const ConfigurationFailureApp(
                message: 'The requested restaurant is unavailable.',
              );
            }
            return RestaurantDetailScreen(
              restaurant: arguments.restaurant,
              pendingAction: arguments.pendingAction,
            );
          },
          '/saved-places': (context) => const SavedPlacesScreen(),
          '/spot-detail': (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;
            if (arguments is! SpotDetailArguments) {
              return const ConfigurationFailureApp(
                message: 'The requested spot is unavailable.',
              );
            }
            return SpotDetailScreen(
              spot: arguments.spot,
              pendingAction: arguments.pendingAction,
            );
          },
          '/guide-detail': (context) {
            final arguments = ModalRoute.of(context)?.settings.arguments;
            if (arguments is! GuideDetailArguments) {
              return const ConfigurationFailureApp(
                message: 'The requested guide is unavailable.',
              );
            }
            return GuideDetailScreen(
              guide: arguments.guide,
              pendingReport: arguments.pendingReport,
            );
          },
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
