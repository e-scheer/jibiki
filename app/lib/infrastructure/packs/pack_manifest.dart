const packsManifestSchema = 'jibiki-packs/3';

class PackRequirement {
  const PackRequirement({required this.id, required this.version});

  final String id;
  final String version;

  factory PackRequirement.fromJson(Map<String, dynamic> json) =>
      PackRequirement(
        id: json['id'] as String? ?? '',
        version: json['version'] as String? ?? '',
      );
}

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
    this.contentType = '',
    this.languages = const [],
    this.requires = const [],
    this.title = const {},
  });

  final String id;
  final String contentType;
  final String version;
  final int schemaVersion;
  final int datasetRev;
  final String file;
  final int bytes;
  final int installedBytes;
  final String sha256;
  final String sha256Db;
  final List<String> languages;
  final List<PackRequirement> requires;
  final Map<String, String> title;

  factory PackInfo.fromJson(Map<String, dynamic> json) => PackInfo(
        id: json['id'] as String? ?? '',
        contentType: json['content_type'] as String? ?? '',
        version: json['version'] as String? ?? '',
        schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 0,
        datasetRev: (json['dataset_rev'] as num?)?.toInt() ?? 0,
        file: json['file'] as String? ?? '',
        bytes: (json['bytes'] as num?)?.toInt() ?? 0,
        installedBytes: (json['installed_bytes'] as num?)?.toInt() ?? 0,
        sha256: json['sha256'] as String? ?? '',
        sha256Db: json['sha256_db'] as String? ?? '',
        languages: [
          for (final value in json['languages'] as List? ?? const []) '$value',
        ],
        requires: [
          for (final value in json['requires'] as List? ?? const [])
            PackRequirement.fromJson((value as Map).cast<String, dynamic>()),
        ],
        title: (json['title'] as Map? ?? const {}).map(
          (key, value) => MapEntry('$key', '$value'),
        ),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'content_type': contentType,
        'version': version,
        'schema_version': schemaVersion,
        'dataset_rev': datasetRev,
        'file': file,
        'bytes': bytes,
        'installed_bytes': installedBytes,
        'sha256': sha256,
        'sha256_db': sha256Db,
        'languages': languages,
        'requires': [
          for (final value in requires)
            {'id': value.id, 'version': value.version},
        ],
        'title': title,
      };
}

class PacksManifest {
  const PacksManifest({required this.schema, required this.packs});

  final String schema;
  final List<PackInfo> packs;

  factory PacksManifest.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] as String? ?? '';
    if (schema != packsManifestSchema) {
      throw FormatException('Unsupported pack manifest schema: $schema');
    }
    final rawPacks = json['packs'];
    if (rawPacks is! List) {
      throw const FormatException('Pack manifest has no packs list.');
    }
    final packs = <PackInfo>[];
    final ids = <String>{};
    final files = <String>{};
    for (final value in rawPacks) {
      if (value is! Map) {
        throw const FormatException('Pack entries must be objects.');
      }
      final pack = PackInfo.fromJson(value.cast<String, dynamic>());
      if (pack.id.isEmpty || pack.version.isEmpty || pack.file.isEmpty) {
        throw const FormatException('Pack identity fields cannot be empty.');
      }
      if (pack.file.contains('/') || pack.file.contains(r'\')) {
        throw FormatException('Pack file must be a basename: ${pack.file}');
      }
      if (!ids.add(pack.id) || !files.add(pack.file)) {
        throw FormatException('Duplicate pack entry: ${pack.id}');
      }
      packs.add(pack);
    }
    for (final pack in packs) {
      for (final requirement in pack.requires) {
        if (!ids.contains(requirement.id)) {
          throw FormatException(
            '${pack.id} requires unknown pack ${requirement.id}.',
          );
        }
      }
    }
    return PacksManifest(schema: schema, packs: packs);
  }

  PackInfo? byId(String id) {
    for (final pack in packs) {
      if (pack.id == id) return pack;
    }
    return null;
  }
}
