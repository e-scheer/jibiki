import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

import '../models/collection.dart';

/// Loads the bundled card catalog. The catalog is versioned content: sets can
/// grow over time without breaking existing collections (card ids are stable).
class CollectionCatalogLoader {
  const CollectionCatalogLoader(this._bundle);

  final AssetBundle _bundle;

  static const assetPath = 'assets/data/collection_sets.json';

  Future<CollectionCatalog> load() async {
    final raw = await _bundle.loadString(assetPath);
    return CollectionCatalog.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>());
  }
}
