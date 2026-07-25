import 'dart:convert';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../models/collection.dart';
import '../user_db_handle.dart';

/// Local, offline-first reward engine (docs/REWARDS.md): computes the burn
/// from review_log, honors milestones idempotently, opens boosters with a
/// deterministic draw and maintains the card collection.
///
/// Everything is derived from or stored in user.db, so guests get the full
/// experience and a future server sync can replay the same deterministic ids.
class LocalRewardsStore {
  LocalRewardsStore(
    this._user,
    this._catalog, {
    DateTime Function()? clock,
    void Function()? onLocalMutation,
  })  : _clock = clock ?? DateTime.now,
        _onLocalMutation = onLocalMutation;

  final UserDbHandle _user;
  final CollectionCatalog _catalog;

  /// Pokes the sync engine after a grant or an opening lands in op_outbox,
  /// same contract as LocalStudyStore. Null in tests and on web.
  final void Function()? _onLocalMutation;
  static const _uuid = Uuid();

  /// Local wall-clock: burn days are the user's calendar days, like the
  /// paper habit tracker they replace.
  final DateTime Function() _clock;

  static const maxStoredBoosters = 3;
  static const cardsPerBooster = 4; // 3 normals + 1 guaranteed shiny

  // Fixed odds for the three normal slots (never purchasable, never tuned per
  // user): commons stay the bulk, specials stay a real event.
  static const _commonWeight = 70;
  static const _rareWeight = 22;
  static const _specialWeight = 8;

  /// Distinct local days with at least one submitted review, newest first.
  /// SQL folds timestamps into 15-minute buckets (every real-world UTC offset
  /// is a multiple of 15 min, so local midnight never falls inside a bucket);
  /// Dart then converts each bucket to the device-local date, which handles
  /// DST correctly. SQLite's own 'localtime' modifier is not reliable on
  /// every bundled build (it returns NULL on some Windows runners).
  Future<List<DateTime>> _qualifiedDays() async {
    final rows = await _user.select(
      'SELECT DISTINCT reviewed_at / 900000 AS bucket FROM review_log '
      'ORDER BY bucket DESC',
    );
    final days = <DateTime>{};
    for (final row in rows) {
      final local = DateTime.fromMillisecondsSinceEpoch(
        (row['bucket'] as int) * 900000,
        isUtc: true,
      ).toLocal();
      days.add(DateTime(local.year, local.month, local.day));
    }
    final sorted = days.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  Future<BurnState> burnState() async {
    final days = await _qualifiedDays();
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);

    final daySet = {for (final day in days) day};
    // Alive if the user reviewed today or yesterday: the current day is not
    // over, so "not yet today" is an invitation, not a loss.
    var cursor = daySet.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    var current = 0;
    while (daySet.contains(cursor)) {
      current += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }

    // Best burn ever, walked over the full local history (never pruned).
    var best = 0;
    var run = 0;
    DateTime? previous;
    for (final day in days.reversed) {
      run = (previous != null && day.difference(previous).inDays == 1)
          ? run + 1
          : 1;
      if (run > best) best = run;
      previous = day;
    }

    return BurnState(
      current: current,
      best: best < current ? current : best,
      qualifiedToday: daySet.contains(today),
      recentDays: [
        for (var i = 6; i >= 0; i--)
          daySet.contains(today.subtract(Duration(days: i))),
      ],
      nextMilestone: nextMilestoneAfter(current),
    );
  }

  /// Honors every milestone reached by the current burn exactly once per
  /// streak run. Returns the grants newly created as openable boosters (the
  /// caller celebrates those); milestones honored while the shelf was full
  /// are recorded as skipped and return nothing.
  Future<List<BoosterGrant>> evaluateMilestones() async {
    final burn = await burnState();
    if (burn.current < 3) return const [];

    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final anchor = burn.qualifiedToday
        ? today
        : today.subtract(const Duration(days: 1));
    final runStart = anchor.subtract(Duration(days: burn.current - 1));
    final runKey =
        '${runStart.year.toString().padLeft(4, '0')}-${runStart.month.toString().padLeft(2, '0')}-${runStart.day.toString().padLeft(2, '0')}';

    final created = <BoosterGrant>[];
    for (final milestone in milestonesUpTo(burn.current)) {
      final grantId = 'streak:$runKey:$milestone';
      final existing = await _user.select(
        'SELECT grant_id FROM booster_grants WHERE grant_id = ?',
        [grantId],
      );
      if (existing.isNotEmpty) continue;
      final unopened = await _unopenedCount();
      final status = unopened >= maxStoredBoosters
          ? BoosterStatus.skippedFull
          : BoosterStatus.unopened;
      final grantedAt = now.toUtc().millisecondsSinceEpoch;
      // Grant + its sync op land atomically; the op replays to the account
      // (docs/REWARDS.md) and the deterministic grant_id makes the server
      // side converge across devices.
      await _user.tx([
        (
          'INSERT OR IGNORE INTO booster_grants (grant_id, source, milestone, status, granted_at) '
              'VALUES (?, ?, ?, ?, ?)',
          [grantId, 'streak_milestone', milestone, status.wire, grantedAt],
        ),
        _opStatement('booster_grant', {
          'grant_id': grantId,
          'source': 'streak_milestone',
          'milestone': milestone,
          'status': status.wire,
        }, grantedAt),
      ]);
      _onLocalMutation?.call();
      if (status == BoosterStatus.unopened) {
        created.add(BoosterGrant(
          id: grantId,
          milestone: milestone,
          status: status,
          grantedAt: DateTime.fromMillisecondsSinceEpoch(grantedAt, isUtc: true),
        ));
      }
    }
    return created;
  }

  Future<int> _unopenedCount() async {
    final rows = await _user.select(
      "SELECT count(*) AS n FROM booster_grants WHERE status = 'unopened'",
    );
    return rows.single['n'] as int;
  }

  Future<List<BoosterGrant>> grants({BoosterStatus? status}) async {
    final rows = await _user.select(
      'SELECT grant_id, milestone, status, granted_at, opened_at FROM booster_grants '
      '${status == null ? '' : 'WHERE status = ?'} ORDER BY granted_at',
      [if (status != null) status.wire],
    );
    return [
      for (final row in rows)
        BoosterGrant(
          id: row['grant_id'] as String,
          milestone: row['milestone'] as int,
          status: BoosterStatus.fromWire(row['status'] as String),
          grantedAt: DateTime.fromMillisecondsSinceEpoch(
              row['granted_at'] as int,
              isUtc: true),
          openedAt: row['opened_at'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(row['opened_at'] as int,
                  isUtc: true),
        ),
    ];
  }

  Future<Map<String, CollectionEntry>> collection() async {
    final rows = await _user.select(
      'SELECT card_id, count, first_obtained_at FROM collection_cards',
    );
    return {
      for (final row in rows)
        row['card_id'] as String: CollectionEntry(
          cardId: row['card_id'] as String,
          count: row['count'] as int,
          firstObtainedAt: DateTime.fromMillisecondsSinceEpoch(
              row['first_obtained_at'] as int,
              isUtc: true),
        ),
    };
  }

  /// Opens a booster. Replay-safe: an already-opened grant returns the stored
  /// result instead of drawing again, and the draw itself is seeded by the
  /// grant id, so the same grant always yields the same cards.
  Future<BoosterOpening> open(String grantId) async {
    final rows = await _user.select(
      'SELECT status, cards_json FROM booster_grants WHERE grant_id = ?',
      [grantId],
    );
    if (rows.isEmpty) throw StateError('unknown booster $grantId');
    final status = BoosterStatus.fromWire(rows.single['status'] as String);
    if (status == BoosterStatus.opened) {
      return _openingFromJson(grantId, rows.single['cards_json'] as String);
    }
    if (status != BoosterStatus.unopened) {
      throw StateError('booster $grantId is not openable');
    }

    final drawnIds = _draw(grantId);
    final owned = await collection();
    final counts = <String, int>{
      for (final entry in owned.entries) entry.key: entry.value.count,
    };
    final drawn = <DrawnCard>[];
    for (final cardId in drawnIds) {
      final before = counts[cardId] ?? 0;
      counts[cardId] = before + 1;
      drawn.add(DrawnCard(
        cardId: cardId,
        isNew: before == 0,
        countAfter: before + 1,
      ));
    }

    final nowMs = _clock().toUtc().millisecondsSinceEpoch;
    final cardsJson = jsonEncode([for (final card in drawn) card.toJson()]);
    await _user.tx([
      for (final card in drawn)
        (
          'INSERT INTO collection_cards (card_id, count, first_obtained_at) VALUES (?, 1, ?) '
              'ON CONFLICT(card_id) DO UPDATE SET count = count + 1',
          [card.cardId, nowMs],
        ),
      (
        "UPDATE booster_grants SET status = 'opened', opened_at = ?, cards_json = ? "
            "WHERE grant_id = ? AND status = 'unopened'",
        [nowMs, cardsJson, grantId],
      ),
      _opStatement('booster_open', {
        'grant_id': grantId,
        'cards': [for (final card in drawn) card.toJson()],
      }, nowMs),
    ]);
    _onLocalMutation?.call();
    return BoosterOpening(grantId: grantId, cards: drawn);
  }

  (String, List<Object?>) _opStatement(
          String kind, Map<String, dynamic> payload, int performedAt) =>
      (
        'INSERT INTO op_outbox (client_op_id, kind, payload, performed_at) VALUES (?, ?, ?, ?)',
        [_uuid.v4(), kind, jsonEncode(payload), performedAt],
      );

  BoosterOpening _openingFromJson(String grantId, String cardsJson) =>
      BoosterOpening(
        grantId: grantId,
        cards: [
          for (final item in jsonDecode(cardsJson) as List)
            DrawnCard.fromJson((item as Map).cast<String, dynamic>()),
        ],
      );

  /// 3 normal slots (fixed rarity odds) + 1 guaranteed shiny, all drawn from
  /// the active set. Reveal order: normals first, shiny kept for last.
  List<String> _draw(String grantId) {
    final random = Random(_stableSeed(grantId));
    final set = _catalog.activeSet;
    final commons = set.byRarity(CardRarity.common).toList();
    final rares = set.byRarity(CardRarity.rare).toList();
    final specials = set.byRarity(CardRarity.special).toList();
    final shinies = set.byRarity(CardRarity.shiny).toList();

    List<CollectionCardDef> bucketFor(int roll) {
      if (roll < _commonWeight && commons.isNotEmpty) return commons;
      if (roll < _commonWeight + _rareWeight && rares.isNotEmpty) return rares;
      if (specials.isNotEmpty) return specials;
      return commons.isNotEmpty ? commons : rares;
    }

    final ids = <String>[];
    for (var slot = 0; slot < cardsPerBooster - 1; slot++) {
      final bucket =
          bucketFor(random.nextInt(_commonWeight + _rareWeight + _specialWeight));
      ids.add(bucket[random.nextInt(bucket.length)].id);
    }
    final shinyBucket = shinies.isNotEmpty ? shinies : commons;
    ids.add(shinyBucket[random.nextInt(shinyBucket.length)].id);
    return ids;
  }

  /// Dev tooling (debug builds): backdates [days] qualified study days ending
  /// yesterday, so milestones fire without waiting real days. Seeded rows are
  /// tagged and marked already-synced, so they never upload to an account.
  Future<void> devSeedQualifiedDays(int days) async {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    await _user.tx([
      for (var offset = 1; offset <= days; offset++)
        (
          'INSERT INTO review_log (client_review_id, item_type, item_ref, rating, '
              "state_before, duration_ms, reviewed_at, synced) VALUES (?, 'kana', 'あ', 3, 0, 1500, ?, 1)",
          [
            'seed-burn-${_uuid.v4()}',
            DateTime(today.year, today.month, today.day, 12)
                .subtract(Duration(days: offset))
                .toUtc()
                .millisecondsSinceEpoch,
          ],
        ),
    ]);
  }

  /// Dev tooling (debug builds): removes seeded days and wipes every grant
  /// and the whole collection on this device.
  Future<void> devReset() async {
    await _user.tx([
      (
        "DELETE FROM review_log WHERE client_review_id LIKE 'seed-burn-%'",
        const [],
      ),
      ('DELETE FROM booster_grants', const []),
      ('DELETE FROM collection_cards', const []),
    ]);
  }

  /// FNV-1a over the grant id: stable across runs and platforms, unlike
  /// String.hashCode, which the Dart spec does not pin down.
  static int _stableSeed(String input) {
    var hash = 0x811c9dc5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}
