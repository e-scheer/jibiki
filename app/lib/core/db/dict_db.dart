/// The on-device dictionary database - a read-only SQLite connection over the
/// installed content packs.
///
/// The conditional export keeps web builds compiling: `dart:ffi` (sqlite3)
/// only exists on native targets, and the web app keeps reading the HTTP API,
/// so the stub is never constructed there.
library;

export 'dict_db_stub.dart' if (dart.library.io) 'dict_db_native.dart';
