import 'package:flutter/widgets.dart';

/// The backbone of jibiki's responsive layout: Material 3 **window size classes**.
/// Every surface - the app shell, the study games, scrollable content - keys its
/// layout off `context.win` / `context.isWide` / `context.isLandscape` instead of
/// guessing device types, so the UI reflows the moment the window (or rotation)
/// changes.
enum WindowSize { compact, medium, expanded }

extension WindowSizeX on WindowSize {
  bool get isCompact => this == WindowSize.compact;

  /// Medium or expanded - i.e. a side rail replaces the bottom bar, content is
  /// bounded, and games can go two-pane.
  bool get isWide => this != WindowSize.compact;
}

class Breakpoints {
  Breakpoints._();

  /// Phone-landscape / small tablet starts here.
  static const double medium = 600;

  /// Tablet landscape and desktop workspaces start here. The navigation rail
  /// remains the same compact 76 px at every wide size.
  static const double expanded = 960;

  /// Reading/content column ceiling on wide screens, so prose and forms don't
  /// stretch into unreadable 1000px+ lines.
  static const double maxContent = 720;

  /// A single study card / game board never grows past this, centred instead.
  static const double maxBoard = 560;

  static WindowSize of(double width) {
    if (width >= expanded) return WindowSize.expanded;
    if (width >= medium) return WindowSize.medium;
    return WindowSize.compact;
  }
}

extension ResponsiveContext on BuildContext {
  WindowSize get win => Breakpoints.of(MediaQuery.sizeOf(this).width);
  bool get isWide => win.isWide;
  bool get isExpanded => win == WindowSize.expanded;
  bool get isLandscape =>
      MediaQuery.orientationOf(this) == Orientation.landscape;
}

/// Caps content to a readable width and centres it on wide screens; a pass-through
/// on phones. Wrap scrollable page bodies (lists, forms, detail) so a tablet shows
/// a centred column, not a full-bleed stretch.
class BoundedContent extends StatelessWidget {
  const BoundedContent(
      {super.key, required this.child, this.maxWidth = Breakpoints.maxContent});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}

/// Bounds a **fixed-height** board (a study game) to [maxWidth] and centres it
/// while still filling the available height, so flex/Expanded children inside keep
/// working. Use for the games' portrait layout so a tablet shows a tidy centred
/// board instead of a stretched one.
class BoundedBoard extends StatelessWidget {
  const BoundedBoard(
      {super.key, required this.child, this.maxWidth = Breakpoints.maxBoard});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Center(
        child: SizedBox(
          width: c.maxWidth < maxWidth ? c.maxWidth : maxWidth,
          height: c.maxHeight.isFinite ? c.maxHeight : null,
          child: child,
        ),
      ),
    );
  }
}
