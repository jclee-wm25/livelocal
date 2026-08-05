import 'dart:convert';

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
    required this.authRedirectUrl,
    required this.supportEmail,
  });

  final AppEnvironment environment;
  final String? supabaseUrl;
  final String? supabasePublishableKey;
  final Uri authRedirectUrl;
  final String supportEmail;

  bool get isDemo => environment == AppEnvironment.demo;

  static AppConfiguration fromCompileTime() {
    return fromValues(
      environment: const String.fromEnvironment('APP_ENV'),
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey:
          const String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
      authRedirectUrl: const String.fromEnvironment(
        'AUTH_REDIRECT_URL',
        defaultValue: 'io.livelocal.app://auth/callback',
      ),
      supportEmail: const String.fromEnvironment(
        'SUPPORT_EMAIL',
        defaultValue: 'support@livelocal.app',
      ),
      isRelease: kReleaseMode,
    );
  }

  static AppConfiguration fromValues({
    required String environment,
    String supabaseUrl = '',
    String supabasePublishableKey = '',
    String authRedirectUrl = 'io.livelocal.app://auth/callback',
    String supportEmail = 'support@livelocal.app',
    required bool isRelease,
  }) {
    final redirectUri = Uri.tryParse(authRedirectUrl.trim());
    if (redirectUri == null ||
        !redirectUri.hasScheme ||
        redirectUri.scheme.toLowerCase() != 'io.livelocal.app' ||
        redirectUri.host.toLowerCase() != 'auth' ||
        redirectUri.path != '/callback') {
      throw const AppConfigurationException(
        'AUTH_REDIRECT_URL must be io.livelocal.app://auth/callback.',
      );
    }
    final normalizedSupportEmail = supportEmail.trim().toLowerCase();
    if (!_looksLikeEmail(normalizedSupportEmail)) {
      throw const AppConfigurationException(
        'SUPPORT_EMAIL must be a valid email address.',
      );
    }

    switch (environment.trim().toLowerCase()) {
      case 'demo':
        if (isRelease) {
          throw const AppConfigurationException(
            'Demo mode is disabled in release builds.',
          );
        }
        return AppConfiguration._(
          environment: AppEnvironment.demo,
          authRedirectUrl: redirectUri,
          supportEmail: normalizedSupportEmail,
        );
      case 'staging':
      case 'production':
        if (supabaseUrl.trim().isEmpty ||
            supabasePublishableKey.trim().isEmpty) {
          throw const AppConfigurationException(
            'Supabase URL and publishable key are required for this environment.',
          );
        }
        final backendUri = Uri.tryParse(supabaseUrl.trim());
        final isLoopbackDevelopment = !isRelease &&
            backendUri?.scheme == 'http' &&
            {'localhost', '127.0.0.1', '::1'}.contains(backendUri?.host);
        if (backendUri == null ||
            !backendUri.hasAuthority ||
            (backendUri.scheme != 'https' && !isLoopbackDevelopment)) {
          throw const AppConfigurationException(
            'SUPABASE_URL must use HTTPS. Non-release loopback development is the only exception.',
          );
        }
        if (_isPrivilegedKey(supabasePublishableKey.trim())) {
          throw const AppConfigurationException(
            'A service-role or secret Supabase key must never be embedded in the app.',
          );
        }
        return AppConfiguration._(
          environment: environment.trim().toLowerCase() == 'staging'
              ? AppEnvironment.staging
              : AppEnvironment.production,
          supabaseUrl: supabaseUrl.trim(),
          supabasePublishableKey: supabasePublishableKey.trim(),
          authRedirectUrl: redirectUri,
          supportEmail: normalizedSupportEmail,
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

  static bool _looksLikeEmail(String value) {
    final separator = value.indexOf('@');
    return separator > 0 &&
        separator < value.length - 3 &&
        value.substring(separator + 1).contains('.');
  }

  static bool _isPrivilegedKey(String value) {
    final normalized = value.toLowerCase();
    if (normalized.startsWith('sb_secret_') ||
        normalized.contains('service_role')) {
      return true;
    }
    final parts = value.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      return claims is Map<String, dynamic> && claims['role'] == 'service_role';
    } on FormatException {
      return false;
    }
  }
}
