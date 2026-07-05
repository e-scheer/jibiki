import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shown only while AppState.bootstrap() resolves the session on cold start.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('字', style: TextStyle(fontSize: 72, fontWeight: FontWeight.w600, color: context.jc.brand)),
            const SizedBox(height: 8),
            const Text('jibiki', style: TextStyle(fontSize: 18, letterSpacing: 2)),
            const SizedBox(height: 28),
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
      ),
    );
  }
}
