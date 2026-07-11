/// Content-pack metadata: the server's `jibiki-packs/2` manifest, the bundled
/// base pack's single-entry manifest, and the on-device registry of installed
/// packs. Pure Dart - no IO - so it compiles (and unit-tests) everywhere.
library;

class PackDependency {
  const PackDependency({required this.id, required this.version});

  final String id;
  final String version;

  factory PackDependency.fromJson(Map<String, dynamic> json) => PackDependency(
        id: json['id'] as String,
        version: json['version'] as String? ?? '',
      );
}

/// One downloadable (or bundled) pack, as described by a manifest entry.
class PackInfo {
  const PackInfo({
    required this.id,
    required this.version,
    required this.schemaVersion,
    required this.datasetRev,
    required this.file,
    required this.bytes,
    required this.installedBytes,
    required this.sha256,
    required this.sha256Db,
    this.counts = const {},
    this.languages = const [],
    this.requires = const [],
    this.minAppVersion = '',
    this.title = const {},
    this.attribution = const {},
  });

  final String id;
  final String version;
  final int schemaVersion;
  final int datasetRev;
  final String file;

  /// Compressed transfer size / raw installed size, in bytes.
  final int bytes;
  final int installedBytes;

  /// sha256 of the .gz as downloaded / of the inflated .db.
  final String sha256;
  final String sha256Db;

  final Map<String, int> counts;
  final List<String> languages;
  final List<PackDependency> requires;
  final String minAppVersion;
  final Map<String, String> title;
  final Map<String, String> attribution;

  factory PackInfo.fromJson(Map<String, dynamic> json) => PackInfo(
        id: json['id'] as String,
        version: json['version'] as String,
        schemaVersion: json['schema_version'] as int? ?? 1,
        datasetRev: json['dataset_rev'] as int? ?? 1,
        file: json['file'] as String,
        bytes: json['bytes'] as int? ?? 0,
        installedBytes: json['installed_bytes'] as int? ?? 0,
        sha256: json['sha256'] as String,
        sha256Db: json['sha256_db'] as String,
        counts: (json['counts'] as Map?)?.cast<String, int>() ?? const {},
        languages: (json['languages'] as List?)?.cast<String>() ?? const [],
        requires: [
          for (final dep in (json['requires'] as List?) ?? const [])
            PackDependency.fromJson((dep as Map).cast<String, dynamic>()),
        ],
        minAppVersion: json['min_app_version'] as String? ?? '',
        title: (json['title'] as Map?)?.cast<String, String>() ?? const {},
        attribution: (json['attribution'] as Map?)?.cast<String, String>() ?? const {},
      );
}

/// The server manifest listing every downloadable pack.
class PacksManifest {
  const PacksManifest({required this.schema, required this.packs});

  final String schema;
  final List<PackInfo> packs;

  PackInfo? byId(String id) {
    for (final p in packs) {
      if (p.id == id) return p;
    }
    return null;
  }

  factory PacksManifest.fromJson(Map<String, dynamic> json) => PacksManifest(
        schema: json['schema'] as String? ?? '',
        packs: [
          for (final p in (json['packs'] as List?) ?? const [])
            PackInfo.fromJson((p as Map).cast<String, dynamic>()),
        ],
      );
}

/// One installed pack, as remembered by the on-device registry.
class InstalledPack {
  const InstalledPack({
    required this.id,
    required this.version,
    required this.schemaVersion,
    required this.datasetRev,
    required this.installedBytes,
    required this.fileName,
  });

  final String id;
  final String version;
  final int schemaVersion;
  final int datasetRev;
  final int installedBytes;

  /// File name inside the packs directory (e.g. `dict-core.db`) - version-less
  /// so updates atomically replace the same path.
  final String fileName;

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'schema_version': schemaVersion,
        'dataset_rev': datasetRev,
        'installed_bytes': installedBytes,
        'file_name': fileName,
      };

  factory InstalledPack.fromJson(Map<String, dynamic> json) => InstalledPack(
        id: json['id'] as String,
        version: json['version'] as String,
        schemaVersion: json['schema_version'] as int? ?? 1,
        datasetRev: json['dataset_rev'] as int? ?? 1,
        installedBytes: json['installed_bytes'] as int? ?? 0,
        fileName: json['file_name'] as String,
      );
}

/// The registry persisted as `packs/registry.json`.
class PackRegistry {
  PackRegistry();

  final Map<String, InstalledPack> installed = {};
  DateTime? lastUpdateCheck;

  factory PackRegistry.fromJson(Map<String, dynamic> json) {
    final registry = PackRegistry();
    for (final p in (json['installed'] as List?) ?? const []) {
      final pack = InstalledPack.fromJson((p as Map).cast<String, dynamic>());
      registry.installed[pack.id] = pack;
    }
    final check = json['last_update_check'] as String?;
    registry.lastUpdateCheck = check == null ? null : DateTime.tryParse(check);
    return registry;
  }

  Map<String, dynamic> toJson() => {
        'installed': [for (final p in installed.values) p.toJson()],
        if (lastUpdateCheck != null)
          'last_update_check': lastUpdateCheck!.toUtc().toIso8601String(),
      };
}
