import 'enums.dart';

/// Per-user product settings (mirrors accounts.UserProfile on the server).
class UserProfile {
  UserProfile({
    required this.mode,
    required this.displayName,
    required this.mnemonicLanguage,
    required this.desiredRetention,
    required this.newCardsPerDay,
    required this.timezone,
    required this.notificationsEnabled,
    required this.notifyThreshold,
  });

  final AppMode mode;
  final String displayName;
  final String mnemonicLanguage;
  final double desiredRetention;
  final int newCardsPerDay;
  final String timezone;
  final bool notificationsEnabled;
  final int notifyThreshold;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        mode: AppMode.fromString(json['mode'] as String?),
        displayName: (json['display_name'] as String?) ?? '',
        mnemonicLanguage: (json['mnemonic_language'] as String?) ?? 'en',
        desiredRetention: (json['desired_retention'] as num?)?.toDouble() ?? 0.9,
        newCardsPerDay: (json['new_cards_per_day'] as num?)?.toInt() ?? 15,
        timezone: (json['timezone'] as String?) ?? 'UTC',
        notificationsEnabled: (json['notifications_enabled'] as bool?) ?? false,
        notifyThreshold: (json['notify_threshold'] as num?)?.toInt() ?? 15,
      );

  UserProfile copyWith({AppMode? mode, String? mnemonicLanguage}) => UserProfile(
        mode: mode ?? this.mode,
        displayName: displayName,
        mnemonicLanguage: mnemonicLanguage ?? this.mnemonicLanguage,
        desiredRetention: desiredRetention,
        newCardsPerDay: newCardsPerDay,
        timezone: timezone,
        notificationsEnabled: notificationsEnabled,
        notifyThreshold: notifyThreshold,
      );
}

class AppUser {
  AppUser({required this.id, required this.email, required this.profile});

  final int id;
  final String email;
  final UserProfile profile;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: (json['id'] as num).toInt(),
        email: json['email'] as String,
        profile: UserProfile.fromJson(
          (json['profile'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
      );
}
