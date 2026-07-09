/// Dev-only convenience: pre-filled local test accounts for the login screen, so
/// a tester - or a device where keyboard injection is blocked - can sign in in a
/// tap or two. Gated by the compile-time flag `JIBIKI_DEV_LOGIN`; it is `false` in
/// any normal (release/prod) build, so these credentials ship nowhere near it.
///
///   flutter build apk --dart-define=JIBIKI_DEV_LOGIN=true
library;

class DevLogin {
  DevLogin._();

  /// True only when built with `--dart-define=JIBIKI_DEV_LOGIN=true`.
  static const bool enabled = bool.fromEnvironment('JIBIKI_DEV_LOGIN');

  /// Local test accounts (all share the same dev password). First is the default
  /// the form pre-fills with; the rest are one-tap chips.
  static const List<({String label, String email, String password})> accounts = [
    (label: 'test', email: 'test@jibiki.dev', password: 'testpass123'),
    (label: 'egon', email: 'egon.scheer@hotmail.com', password: 'testpass123'),
    (label: 'streeter', email: 'streeter08@hotmail.com', password: 'testpass123'),
  ];
}
