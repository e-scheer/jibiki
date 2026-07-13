import 'package:web/web.dart' as web;

/// allauth appends provider errors before the hash fragment in hash-routing
/// deployments. Flutter's hash strategy only exposes the fragment to GoRouter,
/// so read the outer query as a Web fallback.
Map<String, String> readOuterAuthCallbackQuery() {
  try {
    final search = web.window.location.search;
    if (search.isEmpty || search == '?') return const {};
    return Uri.splitQueryString(search.substring(1));
  } catch (_) {
    return const {};
  }
}
