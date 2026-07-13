import 'dart:async';

import 'package:flutter/widgets.dart';

import 'telemetry.dart';

/// Sends one normalized screen view for page-level navigation only.
class TelemetryRouteObserver extends NavigatorObserver {
  TelemetryRouteObserver({Telemetry? telemetry})
      : _telemetry = telemetry ?? Telemetry.instance;

  final Telemetry _telemetry;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _record(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _record(newRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) _record(previousRoute);
  }

  void _record(Route<dynamic> route) {
    if (route is! PageRoute<dynamic>) return;
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    unawaited(_telemetry.screenView(name));
  }
}
