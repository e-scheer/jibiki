/// FSRS parity - replays the shared vectors (scripts/gen_fsrs_vectors.py)
/// through the Dart port and asserts bit-compatible scheduling with the
/// server. If this fails after a server scheduler change, update the port in
/// lib/srs/ and bump [fsrsVectorsVersion] together with the regenerated
/// fixture (`make sync-vectors`).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jibiki/srs/fsrs.dart';
import 'package:jibiki/srs/local_scheduler.dart';

void main() {
  final doc = jsonDecode(
          File('test/srs/fixtures/fsrs_vectors.json').readAsStringSync())
      as Map<String, dynamic>;

  test('fixture version matches the port', () {
    expect(doc['version'], fsrsVectorsVersion,
        reason: 'Vectors were regenerated: re-verify the Dart port against '
            'server/srs/fsrs.py, then bump fsrsVectorsVersion.');
  });

  test('every case replays bit-compatibly with the server', () {
    final start = DateTime.parse(doc['start'] as String);
    final cases = doc['cases'] as List;
    expect(cases, isNotEmpty);

    for (final raw in cases) {
      final c = raw as Map<String, dynamic>;
      final params = (c['parameters'] as List?)?.cast<num>().map((p) => p.toDouble()).toList();
      final scheduler = Fsrs(
        parameters: params,
        desiredRetention: (c['desired_retention'] as num).toDouble(),
      );
      final card = SrsCard(itemType: 'kana', itemRef: 'あ', due: start);
      var now = start;

      final steps = c['steps'] as List;
      for (var i = 0; i < steps.length; i++) {
        final step = steps[i] as Map<String, dynamic>;
        now = now.add(Duration(seconds: step['gap_s'] as int));
        final outcome = applyReview(scheduler, card, step['rating'] as int, now);

        final where = 'case ${c['id']} step $i';
        expect(card.state, step['state'], reason: where);
        expect(card.step, step['step'], reason: where);
        expect(card.due.difference(now).inSeconds, step['due_offset_s'], reason: where);
        expect(outcome.scheduledDays, step['scheduled_days'], reason: where);
        expect(card.reps, step['reps'], reason: where);
        expect(card.lapses, step['lapses'], reason: where);
        _expectClose(card.stability!, (step['stability'] as num).toDouble(), '$where stability');
        _expectClose(card.difficulty!, (step['difficulty'] as num).toDouble(), '$where difficulty');
      }
    }
  });
}

/// Relative tolerance 1e-9: transcendental functions (exp/pow) may differ in
/// the last ulp between Dart's libm and CPython's, never more.
void _expectClose(double actual, double expected, String where) {
  final tol = expected.abs() * 1e-9 + 1e-12;
  expect((actual - expected).abs() <= tol, isTrue,
      reason: '$where: $actual != $expected (±$tol)');
}
