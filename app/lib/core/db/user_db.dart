/// The on-device user-state database (cards, review log/outbox, op outbox,
/// profile cache). Conditional export for the same reason as dict_db.dart:
/// web never studies locally, but its build must compile.
library;

export 'user_db_stub.dart' if (dart.library.io) 'user_db_native.dart';
