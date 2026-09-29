# Study reliability audit

Date: 2026-09-06. Scope: native local study, review view model, synchronization and user database upgrades. Tests use temporary databases only.

## Corrected defects

- Ratings advanced the session before persistence, hiding failed writes. Advancement now follows successful storage. Concurrent taps are ignored during saving, failures retain the card, and partially saved Match rounds retry only their remaining cards.
- Review retries now retain a stable UUID, rating and duration. Native review storage deduplicates that UUID and serializes concurrent review calculations. The HTTP API receives the same event identity for server deduplication.
- Re-adding a card, bulk enrollment and deck enrollment reset learning history. These operations now preserve existing schedules, reps, lapses and source context. Bulk creation counts reflect newly created cards.
- Prior knowledge used arbitrary 30-day schedules and fabricated reps. It now uses the same initial Easy FSRS transition as the server and creates no synthetic review. Repeating a known or learning action preserves progress.
- Card and non-review outbox changes were separate commits. They now commit or roll back together. A failing-outbox test proves that no orphan local change remains.
- Invalid cached FSRS parameters could prevent every review. Malformed parameter arrays and invalid retention now fall back to defaults.
- Sync protected pending reviews but overwrote pending favorites, statuses, bulk additions and profile changes. Transaction-time guards now protect both upserts and deletions while relevant operations remain pending.
- Responses could apply after logout or an account switch. They are now discarded for the old account, leaving durable pending work untouched.
- Cloud replacement retries could repeat destructive replacement or forget the replacement intent after restart. A durable replacement UUID is retained until the response and acknowledgments commit locally. The server uses that identity to avoid repeating the replacement.
- Database migration steps could partially commit and prevent reopening. All upgrade steps now share one transaction, and failed opens release their worker and connection. A legacy-schema fault test proves rollback and successful retry.
- Review duration uses a monotonic stopwatch. Calendar-day streak iteration no longer subtracts fixed 24-hour periods across daylight-saving transitions.
- Local daily statistics, streaks and dashboard forecasts now use the account's IANA timezone through the bundled timezone database. Missing or invalid zones fall back to UTC, consistently with the server. Day boundaries use calendar dates rather than fixed 24-hour offsets.

## Validation

40 targeted Flutter tests passed across `review_viewmodel_test.dart`, `local_study_test.dart`, `user_db_migration_test.dart`, `fsrs_parity_test.dart`, and `rewards_sync_test.dart`. They cover failure/retry, concurrency, local/server FSRS parity, in-flight mutations, account logout, replacement restart and migration rollback. The review screens separately integrate pending and retry states.

## Remaining scope and limits

- Timezone regressions cover Tokyo and Los Angeles date boundaries and the 23-hour and 25-hour days in Brussels. These establish the selected account-calendar policy; keeping the bundled timezone database current remains a maintenance responsibility.
- Sync is eventually consistent: new mutations made during a small upload can remain pending until its next scheduled run. They remain durable and protected from that upload's response.
- Tests establish the documented scenarios, not an exhaustive proof of every possible interleaving or historical user-database state. No personal database was modified and no historical review or source-content repair was performed.
