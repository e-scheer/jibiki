import 'package:jibiki/l10n/l10n.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../repositories/mnemonic_repository.dart';
import '../../theme/app_theme.dart';
import '../widgets/horizontal_overflow_cue.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/neo_pop.dart';
import '../widgets/pressable.dart';
import 'drawing_pad.dart';

/// Turn a character into a picture: draw a mascot around the glyph (り →
/// licorne), name what it looks like, and save it as a mnemonic image. A full
/// little studio, six brush engines (pen · calligraphy · marker · pencil ·
/// neon · spray), a curated palette plus custom colours, size + opacity, a real
/// eraser, two layers around the guide, undo/redo and a show/hide guide. The
/// composited drawing is captured and uploaded.
class DrawMascotView extends StatefulWidget {
  const DrawMascotView(
      {super.key,
      required this.character,
      required this.language,
      this.kind = 'kana'});
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

  bool get _canSave =>
      _word.text.trim().isNotEmpty && !_paint.isEmpty && !_saving;

  Future<void> _save() async {
    final repo =
        context.read<MnemonicRepository>(); // read before the async gaps
    setState(() => _saving = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
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
      final msg = created.status == 'visible'
          ? 'Saved, thank you!'
          : 'Submitted for review, thank you!';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.trText('Could not save the drawing'))));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _confirmClear() async {
    if (_paint.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: NeoCard(
            tone: NeoTone.lavender,
            shadow: 7,
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const NeoBadge('CLEAR', tone: NeoTone.coral, rotate: -2),
                const SizedBox(height: 16),
                Text(
                  context.trText('Clear the drawing?'),
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.trText('This removes everything on the canvas.'),
                  style: TextStyle(
                    color: context.jc.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: NeoCard(
                        shadow: 3,
                        onTap: () => Navigator.pop(dialogContext, false),
                        child: Center(
                          child: Text(
                            context.trText('Cancel'),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: NeoCard(
                        tone: NeoTone.coral,
                        shadow: 4,
                        onTap: () => Navigator.pop(dialogContext, true),
                        child: Center(
                          child: Text(
                            context.trText('Clear'),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      backgroundColor: context.jc.canvas,
      body: Column(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([_paint, _word]),
            builder: (_, __) => _StudioTop(
              character: widget.character,
              saving: _saving,
              canSave: _canSave,
              onBack: () => Navigator.of(context).pop(),
              onSave: _save,
            ),
          ),
          ListenableBuilder(
            listenable: _paint,
            builder: (_, __) => _UtilityStrip(
              showGuide: _showGuide,
              enabled: !_saving,
              canUndo: _paint.canUndo,
              canRedo: _paint.canRedo,
              onGuide: () => setState(() => _showGuide = !_showGuide),
              onUndo: () {
                Haptics.tick();
                _paint.undo();
              },
              onRedo: () {
                Haptics.tick();
                _paint.redo();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            child: NeoCard(
              shadow: 3,
              padding: const EdgeInsets.all(3),
              child: TextField(
                controller: _word,
                enabled: !_saving,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: context.trText('It looks like…'),
                  prefixIcon: const Icon(Icons.lightbulb_outline_rounded),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
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
            enabled: !_saving,
            onPickColor: (color) {
              Haptics.tick();
              _paint.setColor(color);
            },
            onClear: _confirmClear,
          ),
        ],
      ),
    );
  }
}

class _StudioTop extends StatelessWidget {
  const _StudioTop({
    required this.character,
    required this.saving,
    required this.canSave,
    required this.onBack,
    required this.onSave,
  });

  final String character;
  final bool saving;
  final bool canSave;
  final VoidCallback onBack;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: context.jc.magenta,
          border: Border(bottom: BorderSide(color: context.jc.ink, width: 3)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                NeoIconButton(
                  icon: Icons.arrow_back_rounded,
                  label: context.trText('Back'),
                  onTap: onBack,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.trText('Draw · $character'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        context.trText('Turn the glyph into a memory.'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                NeoCard(
                  tone: canSave ? NeoTone.acid : NeoTone.paper,
                  shadow: canSave ? 4 : 0,
                  radius: 9,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  onTap: canSave ? onSave : null,
                  child: saving
                      ? const NeoChaseLoader.small()
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_rounded, size: 18),
                            const SizedBox(width: 5),
                            Text(
                              context.trText('Save'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _UtilityStrip extends StatelessWidget {
  const _UtilityStrip({
    required this.showGuide,
    required this.canUndo,
    required this.canRedo,
    required this.onGuide,
    required this.onUndo,
    required this.onRedo,
    this.enabled = true,
  });

  final bool showGuide;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onGuide;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
        color: context.jc.surface,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            NeoBadge(
              showGuide
                  ? context.trText('GUIDE ON')
                  : context.trText('GUIDE OFF'),
              tone: showGuide ? NeoTone.lime : NeoTone.paper,
            ),
            const Spacer(),
            _StudioIconAction(
              icon: showGuide
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              label: showGuide ? 'Hide guide' : 'Show guide',
              onTap: enabled ? onGuide : null,
            ),
            const SizedBox(width: 8),
            _StudioIconAction(
              icon: Icons.undo_rounded,
              label: context.trText('Undo'),
              onTap: enabled && canUndo ? onUndo : null,
            ),
            const SizedBox(width: 8),
            _StudioIconAction(
              icon: Icons.redo_rounded,
              label: context.trText('Redo'),
              onTap: enabled && canRedo ? onRedo : null,
            ),
          ],
        ),
      );
}

class _StudioIconAction extends StatelessWidget {
  const _StudioIconAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: SizedBox.square(
          dimension: 38,
          child: NeoCard(
            shadow: onTap == null ? 0 : 2,
            radius: 8,
            padding: EdgeInsets.zero,
            onTap: onTap,
            semanticLabel: label,
            child: Icon(icon, size: 18),
          ),
        ),
      );
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.swatches,
    required this.onPickColor,
    required this.onClear,
    this.enabled = true,
  });

  final PaintController controller;
  final List<Color> swatches;
  final ValueChanged<Color> onPickColor;
  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: jc.lavender,
            border: Border(top: BorderSide(color: jc.ink, width: 3)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeoSegmentedControl<DrawingLayer>(
                    segments: [
                      for (final layer in DrawingLayer.values)
                        NeoSegment(
                          layer,
                          layer.label,
                          icon: layer.icon,
                        ),
                    ],
                    selected: controller.layer,
                    enabled: enabled,
                    height: 48,
                    onChanged: (layer) {
                      Haptics.tick();
                      controller.setLayer(layer);
                    },
                  ),
                  const SizedBox(height: 10),
                  // Brushes (the headline of the studio) + eraser.
                  SizedBox(
                    height: 58,
                    child: HorizontalOverflowCue(
                      edgeColor: jc.lavender,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final b in Brush.values) ...[
                              _BrushButton(
                                icon: b.icon,
                                label: b.label,
                                selected: !controller.erasing &&
                                    controller.brush == b,
                                enabled: enabled,
                                onTap: () {
                                  Haptics.tick();
                                  controller.setBrush(b);
                                },
                              ),
                              const SizedBox(width: 8),
                            ],
                            Container(width: 2.5, height: 40, color: jc.ink),
                            const SizedBox(width: 8),
                            _BrushButton(
                              icon: Icons.auto_fix_normal,
                              label: 'Eraser',
                              selected: controller.erasing,
                              enabled: enabled,
                              onTap: () {
                                Haptics.tick();
                                controller.setErasing(!controller.erasing);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Row 2, the fixed house palette. A soft fade at both ends signals
                  // the strip scrolls - a quiet "there's more" cue.
                  SizedBox(
                    // Tall enough that a selected swatch's 1.08 scale-up and an
                    // unselected swatch's drop shadow both fit; each swatch is
                    // centered so the growth is symmetric and never clipped at
                    // the top by the ListView's own viewport.
                    height: 44,
                    child: HorizontalOverflowCue(
                      edgeColor: jc.lavender,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(right: 28),
                        itemCount: swatches.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final c = swatches[i];
                          return SizedBox(
                            height: 44,
                            child: Center(
                              child: _Swatch(
                                color: c,
                                selected: !controller.erasing &&
                                    controller.color == c,
                                enabled: enabled,
                                onTap: () => onPickColor(c),
                              ),
                            ),
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
                          onChanged: enabled ? controller.setWidth : (_) {},
                          enabled: enabled,
                          leading: Container(
                            width: (controller.width / _maxWidth * 18)
                                .clamp(4.0, 18.0),
                            height: (controller.width / _maxWidth * 18)
                                .clamp(4.0, 18.0),
                            decoration: BoxDecoration(
                                color: jc.ink, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MiniSlider(
                          value: controller.opacity.clamp(_minOpacity, 1.0),
                          min: _minOpacity,
                          max: 1.0,
                          onChanged: enabled ? controller.setOpacity : (_) {},
                          enabled: enabled,
                          leading:
                              Icon(Icons.opacity, size: 18, color: jc.muted),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _ToolButton(
                        icon: Icons.delete_outline,
                        tooltip: context.trText('Clear'),
                        enabled: enabled && controller.canUndo,
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
  const _BrushButton(
      {required this.icon,
      required this.label,
      required this.selected,
      required this.onTap,
      this.enabled = true});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final fg = jc.ink;
    return Opacity(
      opacity: enabled ? 1 : .48,
      child: Pressable(
        label: label,
        selected: selected,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: Motion.timed(context, Motion.fast),
          width: 60,
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? jc.acid : jc.surface,
            border: Border.all(color: jc.ink, width: 2.5),
            borderRadius: BorderRadius.circular(Radii.md),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: jc.ink,
                      blurRadius: 0,
                      offset: const Offset(3, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600, color: fg),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(
      {required this.color,
      required this.selected,
      required this.onTap,
      this.enabled = true});
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Opacity(
      opacity: enabled ? 1 : .48,
      child: Pressable(
        label: 'Pen colour',
        selected: selected,
        pressedScale: 0.9,
        onTap: enabled ? onTap : null,
        child: AnimatedScale(
          duration: Motion.timed(context, Motion.fast),
          curve: Motion.out,
          scale: selected ? 1.08 : 1,
          child: AnimatedContainer(
            duration: Motion.timed(context, Motion.fast),
            curve: Motion.out,
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: jc.ink, width: 2.5),
              boxShadow: selected
                  ? null
                  : const [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 0,
                        offset: Offset(3, 3),
                      ),
                    ],
            ),
            child: AnimatedSwitcher(
              duration: Motion.timed(context, Motion.fast),
              child: selected
                  ? Icon(
                      Icons.check_rounded,
                      key: const ValueKey('selected'),
                      size: 18,
                      color: color.computeLuminance() > .56
                          ? jc.ink
                          : Colors.white,
                    )
                  : const SizedBox.shrink(key: ValueKey('not-selected')),
            ),
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
    this.enabled = true,
  });
  final Widget leading;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final bool enabled;

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
              activeTrackColor: jc.ink,
              inactiveTrackColor: jc.surface,
              thumbColor: jc.acid,
              overlayShape: SliderComponentShape.noOverlay,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: enabled ? onChanged : null,
            ),
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
    final button = Opacity(
      opacity: enabled ? 1 : 0.35,
      child: NeoCard(
        tone: NeoTone.coral,
        shadow: enabled ? 3 : 0,
        radius: 8,
        padding: const EdgeInsets.all(9),
        onTap: enabled ? onTap : null,
        semanticLabel: tooltip,
        child: Icon(icon, size: 20, color: color),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
