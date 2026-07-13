import 'dart:convert';

import 'package:web/web.dart' as web;

const _cookieName = 'jibiki_consent_v1';

Future<({bool? analytics, bool? diagnostics})?>
    readSharedTelemetryConsent() async {
  try {
    for (final part in web.document.cookie.split(';')) {
      final separator = part.indexOf('=');
      if (separator < 0) continue;
      final key = part.substring(0, separator).trim();
      if (key != _cookieName) continue;
      final value = Uri.decodeComponent(part.substring(separator + 1).trim());
      if (value == 'granted') return (analytics: true, diagnostics: true);
      if (value == 'denied') return (analytics: false, diagnostics: false);
      final decoded = jsonDecode(value);
      if (decoded is! Map || decoded['version'] != 1) return null;
      return (
        analytics: decoded['analytics'] as bool?,
        diagnostics: decoded['diagnostics'] as bool?,
      );
    }
  } catch (_) {
    return null;
  }
  return null;
}

Future<void> writeSharedTelemetryConsent({
  required bool analytics,
  required bool diagnostics,
}) async {
  try {
    final hostname = web.window.location.hostname;
    final productionDomain = hostname == 'jibiki.app' ||
        hostname == 'www.jibiki.app' ||
        hostname.endsWith('.jibiki.app');
    final secure = web.window.location.protocol == 'https:';
    final attributes = <String>[
      'Path=/',
      'Max-Age=31536000',
      'SameSite=Lax',
      if (productionDomain) 'Domain=.jibiki.app',
      if (secure) 'Secure',
    ];
    final value = Uri.encodeComponent(jsonEncode({
      'version': 1,
      'analytics': analytics,
      'diagnostics': diagnostics,
    }));
    web.document.cookie = '$_cookieName=$value; ${attributes.join('; ')}';
  } catch (_) {
    // Browser privacy settings must never block the settings screen.
  }
}
