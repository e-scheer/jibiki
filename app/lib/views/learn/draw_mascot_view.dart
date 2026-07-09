import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../repositories/mnemonic_repository.dart';
import '../../theme/app_theme.dart';
import '../widgets/pressable.dart';
import 'drawing_pad.dart';

/// Turn a character into a picture: draw a mascot over the faint glyph (り →
/// licorne), name what it looks like, and save it as a mnemonic image. A full
/// little studio, six brush engines (pen · calligraphy · marker · pencil ·
/// neon · spray), a curated palette plus custom colours, size + opacity, a real
/// eraser, undo/redo and a show/hide guide. The composited drawing is captured
/// and uploaded.
class DrawMascotView extends StatefulWidget {
  const DrawMascotView({super.key, required this.character, required this.language, this.kind = 'kana'});
  final String character;
  final String language;
  final String kind;

  @override
  State<DrawMascotView> createState() => _DrawMascotViewState();
}

class _DrawMascotViewState extends State<DrawMascotView> {
  final _paint = PaintController();
  final _word = TextEditingController();
  final _boundaryKey = GlobalKey();
  bool _saving = false;
  bool _showGuide = true;
  bool _initialised = false;

  // Vivid palette that reads on both white and near-black canvases.
  static const _palette = <Color>[
    Color(0xFFD4402A), // vermilion (brand)
    Color(0xFFF58529), // orange
    Color(0xFFFFC300), // amber
    Color(0xFF2ECC71), // green
    Color(0xFF17BEBB), // teal
    Color(0xFF0095F6), // blue
    Color(0xFF5B51D8), // indigo
    Color(0xFFDD2A7B), // pink
    Color(0xFF8134AF), // purple
    Color(0xFF8D5524), // brown
    Color(0xFFFFFFFF), // white
  ];

  // Colours the user mixes themselves, appended after the curated palette.

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialised) {
      // Default to the theme ink so the first stroke shows on any background.
      _paint.color = context.jc.ink;
      _initialised = true;
    }
  }

  @override
  void dispose() {
    _paint.dispose();
    _word.dispose();
    super.dispose();
  }

  bool get _canSave => _word.text.trim().isNotEmpty && !_paint.isEmpty && !_saving;

  Future<void> _save() async {
    final repo = context.read<MnemonicRepository>(); // read before the async gaps
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      final created = await repo.create(
        character: widget.character,
        kind: widget.kind,
        language: widget.language,
        story: _word.text.trim(),
        imageBytes: bytes,
      );
      if (!mounted) return;
      final msg = created.status == 'visible' ? 'Saved, thank you!' : 'Submitted for review, thank you!';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the drawing')));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmClear() async {
    if (_paint.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear the drawing?'),
        content: const Text('This removes everything on the canvas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) {
      Haptics.medium();
      _paint.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // A fixed, curated palette (ink + the house colours) keeps every drawing on
    // one coherent visual key.
    final swatches = <Color>[context.jc.ink, ..._palette];
    return Scaffold(
      // The hint field sits at the top, above the keyboard, so we let the keyboard
      // overlay the bottom instead of resizing (and squashing) the canvas.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text('Draw · ${widget.character}'),
        actions: [
          IconButton(
            tooltip: _showGuide ? 'Hide guide' : 'Show guide',
            icon: Icon(_showGuide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
            onPressed: () => setState(() => _showGuide = !_showGuide),
          ),
          // Undo / redo live in the app bar so the toolbar can give the brushes
          // and colours the room they deserve.
          ListenableBuilder(
            listenable: _paint,
            builder: (_, __) => Row(
              children: [
                IconButton(
                  tooltip: 'Undo',
                  icon: const Icon(Icons.undo),
                  onPressed: _paint.canUndo
                      ? () {
                          Haptics.tick();
                          _paint.undo();
                        }
                      : null,
                ),
                IconButton(
                  tooltip: 'Redo',
                  icon: const Icon(Icons.redo),
                  onPressed: _paint.canRedo
                      ? () {
                          Haptics.tick();
                          _paint.redo();
                        }
                      : null,
                ),
              ],
            ),
          ),
          // Save listens to BOTH the drawing and the hint field so it enables the
          // moment there's a stroke + a hint, without a full-page setState.
          ListenableBuilder(
            listenable: Listenable.merge([_paint, _word]),
            builder: (_, __) => TextButton(
              onPressed: _canSave ? _save : null,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: TextField(
                controller: _word,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'It looks like…',
                  hintText: 'e.g. a unicorn / une licorne',
                  prefixIcon: Icon(Icons.lightbulb_outline),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: DrawingPad(
                          controller: _paint,
                          character: widget.character,
                          showGuide: _showGuide,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _Toolbar(
              controller: _paint,
              swatches: swatches,
              onPickColor: (c) {
                Haptics.tick();
                _paint.setColor(c);
              },
              onClear: _confirmClear,
            ),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.swatches,
    required this.onPickColor,
    required this.onClear,
  });

  final PaintController controller;
  final List<Color> swatches;
  final ValueChanged<Color> onPickColor;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: jc.canvas,
            border: Border(top: BorderSide(color: jc.hairline)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1, brushes (the headline of the studio) + eraser.
                  SizedBox(
                    height: 58,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final b in Brush.values) ...[
                            _BrushButton(
                              icon: b.icon,
                              label: b.label,
                              selected: !controller.erasing && controller.brush == b,
                              onTap: () {
                                Haptics.tick();
                                controller.setBrush(b);
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(width: 1, height: 40, color: jc.hairline),
                          const SizedBox(width: 8),
                          _BrushButton(
                            icon: Icons.auto_fix_normal,
                            label: 'Eraser',
                            selected: controller.erasing,
                            onTap: () {
                              Haptics.tick();
                              controller.setErasing(!controller.erasing);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Row 2, the fixed house palette. A soft fade at both ends signals
                  // the strip scrolls - a quiet "there's more" cue.
                  SizedBox(
                    height: 36,
                    child: ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
                        stops: [0.0, 0.04, 0.9, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 28),
                        itemCount: swatches.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final c = swatches[i];
                          return _Swatch(
                            color: c,
                            selected: !controller.erasing && controller.color == c,
                            onTap: () => onPickColor(c),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Row 3, size + opacity, and a clear-all.
                  Row(
                    children: [
                      Expanded(
                        child: _MiniSlider(
                          value: controller.width.clamp(_minWidth, _maxWidth),
                          min: _minWidth,
                          max: _maxWidth,
                          onChanged: controller.setWidth,
                          leading: Container(
                            width: (controller.width / _maxWidth * 18).clamp(4.0, 18.0),
                            height: (controller.width / _maxWidth * 18).clamp(4.0, 18.0),
                            decoration: BoxDecoration(color: jc.ink, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MiniSlider(
                          value: controller.opacity.clamp(_minOpacity, 1.0),
                          min: _minOpacity,
                          max: 1.0,
                          onChanged: controller.setOpacity,
                          leading: Icon(Icons.opacity, size: 18, color: jc.muted),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _ToolButton(
                        icon: Icons.delete_outline,
                        tooltip: 'Clear',
                        enabled: controller.canUndo,
                        onTap: onClear,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static const double _minWidth = 1.5, _maxWidth = 40, _minOpacity = 0.1;
}

/// A brush (or the eraser) as an icon-over-label pill; the active tool glows in
/// the brand colour.
class _BrushButton extends StatelessWidget {
  const _BrushButton({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final fg = selected ? Colors.white : jc.ink;
    return Pressable(
      label: label,
      selected: selected,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.timed(context, Motion.fast),
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: selected ? jc.brand : jc.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: fg),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.color, required this.selected, required this.onTap});
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    // Selection reads as a ring around the dot (with a gap), not a stamped check -
    // cleaner, and it never fights the swatch colour.
    return Pressable(
      label: 'Pen colour',
      selected: selected,
      pressedScale: 0.9,
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.out,
        width: 34,
        height: 34,
        padding: const EdgeInsets.all(3.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? jc.ink : Colors.transparent, width: 2),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            // A hairline keeps white / pale swatches legible on the surface.
            border: Border.all(color: jc.hairline, width: 1),
          ),
        ),
      ),
    );
  }
}

/// A slim, icon-led slider that fits the drawing toolbar's tight rows.
class _MiniSlider extends StatelessWidget {
  const _MiniSlider({
    required this.leading,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final Widget leading;
  final double value, min, max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Row(
      children: [
        SizedBox(width: 22, child: Center(child: leading)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: jc.brand,
              inactiveTrackColor: jc.surfaceAlt,
              thumbColor: jc.brand,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
        ),
      ],
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.enabled = true,
  });
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final color = enabled ? jc.ink : jc.muted.withValues(alpha: 0.4);
    final button = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(Radii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sm),
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
