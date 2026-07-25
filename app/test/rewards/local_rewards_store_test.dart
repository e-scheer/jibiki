/// Burn -> booster -> collection engine (docs/REWARDS.md): qualified-day burn
/// from review_log, idempotent milestone grants with the 3-booster shelf cap,
/// deterministic openings and duplicate counting.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/db/user_db.dart';
import 'package:jibiki/infrastructure/local/local_rewards_store.dart';
import 'package:jibiki/infrastructure/user_db_handle.dart';
import 'package:jibiki/models/collection.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late UserDbHandle user;
  late CollectionCatalog catalog;

  // Fixed local "now": a Wednesday at 15:00.
  final now = DateTime(2026, 7, 15, 15);

  LocalRewardsStore storeAt(DateTime clock) =>
      LocalRewardsStore(user, catalog, clock: () => clock);

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('jibiki-rewards');
    catalog = CollectionCatalog.fromJson(
      (jsonDecode(File('assets/data/collection_sets.json').readAsStringSync())
              as Map)
          .cast<String, dynamic>(),
    );
  });

  setUp(() async {
    user = UserDbHandle(() => UserDb.open(
        '${tmp.path}/user-${DateTime.now().microsecondsSinceEpoch}.db'));
  });

  tearDown(() => user.close());

  tearDownAll(() => tmp.delete(recursive: true));

  var reviewSeq = 0;
  Future<void> reviewOn(DateTime localDay) async {
    // One real review submitted that local day (mid-afternoon).
    final at = DateTime(localDay.year, localDay.month, localDay.day, 14)
        .toUtc()
        .millisecondsSinceEpoch;
    await user.execute(
      'INSERT INTO review_log (client_review_id, item_type, item_ref, rating, '
      'state_before, duration_ms, reviewed_at, synced) VALUES (?, ?, ?, ?, 0, 0, ?, 0)',
      ['test-${reviewSeq++}', 'kana', 'あ', 3, at],
    );
  }

  test('burn counts consecutive qualified days, alive via yesterday',
      () async {
    final store = storeAt(now);
    expect((await store.burnState()).current, 0);

    // 3 consecutive days ending yesterday: alive, today not yet counted.
    for (var i = 1; i <= 3; i++) {
      await reviewOn(now.subtract(Duration(days: i)));
    }
    var burn = await store.burnState();
    expect(burn.current, 3);
    expect(burn.qualifiedToday, isFalse);
    expect(burn.best, 3);
    expect(burn.nextMilestone, 7);

    // Reviewing today extends it.
    await reviewOn(now);
    burn = await store.burnState();
    expect(burn.current, 4);
    expect(burn.qualifiedToday, isTrue);
    expect(burn.recentDays.last, isTrue);
  });

  test('a missed day breaks the run but never the best burn', () async {
    // 5-day run, then a hole, then 2 recent days.
    for (final offset in [8, 7, 6, 5, 4, 1, 0]) {
      await reviewOn(now.subtract(Duration(days: offset)));
    }
    final burn = await storeAt(now).burnState();
    expect(burn.current, 2);
    expect(burn.best, 5);
  });

  test('milestones grant once per run, replay-safe', () async {
    for (var i = 0; i < 3; i++) {
      await reviewOn(now.subtract(Duration(days: i)));
    }
    final store = storeAt(now);
    final first = await store.evaluateMilestones();
    expect(first, hasLength(1));
    expect(first.single.milestone, 3);

    // Re-evaluating (app restart, second session the same day) grants nothing.
    expect(await store.evaluateMilestones(), isEmpty);
    expect(await store.grants(), hasLength(1));
  });

  test('the shelf caps at 3 unopened; later milestones are honored, not lost',
      () async {
    // A 21-day run crosses milestones 3, 7, 14 and 21 at once.
    for (var i = 0; i < 21; i++) {
      await reviewOn(now.subtract(Duration(days: i)));
    }
    final store = storeAt(now);
    final created = await store.evaluateMilestones();
    expect(created, hasLength(3));

    final all = await store.grants();
    expect(all, hasLength(4));
    expect(
      all.where((g) => g.status == BoosterStatus.skippedFull).single.milestone,
      21,
    );
    // The skipped milestone never re-grants.
    expect(await store.evaluateMilestones(), isEmpty);
  });

  test('opening is deterministic, applies the draw once and counts duplicates',
      () async {
    for (var i = 0; i < 3; i++) {
      await reviewOn(now.subtract(Duration(days: i)));
    }
    final store = storeAt(now);
    final grant = (await store.evaluateMilestones()).single;

    final opening = await store.open(grant.id);
    expect(opening.cards, hasLength(4));

    // The guaranteed shiny is revealed last; the three normals are never shiny.
    final rarities = [
      for (final drawn in opening.cards) catalog.cardsById[drawn.cardId]!.rarity,
    ];
    expect(rarities.last, CardRarity.shiny);
    expect(rarities.take(3), isNot(contains(CardRarity.shiny)));

    // Collection matches the draw, duplicates folded into counts.
    final collection = await store.collection();
    final expected = <String, int>{};
    for (final drawn in opening.cards) {
      expected[drawn.cardId] = (expected[drawn.cardId] ?? 0) + 1;
    }
    expect(
      {for (final e in collection.entries) e.key: e.value.count},
      expected,
    );

    // Re-opening returns the stored result and does not double-apply.
    final replay = await store.open(grant.id);
    expect(
      [for (final drawn in replay.cards) drawn.cardId],
      [for (final drawn in opening.cards) drawn.cardId],
    );
    expect(
      {for (final e in (await store.collection()).entries) e.key: e.value.count},
      expected,
    );
    expect(
      (await store.grants(status: BoosterStatus.opened)).single.id,
      grant.id,
    );
  });

  test('dev seed backdates qualified days; dev reset wipes rewards only',
      () async {
    final store = storeAt(now);
    await store.devSeedQualifiedDays(6);
    var burn = await store.burnState();
    expect(burn.current, 6); // alive via yesterday, today not seeded
    expect(burn.qualifiedToday, isFalse);

    final grants = await store.evaluateMilestones();
    expect([for (final g in grants) g.milestone], [3]);
    await store.open(grants.single.id);
    expect(await store.collection(), isNotEmpty);

    // A real (non-seeded) review must survive the reset.
    await reviewOn(now);
    await store.devReset();
    expect(await store.grants(), isEmpty);
    expect(await store.collection(), isEmpty);
    burn = await store.burnState();
    expect(burn.current, 1);
    expect(burn.qualifiedToday, isTrue);
  });

  test('milestone schedule: 3/7/14/21/30 then every 7 days', () {
    expect(milestonesUpTo(2), isEmpty);
    expect(milestonesUpTo(3), [3]);
    expect(milestonesUpTo(30), [3, 7, 14, 21, 30]);
    expect(milestonesUpTo(44), [3, 7, 14, 21, 30, 37, 44]);
    expect(nextMilestoneAfter(0), 3);
    expect(nextMilestoneAfter(3), 7);
    expect(nextMilestoneAfter(30), 37);
    expect(nextMilestoneAfter(37), 44);
  });

  test('catalog: language scoping is explicit and consumables are declared',
      () {
    final set = catalog.activeSet;
    expect(set.cards, hasLength(20));
    for (final card in set.cards) {
      expect(card.name.authoredIn('fr'), isTrue, reason: card.id);
      expect(card.name.authoredIn('en'), isTrue, reason: card.id);
      expect(card.body.authoredIn('fr'), isTrue, reason: card.id);
      expect(card.body.authoredIn('en'), isTrue, reason: card.id);
    }
    final unlocks = [
      for (final card in set.cards)
        if (card.unlock != null) card,
    ];
    expect(unlocks, hasLength(2));
    expect({for (final card in unlocks) card.unlock!.value},
        {'sakura', 'neon'});
    expect(
      unlocks.every((card) => card.rarity == CardRarity.special),
      isTrue,
    );
    // The shiny slot always has a pool to draw from.
    expect(set.byRarity(CardRarity.shiny), isNotEmpty);
  });
}
