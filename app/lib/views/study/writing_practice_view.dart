import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/stroke_order_view.dart';

/// Write-recall practice (DEEP_SEARCH feature): recall the character from its
/// meaning, trace it with a fading KanjiVG guide, then reveal the stroke-order
/// animation to self-check.
class WritingPracticeView extends StatefulWidget {
  const WritingPracticeView({
    super.key,
    required this.character,
    required this.meaning,
    required this.reading,
    required this.strokePaths,
    required this.strokeViewBox,
  });

  final String character;
  final String meaning;
  final String reading;
  final List<String> strokePaths;
  final String strokeViewBox;

  @override
  State<WritingPracticeView> createState() => _WritingPracticeViewState();
}

class _WritingPracticeViewState extends State<WritingPracticeView> {
  final _controller = DrawingController();
  bool _showGuide = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reveal() {
    Haptics.light();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.trText('Stroke order'), style: ctx.text.titleMedium),
            const SizedBox(height: 8),
            StrokeOrderView(
                paths: widget.strokePaths,
                viewBox: widget.strokeViewBox,
                size: 220),
            if (widget.reading.isNotEmpty)
              Text(widget.reading,
                  style: TextStyle(
                      color: ctx.jc.brand, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.trText('Got it'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Scaffold(
      appBar:
          AppBar(title: Text(context.trText('Write · ${widget.character}'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Prompt: recall from meaning + reading.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: jc.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.trText('Write the character for'),
                              style:
                                  TextStyle(color: jc.muted, fontSize: 12.5)),
                          const SizedBox(height: 4),
                          Text(widget.meaning, style: context.text.titleLarge),
                          if (widget.reading.isNotEmpty)
                            Text(widget.reading,
                                style: TextStyle(
                                    color: jc.brand,
                                    fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    if (!_showGuide)
                      Text(widget.character,
                          style: TextStyle(
                              fontSize: 40,
                              color: jc.hairline,
                              fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: DrawingCanvas(
                      controller: _controller,
                      guidePaths: widget.strokePaths,
                      guideViewBox: widget.strokeViewBox,
                      showGuide: _showGuide,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Tool(
                      icon: Icons.undo, label: 'Undo', onTap: _controller.undo),
                  const SizedBox(width: 8),
                  _Tool(
                      icon: Icons.layers_clear_outlined,
                      label: 'Clear',
                      onTap: _controller.clear),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(context.trText('Guide')),
                    selected: _showGuide,
                    onSelected: (v) => setState(() => _showGuide = v),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _reveal,
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52)),
                icon: const Icon(Icons.gesture),
                label: Text(context.trText('Reveal stroke order')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: context.jc.body),
      label: Text(label),
      onPressed: () {
        Haptics.tick();
        onTap();
      },
    );
  }
}
