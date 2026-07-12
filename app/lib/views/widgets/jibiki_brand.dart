import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

const _jibikiWordmark = 'jibiki';

/// Fixed identity colours from design exploration 17.
abstract final class JibikiBrandColors {
  static const ink = Color(0xFF17131F);
  static const acid = Color(0xFFF2E51C);
  static const klein = Color(0xFF2B36E3);
  static const magenta = Color(0xFFFF57A8);
  static const lime = Color(0xFF8FE838);
  static const lavender = Color(0xFFC9B8F9);
}

enum JibikiBrandVariant { color, monochrome, negative }

/// The compact 字 symbol from the exploration 17 identity sheet.
///
/// Its coordinates are the same 140 by 140 geometry as the source SVG, so the
/// mark stays recognizable and balanced down to 24 logical pixels.
class JibikiBrandMark extends StatelessWidget {
  const JibikiBrandMark({
    super.key,
    this.size = 60,
    this.variant = JibikiBrandVariant.color,
    this.semanticLabel = 'jibiki',
  });

  final double size;
  final JibikiBrandVariant variant;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mark = RepaintBoundary(
      child: CustomPaint(
        size: Size.square(size),
        painter: _BrandMarkPainter(variant),
      ),
    );
    if (semanticLabel == null) return mark;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: mark),
    );
  }
}

class _BrandMarkPainter extends CustomPainter {
  const _BrandMarkPainter(this.variant);

  final JibikiBrandVariant variant;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 140;
    canvas.save();
    canvas.scale(scale);

    final (ink, face) = switch (variant) {
      JibikiBrandVariant.color => (
          JibikiBrandColors.ink,
          JibikiBrandColors.acid
        ),
      JibikiBrandVariant.monochrome => (JibikiBrandColors.ink, Colors.white),
      JibikiBrandVariant.negative => (Colors.white, JibikiBrandColors.ink),
    };
    final fill = Paint()..color = ink;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(14, 28, 104, 104),
        const Radius.circular(26),
      ),
      fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 20, 104, 104),
        const Radius.circular(26),
      ),
      Paint()..color = face,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 20, 104, 104),
        const Radius.circular(26),
      ),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    final text = TextPainter(
      text: TextSpan(
        text: '字',
        style: TextStyle(
          color: ink,
          fontFamily: 'ZenKakuGothicNew',
          fontWeight: FontWeight.w900,
          fontSize: 70,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, Offset(58 - text.width / 2, 74 - text.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandMarkPainter oldDelegate) =>
      oldDelegate.variant != variant;
}

/// The larger square mark used on the launch screen.
class JibikiBlockMark extends StatelessWidget {
  const JibikiBlockMark({super.key, this.size = 148});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scale = size / 148;
    return Semantics(
      image: true,
      label: 'jibiki',
      child: ExcludeSemantics(
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: JibikiBrandColors.acid,
            borderRadius: BorderRadius.circular(36 * scale),
            border: Border.all(
              color: JibikiBrandColors.ink,
              width: 5 * scale,
            ),
            boxShadow: const [
              BoxShadow(
                color: JibikiBrandColors.ink,
                blurRadius: 0,
                offset: Offset(9, 9),
              ),
            ],
          ),
          child: Text(
            '字',
            style: TextStyle(
              color: JibikiBrandColors.ink,
              fontFamily: 'ZenKakuGothicNew',
              fontWeight: FontWeight.w900,
              fontSize: 96 * scale,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Space Grotesk wordmark with the small rotated acid square signature.
class JibikiWordmark extends StatelessWidget {
  const JibikiWordmark({
    super.key,
    this.fontSize = 46,
    this.variant = JibikiBrandVariant.color,
    this.dotOutline,
    this.semanticLabel = 'jibiki',
  });

  final double fontSize;
  final JibikiBrandVariant variant;
  final Color? dotOutline;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final textColor = switch (variant) {
      JibikiBrandVariant.negative => Colors.white,
      _ => JibikiBrandColors.ink,
    };
    final dotColor = variant == JibikiBrandVariant.monochrome
        ? JibikiBrandColors.ink
        : JibikiBrandColors.acid;
    final resolvedDotOutline = dotOutline ??
        (variant == JibikiBrandVariant.negative
            ? Colors.white
            : JibikiBrandColors.ink);
    final dotSize = fontSize * 0.375;
    final wordmark = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _jibikiWordmark,
          style: TextStyle(
            color: textColor,
            fontFamily: 'SpaceGrotesk',
            fontWeight: FontWeight.w700,
            fontSize: fontSize,
            height: 1,
            letterSpacing: fontSize * -0.03,
          ),
        ),
        SizedBox(width: fontSize * 0.10),
        Padding(
          padding: EdgeInsets.only(bottom: fontSize * 0.05),
          child: Transform.rotate(
            angle: 12 * math.pi / 180,
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: dotColor,
                borderRadius: BorderRadius.circular(fontSize * 0.09),
                border: Border.all(
                  color: resolvedDotOutline,
                  width: math.max(1.25, fontSize * 0.07),
                ),
              ),
            ),
          ),
        ),
      ],
    );
    if (semanticLabel == null) return wordmark;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: wordmark),
    );
  }
}

/// Horizontal symbol and wordmark lockup for rails, headers and About pages.
class JibikiBrandLockup extends StatelessWidget {
  const JibikiBrandLockup({
    super.key,
    this.fontSize = 46,
    this.variant = JibikiBrandVariant.color,
    this.markSize,
    this.spacing,
  });

  final double fontSize;
  final JibikiBrandVariant variant;
  final double? markSize;
  final double? spacing;

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'jibiki',
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              JibikiBrandMark(
                size: markSize ?? fontSize * 1.48,
                variant: variant,
                semanticLabel: null,
              ),
              SizedBox(width: spacing ?? fontSize * 0.39),
              JibikiWordmark(
                fontSize: fontSize,
                variant: variant,
                semanticLabel: null,
              ),
            ],
          ),
        ),
      );
}

/// Three square blocks pursuing each other around a square every 640 ms.
///
/// A 160 ms timer produces the source design's four crisp steps without a
/// wasteful 60 fps ticker. Reduced motion and offstage TickerMode freeze it.
class NeoChaseLoader extends StatefulWidget {
  const NeoChaseLoader({
    super.key,
    this.size = 56,
    this.blockSize = 24,
    this.borderWidth = 2.5,
    this.radius = 6,
    this.shadow = 3,
    this.alternateFirst = false,
    this.semanticLabel = 'Loading',
  });

  const NeoChaseLoader.small({
    super.key,
    this.size = 18,
    this.blockSize = 8,
    this.borderWidth = 1.5,
    this.radius = 2,
    this.shadow = 1.5,
    this.alternateFirst = false,
    this.semanticLabel = 'Loading',
  });

  final double size;
  final double blockSize;
  final double borderWidth;
  final double radius;
  final double shadow;
  final bool alternateFirst;
  final String semanticLabel;

  @override
  State<NeoChaseLoader> createState() => _NeoChaseLoaderState();
}

class _NeoChaseLoaderState extends State<NeoChaseLoader> {
  Timer? _timer;
  int _step = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate = !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 160), (_) {
        if (mounted) setState(() => _step = (_step + 1) % 4);
      });
    } else if (!animate) {
      _timer?.cancel();
      _timer = null;
      _step = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final colors = [
      widget.alternateFirst ? jc.acid : jc.brand,
      jc.magenta,
      jc.lime,
    ];
    final travel = widget.size - widget.blockSize;
    const corners = [
      Offset.zero,
      Offset(1, 0),
      Offset(1, 1),
      Offset(0, 1),
    ];

    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var i = 0; i < colors.length; i++)
                  Positioned(
                    left: corners[(_step + i) % 4].dx * travel,
                    top: corners[(_step + i) % 4].dy * travel,
                    child: Container(
                      width: widget.blockSize,
                      height: widget.blockSize,
                      decoration: BoxDecoration(
                        color: colors[i],
                        borderRadius: BorderRadius.circular(widget.radius),
                        border: Border.all(
                          color: jc.ink,
                          width: widget.borderWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: jc.ink,
                            blurRadius: 0,
                            offset: Offset(widget.shadow, widget.shadow),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
