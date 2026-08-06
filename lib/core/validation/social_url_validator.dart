class SocialUrlValidator {
  static const supportedPlatforms = {'tiktok', 'instagram'};

  static bool isSupported(String value, {String? platform}) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'https' || uri.hasPort) {
      return false;
    }
    final host = uri.host.toLowerCase();
    final normalizedHost = host.startsWith('www.') ? host.substring(4) : host;
    if (normalizedHost != 'tiktok.com' && normalizedHost != 'instagram.com') {
      return false;
    }
    return platform == null || normalizedHost == '$platform.com';
  }
}
