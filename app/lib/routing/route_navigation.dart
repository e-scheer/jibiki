import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A deep link has no previous page, but must always offer a way out.
void popOrGo(BuildContext context, {String fallback = '/'}) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    context.go(fallback);
  }
}
