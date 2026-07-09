/// Entitlement tiers - the client mirror of accounts/entitlements.py.
///
/// Today jibiki is a one-shot purchase: every tier resolves to full access
/// and nothing in the UI is gated. If the product pivots to freemium +
/// subscription, this file is the single flip point on the client:
///  1. set [localOnlyDefaultPlan] to 'free' (a free download can't assume
///     ownership without a store receipt),
///  2. wire the store SDK (RevenueCat / in_app_purchase) to refresh the
///     server plan, which then arrives via /auth/me and every /study/sync,
///  3. gate premium UI behind [isPremium] / the feature getters below.
///
/// The client value is presentation only - the server enforces entitlements
/// on its own checks (accounts.entitlements.IsPremium), so tampering with the
/// local flag can at most unlock buttons whose API calls will 403.
library;

import '../models/user.dart';

/// What a user without an account (local-only) is entitled to. 'lifetime'
/// while the app itself is paid up-front; flip to 'free' under freemium.
const String localOnlyDefaultPlan = 'lifetime';

class Entitlements {
  const Entitlements({required this.plan, this.expiresAt});

  /// free | premium | lifetime
  final String plan;
  final DateTime? expiresAt;

  factory Entitlements.of(UserProfile? profile, {bool localOnly = false}) {
    if (profile == null && localOnly) {
      return const Entitlements(plan: localOnlyDefaultPlan);
    }
    return Entitlements(
      plan: profile?.plan ?? 'free',
      expiresAt: profile?.planExpiresAt,
    );
  }

  bool get isPremium => switch (plan) {
        'lifetime' => true,
        'premium' => expiresAt == null || expiresAt!.isAfter(DateTime.now().toUtc()),
        _ => false,
      };

  // Feature gates - deliberately the only vocabulary the UI ever uses, so a
  // future tier split is a change HERE, not a hunt through the views. All of
  // them resolve to isPremium for now.
  bool get canDownloadPacks => isPremium;
  bool get canStudyOffline => isPremium;
  bool get canUseCommunity => isPremium;
}
