import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/speech.dart';
import '../../models/kana.dart';
import '../../models/mnemonic.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../theme/app_theme.dart';
import '../widgets/net_image.dart';
import '../widgets/pressable.dart';
import 'draw_mascot_view.dart';

/// A read/learn experience (not flashcards): swipe between characters, see the
/// mnemonic illustration + word, hear it, and draw your own mascot. Mirrors the
/// "memory hint" apps the user referenced (り → licorne, い → ivoire…).
class LearnCarouselView extends StatefulWidget {
  const LearnCarouselView({
    super.key,
    required this.items,
    required this.language,
    this.initialIndex = 0,
    this.title = 'Learn',
  });

  final List<KanaEntry> items;
  final String language;
  final int initialIndex;
  final String title;

  @override
  State<LearnCarouselView> createState() => _LearnCarouselViewState();
}

class _LearnCarouselViewState extends State<LearnCarouselView> {
  late final PageController _pager =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _goto(int i) {
    _pager.animateToPage(i,
        duration: Motion.timed(context, Motion.base), curve: Motion.out);
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          _Strip(items: widget.items, index: _index, onTap: _goto),
          Expanded(
            child: PageView.builder(
              controller: _pager,
              itemCount: widget.items.length,
              onPageChanged: (i) {
                setState(() => _index = i);
                Haptics.tick();
              },
              itemBuilder: (_, i) => LearnPage(
                key: ValueKey(widget.items[i].char),
                item: widget.items[i],
                language: widget.language,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: jc.canvas,
    );
  }
}

/// The kana quick-jump bar. One vermilion pill marks the current character and
/// *slides* between items as the selection moves (tap or page swipe), like a
/// toggle, instead of blinking on in place. Fixed-width cells make the slide exact
/// and let the bar keep the active kana centred as it scrolls.
class _Strip extends StatefulWidget {
  const _Strip({required this.items, required this.index, required this.onTap});
  final List<KanaEntry> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  static const double _cell = 50; // per-item width
  static const double _pad = 12; // ListView-style horizontal padding
  static const double _inset = 4; // gap between the pill and its cell edges
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(jump: true));
  }

  @override
  void didUpdateWidget(covariant _Strip old) {
    super.didUpdateWidget(old);
    if (widget.index != old.index) _center();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Scroll so the active cell sits centred, matching where the pill slides to.
  void _center({bool jump = false}) {
    if (!_scroll.hasClients) return;
    final target = (_pad + widget.index * _cell + _cell / 2) -
        _scroll.position.viewportDimension / 2;
    final to = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if (jump || !Motion.enabled(context)) {
      _scroll.jumpTo(to);
    } else {
      _scroll.animateTo(to, duration: Motion.base, curve: Motion.out);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return SizedBox(
      height: 44,
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _pad),
        child: SizedBox(
          width: widget.items.length * _cell,
          child: Stack(
            children: [
              // The sliding highlight, behind the labels.
              AnimatedPositioned(
                duration: Motion.timed(context, Motion.base),
                curve: Motion.out,
                top: 8,
                bottom: 8,
                left: widget.index * _cell + _inset,
                width: _cell - _inset * 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: jc.brand,
                      borderRadius: BorderRadius.circular(Radii.pill)),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < widget.items.length; i++)
                    SizedBox(
                      width: _cell,
                      child: Pressable(
                        label: widget.items[i].romaji,
                        selected: i == widget.index,
                        onTap: () => widget.onTap(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: Motion.timed(context, Motion.base),
                            curve: Motion.out,
                            style: TextStyle(
                              color:
                                  i == widget.index ? Colors.white : jc.muted,
                              fontWeight: i == widget.index
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: i == widget.index ? 14 : 12.5,
                            ),
                            child: Text(widget.items[i].romaji.toUpperCase()),
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
    );
  }
}

class LearnPage extends StatefulWidget {
  const LearnPage({super.key, required this.item, required this.language});
  final KanaEntry item;
  final String language;

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  Mnemonic? _top;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<MnemonicRepository>().list(
          character: widget.item.char, language: widget.language, kind: 'kana');
      Mnemonic? pick;
      for (final m in list) {
        if (m.hasImage) {
          pick = m;
          break;
        }
      }
      pick ??= list.isNotEmpty ? list.first : null;
      if (mounted) setState(() => _top = pick);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _draw() async {
    Haptics.light();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => DrawMascotView(
              character: widget.item.char, language: widget.language)),
    );
    if (saved == true) {
      setState(() => _loading = true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final item = widget.item;
    final word = _top?.story ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: jc.brandSoft,
                borderRadius: BorderRadius.circular(Radii.xl),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: _loading
                  ? const CircularProgressIndicator()
                  : (_top?.hasImage ?? false)
                      ? NetImage(
                          url: _top!.imageUrl,
                          fit: BoxFit.contain,
                          cacheWidth: 900,
                          semanticLabel: 'Mnemonic drawing for ${item.char}',
                          errorBuilder: (_) => _Glyph(char: item.char),
                        )
                      : _Glyph(char: item.char),
            ),
          ),
          const SizedBox(height: 16),
          Text(item.romaji,
              style: TextStyle(
                  fontSize: 30, fontWeight: FontWeight.w800, color: jc.ink)),
          if (word.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(word,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: jc.body, fontSize: 14.5, height: 1.35)),
            ),
          const SizedBox(height: 16),
          _BottomBar(
              char: item.char,
              onSay: () => Speech.instance.say(item.char),
              onDraw: _draw),
        ],
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.char});
  final String char;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(char,
            style: TextStyle(
                fontSize: 200,
                fontWeight: FontWeight.w700,
                color: context.jc.brand)),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar(
      {required this.char, required this.onSay, required this.onDraw});
  final String char;
  final VoidCallback onSay;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: jc.surface,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: jc.hairline),
        boxShadow: Shadows.soft(context),
      ),
      child: Row(
        children: [
          Text(char,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w700, color: jc.ink)),
          const Spacer(),
          IconButton(
            onPressed: () {
              Haptics.tick();
              onSay();
            },
            icon: Icon(Icons.volume_up_rounded, color: jc.brand),
            tooltip: 'Play audio',
          ),
          IconButton(
            onPressed: onDraw,
            icon: Icon(Icons.edit_outlined, color: jc.brand),
            tooltip: 'Draw a mascot',
          ),
        ],
      ),
    );
  }
}
