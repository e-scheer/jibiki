// Opt-in integration test against freshly generated, real production packs.
// JIBIKI_PACK_SMOKE_DIR must name the build output directory. The installed
// topology is retained in a temporary folder for inspection; no user DB opens.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/infrastructure/local/local_dictionary_data_source.dart';
import 'package:jibiki/infrastructure/packs/pack_manager.dart';
import 'package:jibiki/infrastructure/packs/pack_manifest.dart';

void main() {
  final sourcePath = Platform.environment['JIBIKI_PACK_SMOKE_DIR'];
  test('generated corpus installs and resolves real dictionary data', () async {
    final source = Directory(sourcePath!).absolute;
    final requestedOutput =
        Platform.environment['JIBIKI_PACK_SMOKE_INSTALL_DIR'];
    final output = requestedOutput == null
        ? await Directory.systemTemp.createTemp('jibiki-production-packs-')
        : Directory(requestedOutput).absolute;
    await output.create(recursive: true);
    final dio = Dio(BaseOptions(baseUrl: 'https://packs.local.test'));
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      try {
        final file = File('${source.path}/${options.uri.pathSegments.last}');
        handler.resolve(
            Response(requestOptions: options, data: await file.readAsBytes()));
      } catch (error) {
        handler.reject(DioException(requestOptions: options, error: error));
      }
    }));
    final packs = PackManager(
      root: () async => output,
      dio: dio,
      loadAsset: (key) async => ByteData.sublistView(
          await File('${source.path}/${key.split('/').last}').readAsBytes()),
    );
    addTearDown(packs.close);
    packs.available = PacksManifest.fromJson(jsonDecode(
            await File('${source.path}/packs_manifest.json').readAsString())
        as Map<String, dynamic>);
    await packs.ensureReady();
    expect(packs.lastError, isNull);
    expect(packs.ready, isTrue);
    for (final id in [
      'dict-core',
      'dict-locale-en',
      'dict-locale-fr',
      'names',
      'examples-en'
    ]) {
      await packs.download(id);
      expect(packs.isInstalled(id), isTrue);
    }
    final dictionary = LocalDictionaryDataSource(packs,
        language: () => 'fr', glossLanguage: () => 'fr');
    final results = await dictionary.search('水', lang: 'fr');
    final water = results.words.firstWhere((word) => word.headword == '水');
    final detail = await dictionary.word(water.id);
    expect(
        detail.senses.any((sense) =>
            sense.exactGlossesFor('fr').any((text) => text.contains('eau'))),
        isTrue);
    expect(detail.provenance['jmdict'], isNotNull);
    final names = (await dictionary.search('東京', lang: 'fr')).names;
    expect(names, isNotEmpty);
    expect(names.first.translations, isNotEmpty);
    final exampleLinks = await packs.db
        .select('SELECT word_id FROM ex_en.example_sense_links LIMIT 1');
    expect(exampleLinks, isNotEmpty);
    final illustrated =
        await dictionary.word(exampleLinks.single['word_id'] as int);
    expect(illustrated.examples, isNotEmpty);
    expect(illustrated.examples.first.translation, isNotEmpty);
    final kanaRows = await packs.db.select(
        'SELECT kana FROM kana_word_examples GROUP BY kana ORDER BY COUNT(*) DESC LIMIT 1');
    expect(kanaRows, isNotEmpty);
    final kana = await dictionary.kanaDetail(kanaRows.first['kana'] as String);
    expect(kana.wordExamples, isNotEmpty);
    expect(kana.wordExamples.first.glosses, isNotEmpty);
    final radicals = await dictionary.radicals();
    expect(radicals.any((radical) => (radical['provenance'] as Map).isNotEmpty),
        isTrue);
    final sourceRadicals = await packs.db.select(
        r"SELECT literal, json_extract(metadata, '$.kanjialive.radical.literal') AS radical FROM kanji WHERE json_extract(metadata, '$.kanjialive.radical.literal') IS NOT NULL LIMIT 1");
    expect(sourceRadicals, isNotEmpty);
    final sourceKanji = sourceRadicals.single;
    final byRadical = await dictionary.kanjiList(
        contains: sourceKanji['radical'] as String, limit: 10000);
    expect(byRadical.any((kanji) => kanji.literal == sourceKanji['literal']),
        isTrue);
    final aliases = await packs.db.select(
        'SELECT id,canonical_word_id FROM words WHERE canonical_word_id IS NOT NULL LIMIT 1');
    expect(aliases, isNotEmpty);
    final alias = await dictionary.word(aliases.single['id'] as int);
    expect(alias.id, aliases.single['id']);
    expect(alias.canonicalId, aliases.single['canonical_word_id']);
    expect(alias.senses, isNotEmpty);
    final historical = await packs.db.select(
        r"SELECT id FROM words WHERE json_extract(provenance, '$.source_status') IN ('upstream_not_in_snapshot','legacy_merged_entry') LIMIT 1");
    if (historical.isNotEmpty) {
      final retained = await dictionary.word(historical.single['id'] as int);
      expect(retained.id, historical.single['id']);
    }
    final counts = <String, int>{};
    for (final table in [
      'words',
      'senses',
      'kanji',
      'kana',
      'radicals',
      'kana_word_examples'
    ]) {
      counts[table] =
          (await packs.db.select('SELECT COUNT(*) AS n FROM $table'))
              .single['n'] as int;
    }
    final report = {
      'source': source.path,
      'installed_root': output.path,
      'installed': [for (final pack in packs.installed) pack.toJson()],
      'counts': counts,
      'water_id': water.id,
      'water_french': detail.summaryGloss('fr'),
      'names_checked': names.length,
      'example_word_checked': illustrated.id,
      'example_language': illustrated.examples.first.language,
      'kana_checked': kana.char,
      'kana_word_examples': kana.wordExamples.length,
      'radical_checked': sourceKanji,
      'alias_checked': aliases.single,
      'historical_checked': historical.isEmpty ? null : historical.single,
      'verified_at': DateTime.now().toUtc().toIso8601String(),
    };
    final reportFile = File('${output.path}/smoke-report.json');
    await reportFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(report));
    // The parent task consumes this explicit path, after the handles close.
    // ignore: avoid_print
    print('JIBIKI_PACK_SMOKE_REPORT=${reportFile.path}');
  },
      skip: sourcePath == null
          ? 'Set JIBIKI_PACK_SMOKE_DIR to opt in to real-pack verification.'
          : false,
      timeout: const Timeout(Duration(minutes: 15)));
}
