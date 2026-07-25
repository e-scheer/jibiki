/// Collection album + booster opening surfaces, phone and tablet: the album
/// grid renders with real store data, the card detail opens as a sheet on
/// phones and a dialog on tablets, and the opening sequence reaches its
/// summary through the tap path and its reveal through the slash gesture.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/core/db/user_db.dart';
import 'package:jibiki/core/session_store.dart';
import 'package:jibiki/infrastructure/user_db_handle.dart';
import 'package:jibiki/l10n/app_localizations.dart';
import 'package:jibiki/services/collection_catalog_loader.dart';
import 'package:jibiki/theme/app_theme.dart';
import 'package:jibiki/theme/theme_controller.dart';
import 'package:jibiki/viewmodels/rewards_viewmodel.dart';
import 'package:jibiki/views/rewards/booster_opening_view.dart';
import 'package:jibiki/views/rewards/collection_card_art.dart';
import 'package:jibiki/views/rewards/collection_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CatalogBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key == CollectionCatalogLoader.assetPath) {
      return ByteData.sublistView(
        utf8.encode(
            File('assets/data/collection_sets.json').readAsStringSync()),
      );
    }
    throw StateError('missing asset $key');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late UserDbHandle user;
  late RewardsViewModel rewards;
  late ThemeController theme;
  String? earnedGrantId;

  setUpAll(() async {
    tmp = await Directory.systemTemp.createTemp('jibiki-rewards-ui');
    SharedPreferences.setMockInitialValues({});
    final session = SessionStore(await SharedPreferences.getInstance());
    theme = ThemeController(session);
    user = UserDbHandle(() => UserDb.open('${tmp.path}/user.db'));

    // 3 qualified days -> milestone 3 -> one unopened booster on the shelf.
    final today = DateTime.now();
    for (var i = 0; i < 3; i++) {
      final day = today.subtract(Duration(days: i));
      await user.execute(
        'INSERT INTO review_log (client_review_id, item_type, item_ref, rating, '
        'state_before, duration_ms, reviewed_at, synced) VALUES (?, ?, ?, ?, 0, 0, ?, 0)',
        [
          'seed-$i',
          'kana',
          'あ',
          3,
          DateTime(day.year, day.month, day.day, 12)
              .toUtc()
              .millisecondsSinceEpoch,
        ],
      );
    }

    rewards = RewardsViewModel(
      userDb: user,
      loader: CollectionCatalogLoader(_CatalogBundle()),
      theme: theme,
      session: session,
    );
    await rewards.init();
    await rewards.onStudyActivity();
    earnedGrantId = rewards.unopened.single.id;
  });

  tearDownAll(() async {
    await user.close();
    await tmp.delete(recursive: true);
  });

  Widget app(Widget home) => MultiProvider(
        providers: [
          ChangeNotifierProvider<RewardsViewModel>.value(value: rewards),
          ChangeNotifierProvider<ThemeController>.value(value: theme),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      );

  void resize(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  testWidgets('phone album: grid, progress and sheet detail', (tester) async {
    resize(tester, const Size(390, 844));
    await tester.pumpWidget(app(const CollectionView()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Collection'), findsOneWidget);
    expect(find.text('0 / 20 cards'), findsOneWidget);
    expect(find.byType(CollectionCardFace), findsWidgets);

    // Card detail opens as a draggable sheet on phones.
    await tester.tap(find.byType(CollectionCardFace).first);
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Not obtained yet'), findsWidgets);
  });

  testWidgets('tablet album: dialog detail, no overflow', (tester) async {
    resize(tester, const Size(1280, 900));
    await tester.pumpWidget(app(const CollectionView()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(CollectionCardFace).first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
  });

  testWidgets('opening: tap to tear, reveal 4 cards, reach the summary',
      (tester) async {
    resize(tester, const Size(390, 844));
    await tester.pumpWidget(app(BoosterOpeningView(grantId: earnedGrantId!)));
    // The draw is a chain of real async round-trips to the user.db isolate;
    // each hop needs real event-loop time (runAsync) followed by a microtask
    // flush (pump) before the fake-async animation clock can be driven.
    Future<void> settleAsyncWork() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    await settleAsyncWork();

    // Tap-to-open path (the accessible alternative to the tear gesture).
    await tester.tapAt(const Offset(195, 400));
    await tester.pump(const Duration(milliseconds: 500));

    // Each of the 4 cards now takes two taps (flip face-up, then advance), so
    // ~8 taps reach the summary; a few extra taps on the summary are harmless.
    for (var i = 0; i < 12; i++) {
      await tester.tapAt(const Offset(195, 400));
      await tester.pump(const Duration(milliseconds: 400));
      await settleAsyncWork();
      if (find.text('Booster opened').evaluate().isNotEmpty) break;
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Booster opened'), findsOneWidget);
    expect(rewards.unopened, isEmpty);
    expect(rewards.collection.values.fold<int>(0, (n, e) => n + e.count), 4);
  });

  // The slash gesture on both form factors: one continuous stroke across the
  // pack, Fruit Ninja style. Opening is replay-safe, so revisiting the opened
  // grant replays the same ceremony with the stored draw.
  for (final (label, size) in const [
    ('phone', Size(390, 844)),
    ('tablet', Size(1280, 900)),
  ]) {
    testWidgets('opening ($label): a fast slash cuts the pack to the reveal',
        (tester) async {
      resize(tester, size);
      await tester.pumpWidget(app(BoosterOpeningView(grantId: earnedGrantId!)));
      Future<void> settleAsyncWork() async {
        for (var i = 0; i < 12; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)));
          await tester.pump();
        }
      }

      await settleAsyncWork();

      // The stroke sweeps the middle of the screen, entering the pack on its
      // left edge and exiting on its right. The moves are dispatched back to
      // back, so the stroke reads as fast to the slash detector.
      final y = size.height / 2;
      final step = Offset(size.width * .08, 2);
      final gesture =
          await tester.startGesture(Offset(size.width * .1, y));
      for (var i = 0; i < 10; i++) {
        await gesture.moveBy(step);
      }
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 600));
      await settleAsyncWork();

      // The wrapper is cut: the ceremony moved on to the card reveal.
      expect(find.text('Tap to reveal'), findsOneWidget);
    });
  }

  testWidgets('opening: a slow deliberate glide across the pack also cuts',
      (tester) async {
    resize(tester, const Size(390, 844));
    await tester.pumpWidget(app(BoosterOpeningView(grantId: earnedGrantId!)));
    Future<void> settleAsyncWork() async {
      for (var i = 0; i < 12; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
    }

    await settleAsyncWork();

    // The slash detector clocks strokes on wall time, so real delays between
    // the moves make this a genuinely slow glide (roughly 300 px/s, well
    // under the fast-flick threshold). It must still cut on reaching the far
    // edge of the pack: the calm ritual never requires speed.
    final gesture = await tester.startGesture(const Offset(39, 422));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(31.2, 2));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 900));
    await settleAsyncWork();

    expect(find.text('Tap to reveal'), findsOneWidget);
  });
}
