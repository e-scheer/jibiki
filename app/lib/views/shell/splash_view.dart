import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:jibiki/l10n/l10n.dart';

import '../../core/api_config.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/neo_pop.dart';

/// Animated continuation of the static native launch screen from exploration
/// 17. It stays useful during a slow bootstrap and exposes a retry on failure.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final loading = app.bootstrapping || app.bootstrapError == null;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? JibikiBrandColors.ink : JibikiBrandColors.klein;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: loading
              ? _LoadingBrandSplash(dark: dark)
              : _BootstrapError(dark: dark),
        ),
      ),
    );
  }
}

class _LoadingBrandSplash extends StatelessWidget {
  const _LoadingBrandSplash({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const JibikiBlockMark(),
                  const SizedBox(height: 34),
                  JibikiWordmark(
                    fontSize: 44,
                    variant: JibikiBrandVariant.negative,
                    dotOutline: dark ? Colors.white : JibikiBrandColors.ink,
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 44),
          child: Column(
            children: [
              const NeoChaseLoader(alternateFirst: true),
              const SizedBox(height: 22),
              Text(
                context.trText('dictionnaire libre, mémoire durable'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: dark ? JibikiBrandColors.lavender : Colors.white,
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const JibikiBlockMark(size: 104),
              const SizedBox(height: 28),
              JibikiWordmark(
                fontSize: 36,
                variant: JibikiBrandVariant.negative,
                dotOutline: dark ? Colors.white : JibikiBrandColors.ink,
              ),
              const SizedBox(height: 32),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: JibikiBrandColors.ink,
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: JibikiBrandColors.ink,
                        blurRadius: 0,
                        offset: Offset(6, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_outlined,
                        color: JibikiBrandColors.ink,
                        size: 30,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "Can't reach the server. Check your connection, then try again.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: JibikiBrandColors.ink,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ApiConfig.baseUrl,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF5D5866),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      NeoPrimaryButton(
                        label: context.trText('Try again'),
                        icon: Icons.refresh_rounded,
                        onTap: () => context.read<AppState>().bootstrap(),
                      ),
                      const SizedBox(height: 10),
                      NeoCard(
                        shadow: 0,
                        radius: 10,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        onTap: () => context.read<AppState>().logout(),
                        semanticLabel: context.trText('Sign in instead'),
                        child: Center(
                          child: Text(
                            context.trText('Sign in instead'),
                            style: TextStyle(
                              color: jc.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
