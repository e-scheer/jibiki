import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/entitlements.dart';
import 'package:jibiki/models/user.dart';

UserProfile _profile(String plan, {DateTime? expires}) =>
    UserProfile.fromJson({
      'plan': plan,
      if (expires != null) 'plan_expires_at': expires.toIso8601String(),
    });

void main() {
  test('one-shot purchase: everything resolves to full access', () {
    final lifetime = Entitlements.of(_profile('lifetime'));
    expect(lifetime.isPremium, isTrue);
    expect(lifetime.canDownloadPacks, isTrue);
    expect(lifetime.canStudyOffline, isTrue);
    expect(lifetime.canUseCommunity, isTrue);

    // A profile that predates the plan field defaults to lifetime too.
    expect(Entitlements.of(UserProfile.fromJson(const {})).isPremium, isTrue);

    // No account (local-only) is owner of a paid app today.
    expect(Entitlements.of(null, localOnly: true).isPremium, isTrue);
  });

  test('the freemium rules are ready: free blocked, premium honors expiry', () {
    expect(Entitlements.of(_profile('free')).isPremium, isFalse);
    expect(
      Entitlements.of(_profile('premium',
              expires: DateTime.now().toUtc().add(const Duration(days: 30))))
          .isPremium,
      isTrue,
    );
    expect(
      Entitlements.of(_profile('premium',
              expires: DateTime.now().toUtc().subtract(const Duration(minutes: 1))))
          .isPremium,
      isFalse,
    );
    // Grace period: premium with no recorded expiry stays honored.
    expect(Entitlements.of(_profile('premium')).isPremium, isTrue);
  });

  test('plan round-trips through the cached-user serialization', () {
    final expires = DateTime.utc(2027, 1, 1);
    final profile = _profile('premium', expires: expires);
    final restored = UserProfile.fromJson(profile.toJson());
    expect(restored.plan, 'premium');
    expect(restored.planExpiresAt, expires);
  });
}
