class WaniKaniStatus {
  const WaniKaniStatus({
    required this.connected,
    this.username = '',
    this.threshold = 'guru',
    this.lastSyncedAt,
    this.lastImportedAt,
    this.lastError = '',
    this.pending = false,
    this.preview = const {},
  });

  final bool connected;
  final String username;
  final String threshold;
  final DateTime? lastSyncedAt;
  final DateTime? lastImportedAt;
  final String lastError;
  final bool pending;
  final Map<String, dynamic> preview;

  factory WaniKaniStatus.fromJson(Map<String, dynamic> json) => WaniKaniStatus(
        connected: json['connected'] == true,
        username: json['username'] as String? ?? '',
        threshold: json['threshold'] as String? ?? 'guru',
        lastSyncedAt:
            DateTime.tryParse(json['last_synced_at'] as String? ?? ''),
        lastImportedAt:
            DateTime.tryParse(json['last_imported_at'] as String? ?? ''),
        lastError: json['last_error'] as String? ?? '',
        pending: json['pending'] == true,
        preview:
            ((json['preview'] as Map?) ?? const {}).cast<String, dynamic>(),
      );

  int count(String key) => (preview[key] as num?)?.toInt() ?? 0;
}
