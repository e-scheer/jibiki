import 'dart:async';

import 'package:flutter/material.dart';
import 'package:jibiki/l10n/l10n.dart';

import '../../core/breakpoints.dart';
import '../../core/telemetry.dart';
import '../../theme/app_theme.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/pressable.dart';
import '../widgets/stroke_order_view.dart';
import 'study_chrome.dart';

class WritingPracticeView extends StatefulWidget {
  const WritingPracticeView({
    super.key,
    required this.character,
    required this.meaning,
    required this.reading,
    required this.strokePaths,
    required this.strokeViewBox,
    this.telemetry,
  });

  final String character;
  final String meaning;
  final String reading;
  final List<String> strokePaths;
  final String strokeViewBox;
  final TelemetrySink? telemetry;

  @override
  State<WritingPracticeView> createState() => _WritingPracticeViewState();
}

class _WritingPracticeViewState extends State<WritingPracticeView> {
  final _controller = DrawingController();
  bool _showGuide = true;
  bool _completedLogged = false;

  TelemetrySink get _telemetry => widget.telemetry ?? Telemetry.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_telemetry.logEvent(
      TelemetryEvent.writingPracticeStarted,
      parameters: const {
        'item_type': 'kanji',
        'kind': 'free',
        'source': 'kanji_detail',
      },
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reveal() {
    Haptics.light();
    if (!_completedLogged) {
      _completedLogged = true;
      unawaited(_telemetry.logEvent(
        TelemetryEvent.writingPracticeCompleted,
        parameters: const {
          'item_type': 'kanji',
          'kind': 'free',
          'source': 'kanji_detail',
        },
      ));
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.jc.lavender,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: ctx.jc.ink,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ctx.trText('Stroke order'),
                      style: ctx.text.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  StudySticker(widget.character, color: ctx.jc.acid),
                ],
              ),
              const SizedBox(height: 16),
              StudyPanel(
                shadow: 6,
                padding: const EdgeInsets.all(12),
                child: StrokeOrderView(
                  paths: widget.strokePaths,
                  viewBox: widget.strokeViewBox,
                  size: 220,
                ),
              ),
              if (widget.reading.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  widget.reading,
                  style: TextStyle(
                    color: ctx.jc.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              StudyActionButton(
                label: ctx.trText('Got it'),
                color: ctx.jc.lime,
                icon: Icons.check_rounded,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.jc.lavender,
        body: SafeArea(
          child: BoundedContent(
            maxWidth: context.isExpanded ? 920 : Breakpoints.maxContent,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.isExpanded ? 28 : 18,
                14,
                context.isExpanded ? 28 : 18,
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.trText('Writing'),
                              style: context.text.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            ),
                            Text(
                              context
                                  .trText('Recall it, then check the strokes.'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox.square(
                        dimension: 44,
                        child: Pressable(
                          label: context.trText('Close'),
                          onTap: () => Navigator.pop(context),
                          child: const StudyPanel(
                            shadow: 4,
                            radius: 10,
                            padding: EdgeInsets.zero,
                            child: Icon(Icons.close_rounded),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  StudyPanel(
                    color: context.jc.acid,
                    shadow: 4,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.trText('Write the character for'),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.meaning,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              if (widget.reading.isNotEmpty)
                                Text(
                                  widget.reading,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!_showGuide)
                          Text(
                            widget.character,
                            style: TextStyle(
                              fontFamily:
                                  JpFonts.variant(widget.character.hashCode),
                              fontSize: 48,
                              color: context.jc.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: StudyPanel(
                          shadow: 8,
                          radius: 16,
                          padding: EdgeInsets.zero,
                          child: DrawingCanvas(
                            controller: _controller,
                            guidePaths: widget.strokePaths,
                            guideViewBox: widget.strokeViewBox,
                            showGuide: _showGuide,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _Tool(
                          icon: Icons.undo_rounded,
                          label: context.trText('Undo'),
                          onTap: _controller.undo,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Tool(
                          icon: Icons.layers_clear_outlined,
                          label: context.trText('Clear'),
                          onTap: _controller.clear,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _Tool(
                          icon: _showGuide
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_outlined,
                          label: context.trText('Guide'),
                          selected: _showGuide,
                          onTap: () => setState(() => _showGuide = !_showGuide),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  StudyActionButton(
                    label: context.trText('Reveal stroke order'),
                    icon: Icons.gesture_rounded,
                    color: context.jc.ink,
                    foreground: context.jc.acid,
                    onTap: _reveal,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 48,
        child: Pressable(
          label: label,
          selected: selected,
          onTap: () {
            Haptics.tick();
            onTap();
          },
          child: StudyPanel(
            color: selected ? context.jc.acid : context.jc.surface,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
