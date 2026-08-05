import 'package:flutter/foundation.dart';

enum AppEnvironment { demo, staging, production }

class AppConfigurationException implements Exception {
  const AppConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppConfiguration {
  const AppConfiguration._({
    required this.environment,
    this.supabaseUrl,
    this.supabasePublishableKey,
  });

  final AppEnvironment environment;
  final String? supabaseUrl;
  final String? supabasePublishableKey;

  bool get isDemo => environment == AppEnvironment.demo;

  static AppConfiguration fromCompileTime() {
    return fromValues(
      environment: const String.fromEnvironment('APP_ENV'),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey:
          const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      isRelease: kReleaseMode,
    );
  }

  static AppConfiguration fromValues({
    required String environment,
    String supabaseUrl = '',
    String supabasePublishableKey = '',
    required bool isRelease,
  }) {
    switch (environment.trim().toLowerCase()) {
      case 'demo':
        if (isRelease) {
          throw const AppConfigurationException(
            'Demo mode is disabled in release builds.',
          );
        }
        return const AppConfiguration._(environment: AppEnvironment.demo);
      case 'staging':
      case 'production':
        if (supabaseUrl.trim().isEmpty ||
            supabasePublishableKey.trim().isEmpty) {
          throw const AppConfigurationException(
            'Supabase URL and publishable key are required for this environment.',
          );
        }
        return AppConfiguration._(
          environment: environment.trim().toLowerCase() == 'staging'
              ? AppEnvironment.staging
              : AppEnvironment.production,
          supabaseUrl: supabaseUrl.trim(),
          supabasePublishableKey: supabasePublishableKey.trim(),
        );
      default:
        throw const AppConfigurationException(
          'APP_ENV must be explicitly set to demo, staging, or production.',
        );
    }
  }

  static AppConfiguration demoForTesting() {
    return fromValues(environment: 'demo', isRelease: false);
  }
}
