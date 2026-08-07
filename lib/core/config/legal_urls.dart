import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

abstract class AppLauncher {
  Future<bool> launch(Uri url);
}

class DefaultAppLauncher implements AppLauncher {
  const DefaultAppLauncher();

  @override
  Future<bool> launch(Uri url) async {
    if (url.scheme != 'https') {
      return false;
    }
    return ul.launchUrl(url, mode: ul.LaunchMode.externalApplication);
  }
}

class LegalUrls {
  const LegalUrls({
    required this.terms,
    required this.privacy,
    required this.communityRules,
    required this.support,
  });

  final Uri terms;
  final Uri privacy;
  final Uri communityRules;
  final Uri support;

  static LegalUrls fromCompileTime() {
    return fromValues(
      termsUrl: const String.fromEnvironment('URL_TERMS'),
      privacyUrl: const String.fromEnvironment('URL_PRIVACY'),
      rulesUrl: const String.fromEnvironment('URL_RULES'),
      supportUrl: const String.fromEnvironment('URL_SUPPORT'),
      isRelease: kReleaseMode,
    );
  }

  static LegalUrls fromValues({
    required String termsUrl,
    required String privacyUrl,
    required String rulesUrl,
    required String supportUrl,
    required bool isRelease,
  }) {
    final t =
        termsUrl.isEmpty ? 'https://livelocal.app/placeholder-terms' : termsUrl;
    final p = privacyUrl.isEmpty
        ? 'https://livelocal.app/placeholder-privacy'
        : privacyUrl;
    final r =
        rulesUrl.isEmpty ? 'https://livelocal.app/placeholder-rules' : rulesUrl;
    final s = supportUrl.isEmpty
        ? 'https://livelocal.app/placeholder-support'
        : supportUrl;

    if (isRelease) {
      if (termsUrl.isEmpty ||
          privacyUrl.isEmpty ||
          rulesUrl.isEmpty ||
          supportUrl.isEmpty) {
        throw Exception(
          'Deployment requirement: Final production URLs must be explicitly provided via '
          '--dart-define (URL_TERMS, URL_PRIVACY, URL_RULES, URL_SUPPORT). '
          'Placeholder domains are not permitted in release builds.',
        );
      }
    }

    return LegalUrls(
      terms: _parseAndValidate(t, 'Terms'),
      privacy: _parseAndValidate(p, 'Privacy'),
      communityRules: _parseAndValidate(r, 'Community Rules'),
      support: _parseAndValidate(s, 'Support'),
    );
  }

  static Uri _parseAndValidate(String urlString, String name) {
    final uri = Uri.tryParse(urlString.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw FormatException(
          '$name URL must be a parseable HTTPS URI with a non-empty host. Got: $urlString');
    }
    return uri;
  }
}
