/// Rewards sync (docs/REWARDS.md): grants and openings enqueue ops that the
/// engine replays to the account, and the server's rewards state merges back
/// monotonically (MAX counts, opened never demoted).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/api_client.dart';
import 'package:jibiki/core/db/user_db.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/infrastructure/local/local_rewards_store.dart';
import 'package:jibiki/infrastructure/user_db_handle.dart';
import 'package:jibiki/models/collection.dart';
import 'package:jibiki/services/sync_service.dart';
import 'package:jibiki/sync/sync_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeSyncService extends SyncService {
  _FakeSyncService(super.api);

  final List<Map<String, dynamic>> requests = [];
  Map<String, dynamic> Function(Map<String, dynamic> request)? handler;

  @override
  Future<Map<String, dynamic>> sync({
    String? lastSyncedAt,
    String mode = 'sync',
    List<Map<String, dynamic>> reviews = const [],
    List<Map<String, dynamic>> ops = const [],
  }) async {
    final request = {
      'last_synced_at': lastSyncedAt,
      'mode': mode,
      'reviews': reviews,
      'ops': ops,
    };
    requests.add(request);
    final base = {
      'synced_at': DateTime.now().toUtc().toIso8601String(),
      'applied_review_ids': [
        for (final r in reviews) r['client_review_id'],
      ],
      'rejected': const [],
      'applied_op_ids': [for (final o in ops) o['client_op_id']],
      'rejected_ops': const [],
      'cards': const [],
      'deleted': const [],
      'profile': null,
    };
    final extra = handler?.call(request);
    return extra == null ? base : {...base, ...extra};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late UserDbHandle user;
  late LocalRewardsStore store;
  late _FakeSyncService remote;
  late SyncEngine engine;
  late CollectionCatalog catalog;
  final now = DateTime(2026, 7, 15, 15);

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('jibiki-rewards-sync');
    catalog = CollectionCatalog.fromJson(
      (jsonDecode(File('assets/data/collection_sets.json').readAsStringSync())
              as Map)
          .cast<String, dynamic>(),
    );
    SharedPreferences.setMockInitialValues({});
    final api = ApiClient(SessionStore(await SharedPreferences.getInstance()));
    remote = _FakeSyncService(api);
  });

  setUp(() async {
    user = UserDbHandle(() => UserDb.open(
        '${tmp.path}/user-${DateTime.now().microsecondsSinceEpoch}.db'));
    store = LocalRewardsStore(user, catalog, clock: () => now);
    engine = SyncEngine(user, remote, canSync: () => true);
    await engine.init();
    engine.setOnline(true);
    await engine.accountChanged(1);
    remote.requests.clear();
    remote.handler = null;
  });

  tearDown(() async {
    engine.dispose();
    await user.close();
  });

  tearDownAll(() => tmp.delete(recursive: true));

  var seq = 0;
  Future<void> reviewOn(DateTime day) => user.execute(
        'INSERT INTO review_log (client_review_id, item_type, item_ref, rating, '
        'state_before, duration_ms, reviewed_at, synced) VALUES (?, ?, ?, ?, 0, 0, ?, 1)',
        [
          'r-${seq++}',
          'kana',
          'あ',
          3,
          DateTime(day.year, day.month, day.day, 12)
              .toUtc()
              .millisecondsSinceEpoch,
        ],
      );

  test('grants and openings replay to the account as ops', () async {
    for (var i = 0; i < 3; i++) {
      await reviewOn(now.subtract(Duration(days: i)));
    }
    final grant = (await store.evaluateMilestones()).single;
    final opening = await store.open(grant.id);

    await engine.syncNow();
    final ops = [
      for (final request in remote.requests)
        ...request['ops'] as List<Map<String, dynamic>>,
    ];
    final grantOp = ops.singleWhere((op) => op['kind'] == 'booster_grant');
    expect(grantOp['payload']['grant_id'], grant.id);
    expect(grantOp['payload']['milestone'], 3);
    expect(grantOp['payload']['status'], 'unopened');
    final openOp = ops.singleWhere((op) => op['kind'] == 'booster_open');
    expect(openOp['payload']['grant_id'], grant.id);
    expect((openOp['payload']['cards'] as List).length, 4);
    expect(
      [for (final c in openOp['payload']['cards'] as List) c['card_id']],
      [for (final c in opening.cards) c.cardId],
    );

    // Acked ops leave the outbox: nothing re-uploads on the next pass.
    final pending = await user.select('SELECT count(*) AS n FROM op_outbox');
    expect(pending.single['n'], 0);
  });

  test('server rewards state merges in monotonically', () async {
    // Local: one opened booster (4 cards).
    for (var i = 0; i < 3; i++) {
      await reviewOn(now.subtract(Duration(days: i)));
    }
    final grant = (await store.evaluateMilestones()).single;
    final opening = await store.open(grant.id);
    final localFirst = opening.cards.first.cardId;

    // The account also owns a grant from another device, a higher duplicate
    // count on one local card, and says our opened grant is 'unopened'
    // (its open op has not reached the server yet in this scenario).
    remote.handler = (request) => {
          'rewards': {
            'grants': [
              {
                'grant_id': grant.id,
                'source': 'streak_milestone',
                'milestone': 3,
                'status': 'unopened',
                'granted_at': 1,
                'opened_at': null,
                'cards': null,
              },
              {
                'grant_id': 'streak:2026-06-01:7',
                'source': 'streak_milestone',
                'milestone': 7,
                'status': 'unopened',
                'granted_at': 2,
                'opened_at': null,
                'cards': null,
              },
            ],
            'collection': [
              {'card_id': localFirst, 'count': 5, 'first_obtained_at': 1},
              {'card_id': 'set001-011', 'count': 1, 'first_obtained_at': 2},
            ],
          },
        };
    await engine.syncNow();

    final grants = await user.select(
        'SELECT grant_id, status FROM booster_grants ORDER BY grant_id');
    expect(grants, hasLength(2));
    // The other device's grant arrived openable; ours stays opened.
    expect(
      {for (final g in grants) g['grant_id']: g['status']},
      {grant.id: 'opened', 'streak:2026-06-01:7': 'unopened'},
    );

    final counts = {
      for (final row in await user
          .select('SELECT card_id, count FROM collection_cards'))
        row['card_id'] as String: row['count'] as int,
    };
    // MAX merge: the server's 5 wins over the local 1; the pulled card lands.
    expect(counts[localFirst], 5);
    expect(counts['set001-011'], 1);
    // Local-only cards from the opening are kept even though the server did
    // not list them yet.
    for (final drawn in opening.cards) {
      expect(counts[drawn.cardId], greaterThanOrEqualTo(1));
    }
  });
}
