/// Offline-first study against the real base pack: queue semantics (session
/// batch + "Study more", never a daily wall), review scheduling + outbox,
/// set-status transitions, decks, and the sync engine's replay/apply loop -
/// the client mirror of server/tests/test_srs.py and test_sync.py.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart' show ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/db/user_db.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/data/local/local_dictionary_data_source.dart';
import 'package:jibiki/data/local/local_study_store.dart';
import 'package:jibiki/data/packs/pack_manager.dart';
import 'package:jibiki/data/user_db_handle.dart';
import 'package:jibiki/models/enums.dart';
import 'package:jibiki/services/sync_service.dart';
import 'package:jibiki/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSyncService extends SyncService {
  _FakeSyncService(super.api);

  final List<Map<String, dynamic>> requests = [];
  Future<Map<String, dynamic>> Function(Map<String, dynamic> request)? handler;

  @override
  Future<Map<String, dynamic>> sync({
    String? lastSyncedAt,
    List<Map<String, dynamic>> reviews = const [],
    List<Map<String, dynamic>> ops = const [],
  }) async {
    final request = {
      'last_synced_at': lastSyncedAt,
      'reviews': reviews,
      'ops': ops,
    };
    requests.add(request);
    return await handler?.call(request) ?? _ackAll(request);
  }

  static Map<String, dynamic> _ackAll(Map<String, dynamic> request) => {
        'synced_at': DateTime.now().toUtc().toIso8601String(),
        'applied_review_ids': [
          for (final r in request['reviews'] as List) (r as Map)['client_review_id'],
        ],
        'rejected': const [],
        'applied_op_ids': [
          for (final o in request['ops'] as List) (o as Map)['client_op_id'],
        ],
        'rejected_ops': const [],
        'cards': const [],
        'deleted': const [],
        'profile': null,
      };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late PackManager packs;
  late LocalDictionaryDataSource dict;
  late UserDbHandle user;
  late LocalStudyStore store;
  late _FakeSyncService remote;
  late SyncEngine engine;
  var syncPokes = 0;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('jibiki-local-study');
    final gz = File('assets/packs/base.db.gz').readAsBytesSync();
    final manifest = File('assets/packs/base_manifest.json').readAsStringSync();
    packs = PackManager(
      root: () async => Directory('${tmp.path}/packs'),
      dio: Dio(),
      loadAsset: (key) async => switch (key) {
        'assets/packs/base.db.gz' => ByteData.sublistView(gz),
        'assets/packs/base_manifest.json' =>
          ByteData.sublistView(utf8.encode(manifest)),
        _ => throw StateError('missing asset $key'),
      },
    );
    await packs.ensureReady();
    dict = LocalDictionaryDataSource(packs);

    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(SessionStore(await SharedPreferences.getInstance()));
    remote = _FakeSyncService(api);
  });

  setUp(() async {
    user = UserDbHandle(
        () => UserDb.open('${tmp.path}/user-${DateTime.now().microsecondsSinceEpoch}.db'));
    store = LocalStudyStore(user, packs, dict, onLocalMutation: () => syncPokes++);
    engine = SyncEngine(user, remote, canSync: () => true);
    await engine.init();
    remote.requests.clear();
    remote.handler = null;
    syncPokes = 0;
  });

  tearDownAll(() => tmp.delete(recursive: true));

  test('add → new queue; review advances and fills the outbox', () async {
    final wordId = (await dict.search('食べる')).words.first.id;
    await store.addCard(ItemType.word, '$wordId');
    await store.addCard(ItemType.kana, 'あ');

    var queue = await store.queue();
    expect(queue.newCards.length, 2);
    expect(queue.due, isEmpty);
    // Items are joined from the packs at read time.
    expect(queue.newCards.first.front, isNotEmpty);

    final card = queue.newCards.first;
    final after = await store.review(card.id, Rating.good, durationMs: 1200);
    expect(after.state, 1); // first learning step
    expect(after.reps, 1);

    queue = await store.queue();
    expect(queue.newCards.length, 1);

    expect(engine.pendingCount, 0); // not refreshed yet
    await engine.syncNow();
    final sent = remote.requests.single;
    expect((sent['reviews'] as List).length, 1);
    final review = (sent['reviews'] as List).single as Map;
    expect(review['rating'], 3);
    expect(review['duration_ms'], 1200);
    // add ops (2 bulk_add) went along.
    expect((sent['ops'] as List).length, 2);
    expect(engine.pendingCount, 0);
    expect(syncPokes, greaterThan(0));
  });

  test('new-card order puts prerequisites first (kanji before its word)', () async {
    // 食べる (word) contains the kanji 食. Add the WORD first so the raw
    // created_at order is word-then-kanji; the prerequisite sort must still
    // surface the kanji ahead of the word it builds.
    final wordId = (await dict.search('食べる')).words.first.id;
    await store.addCard(ItemType.word, '$wordId');
    await store.addCard(ItemType.kanji, '食');

    final q = await store.queue(newLimit: 100);
    final order = [for (final c in q.newCards) '${c.itemType.wire}:${c.itemRef}'];
    final iKanji = order.indexOf('kanji:食');
    final iWord = order.indexOf('word:$wordId');
    expect(iKanji, greaterThanOrEqualTo(0));
    expect(iWord, greaterThanOrEqualTo(0));
    expect(iKanji, lessThan(iWord), reason: 'kanji 食 must lead its word 食べる');
  });

  test('new cards are a per-session batch, "Study more" pulls the rest', () async {
    await store.enrollDeck('hiragana');
    final deck = (await store.decks()).firstWhere((d) => d.id == 'hiragana');
    expect(deck.total, greaterThan(40));
    expect(deck.enrolled, deck.total);

    final firstBatch = await store.queue();
    expect(firstBatch.newCards.length, 15); // default new_per_session
    expect(firstBatch.newAvailable, deck.total);

    final more = await store.queue(newLimit: 100000 > 500 ? 500 : 100000);
    expect(more.newCards.length, deck.total); // the whole pool, no daily wall

    final deckQueue = await store.deckQueue('hiragana');
    expect(deckQueue.newCards.length, 15);
    expect(deckQueue.counts['new_available'], deck.total);
  });

  test('set_status cycle: learning → known → none, mark-known has no log', () async {
    await store.setStatus(ItemType.kana, 'い', 'learning');
    var states = await store.states(type: ItemType.kana);
    expect(states['い'], 0);

    await store.setStatus(ItemType.kana, 'い', 'known');
    states = await store.states(type: ItemType.kana);
    expect(states['い'], 2); // seeded mature via initial-Easy
    // Asserting prior knowledge is NOT a review: no log, no outbox entry.
    final logs = await user.select('SELECT count(*) AS n FROM review_log');
    expect(logs.single['n'], 0);

    // Toggling Study back on demotes an established card to new (honest).
    await store.setStatus(ItemType.kana, 'い', 'learning');
    states = await store.states(type: ItemType.kana);
    expect(states['い'], 0);

    await store.setStatus(ItemType.kana, 'い', 'none');
    states = await store.states(type: ItemType.kana);
    expect(states.containsKey('い'), isFalse);

    // Re-adding resurrects the locally-deleted row as new.
    await store.setStatus(ItemType.kana, 'い', 'learning');
    states = await store.states(type: ItemType.kana);
    expect(states['い'], 0);
  });

  test('bulk add known seeds a whole set as mature', () async {
    final summary = await store.bulkAdd(
      [for (final c in ['か', 'き', 'く']) (type: ItemType.kana, ref: c)],
      known: true,
    );
    expect(summary['resolved'], 3);
    final stats = await store.stats();
    expect(stats.byState['review'], 3);
    expect(stats.byState['new'], 0);
    // Known cards don't clog the new queue.
    expect((await store.queue()).newCards, isEmpty);
  });

  test('stats: reviews today + streak track local reviews', () async {
    await store.addCard(ItemType.kana, 'さ');
    final card = (await store.queue()).newCards.single;
    await store.review(card.id, Rating.good);
    final stats = await store.stats();
    expect(stats.reviewsToday, 1);
    expect(stats.streak, 1);
    expect(stats.totalCards, 1);
  });

  test('favorites deck filters on the flag', () async {
    await store.addCard(ItemType.kana, 'た');
    final card = (await store.queue()).newCards.single;
    await store.setFavorite(card.id, true);
    final favorites = (await store.decks()).firstWhere((d) => d.id == 'favorites');
    expect(favorites.enrolled, 1);
  });

  test('sync applies authoritative cards, profile and watermark', () async {
    await store.addCard(ItemType.kana, 'な');
    final localCard = (await store.queue()).newCards.single;
    await store.review(localCard.id, Rating.good);

    final due = DateTime.now().toUtc().add(const Duration(days: 3));
    remote.handler = (request) async => {
          ..._FakeSyncService._ackAll(request),
          'cards': [
            {
              'id': 991,
              'item_type': 'kana',
              'item_ref': 'な',
              'state': 2,
              'step': null,
              'stability': 12.5,
              'difficulty': 4.2,
              'due': due.toIso8601String(),
              'last_review': DateTime.now().toUtc().toIso8601String(),
              'reps': 7,
              'lapses': 1,
              'favorite': false,
              'created_at': DateTime.now().toUtc().toIso8601String(),
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          ],
          'profile': {'new_cards_per_day': 3, 'desired_retention': 0.9},
        };
    await engine.syncNow();
    expect(engine.lastError, isNull);
    expect(engine.lastSyncedAt, isNotNull);
    expect(engine.pendingCount, 0);

    // Server state won: the card is now a mature review card with server_id.
    final row = (await user.select('SELECT * FROM cards WHERE item_ref = ?', ['な'])).single;
    expect(row['server_id'], 991);
    expect(row['state'], 2);
    expect(row['reps'], 7);

    // Profile cache drives the scheduler: next queue uses the server batch size.
    await store.enrollDeck('hiragana');
    expect((await store.queue()).newCards.length, 3);
  });

  test('a rejected review is acked and its deleted card dropped', () async {
    await store.addCard(ItemType.kana, 'は');
    final card = (await store.queue()).newCards.single;
    await store.review(card.id, Rating.good);

    remote.handler = (request) async {
      final base = _FakeSyncService._ackAll(request);
      return {
        ...base,
        'applied_review_ids': const [],
        'rejected': [
          for (final id in base['applied_review_ids'] as List)
            {'id': id, 'reason': 'deleted'},
        ],
        'deleted': [
          {'item_type': 'kana', 'ref': 'は'},
        ],
      };
    };
    await engine.syncNow();
    expect(engine.pendingCount, 0); // acked even though rejected
    expect(await user.select('SELECT * FROM cards WHERE item_ref = ?', ['は']), isEmpty);
  });

  test('in-flight reviews are never clobbered by the response', () async {
    await store.addCard(ItemType.kana, 'ま');
    final card = (await store.queue()).newCards.single;
    await store.review(card.id, Rating.good);

    remote.handler = (request) async {
      final base = _FakeSyncService._ackAll(request);
      // While the request was "on the wire", the user rated the card again -
      // there is a fresh unsynced review by the time the response applies.
      if (remote.requests.length == 1) {
        await store.review(card.id, Rating.good);
      }
      return {
        ...base,
        'cards': [
          {
            'id': 5,
            'item_type': 'kana',
            'item_ref': 'ま',
            'state': 0,
            'stability': null,
            'difficulty': null,
            'due': DateTime.now().toUtc().toIso8601String(),
            'reps': 1,
            'lapses': 0,
            'favorite': false,
          },
        ],
      };
    };
    await engine.syncNow();
    // The stale server snapshot (reps 1, state 0) must not overwrite the
    // locally-newer card; the pending second review re-syncs next round.
    final row = (await user.select('SELECT * FROM cards WHERE item_ref = ?', ['ま'])).single;
    expect(row['reps'], 2);
  });
}
