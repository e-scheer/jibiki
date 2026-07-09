import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_config.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';

/// Shown while AppState.bootstrap() resolves the session on cold start. It echoes
/// the native splash (vermilion 字 on white) so the hand-off from the OS launch
/// screen into Flutter is seamless: the glyph breathes as the "still loading" cue.
/// If the server can't be reached, it turns into an honest retry instead of
/// bouncing a signed-in user to the login screen.
class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final app = context.watch<AppState>();
    final retrying = app.bootstrapping;
    final error = app.bootstrapError;
    // Breathe while connecting (first load or a retry in flight); hold still only
    // once we've stopped to ask for a retry.
    final loading = retrying || error == null;

    Widget glyph = Text(
      '字',
      style: TextStyle(fontFamily: 'NotoSansJP', fontSize: 104, fontWeight: FontWeight.w600, color: jc.brand),
    );
    // Breathe only while actually loading; hold still once we're asking to retry.
    if (loading && Motion.enabled(context)) {
      glyph = AnimatedBuilder(
        animation: _c,
        child: glyph,
        builder: (_, child) {
          final t = Curves.easeInOut.transform(_c.value);
          return Opacity(
            opacity: 0.82 + 0.18 * t,
            child: Transform.scale(scale: 1.0 + 0.04 * t, child: child),
          );
        },
      );
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              glyph,
              const SizedBox(height: 10),
              Text('jibiki',
                  style: TextStyle(fontSize: 17, letterSpacing: 3, fontWeight: FontWeight.w700, color: jc.ink)),
              if (retrying) ...[
                const SizedBox(height: 20),
                Text('Connecting…', style: TextStyle(color: jc.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              ] else if (error != null) ...[
                const SizedBox(height: 28),
                Icon(Icons.cloud_off_outlined, color: jc.muted, size: 26),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Column(
                    children: [
                      Text(
                        "Can't reach the server. Check your connection, then try again.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: jc.body, height: 1.4),
                      ),
                      const SizedBox(height: 8),
                      // Surface the target so a wrong host (e.g. a physical device
                      // still pointed at the emulator's 10.0.2.2) is obvious.
                      Text(
                        ApiConfig.baseUrl,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: jc.muted, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.read<AppState>().bootstrap(),
                  child: const Text('Try again'),
                ),
                const SizedBox(height: 2),
                // Escape hatch: never trap a user on the splash when the API is
                // unreachable or the stored session is unusable - always let them
                // drop it and reach the sign-in screen.
                TextButton(
                  onPressed: () => context.read<AppState>().logout(),
                  child: const Text('Sign in instead'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
