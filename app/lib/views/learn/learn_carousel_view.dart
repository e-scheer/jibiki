import 'package:flutter/material.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/speech.dart';
import '../../models/kana.dart';
import '../../models/mnemonic.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../theme/app_theme.dart';
import '../widgets/neo_pop.dart';
import '../widgets/jibiki_brand.dart';
import '../widgets/net_image.dart';
import '../widgets/pressable.dart';
import 'draw_mascot_view.dart';

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
  late final PageController _pager = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _pager.animateToPage(
      index,
      duration: Motion.timed(context, Motion.base),
      curve: Motion.out,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.jc.canvas,
        body: Column(
          children: [
            NeoPageHeader(
              title: widget.title,
              subtitle:
                  '${_index + 1}/${widget.items.length} · ${widget.items[_index].romaji.toUpperCase()}',
              tone: NeoTone.lime,
              leading: NeoIconButton(
                icon: Icons.arrow_back_rounded,
                label: context.trText('Back'),
                onTap: () => Navigator.of(context).pop(),
              ),
              trailing:
                  const NeoBadge('LEARN', tone: NeoTone.magenta, rotate: 2),
            ),
            _Strip(items: widget.items, index: _index, onTap: _goTo),
            Expanded(
              child: PageView.builder(
                controller: _pager,
                itemCount: widget.items.length,
                onPageChanged: (index) {
                  setState(() => _index = index);
                  Haptics.tick();
                },
                itemBuilder: (_, index) => LearnPage(
                  key: ValueKey(widget.items[index].char),
                  item: widget.items[index],
                  language: widget.language,
                ),
              ),
            ),
          ],
        ),
      );
}

class _Strip extends StatefulWidget {
  const _Strip({required this.items, required this.index, required this.onTap});

  final List<KanaEntry> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  State<_Strip> createState() => _StripState();
}

class _StripState extends State<_Strip> {
  static const double _cell = 62;
  static const double _padding = 16;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _center(jump: true));
  }

  @override
  void didUpdateWidget(covariant _Strip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) _center();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _center({bool jump = false}) {
    if (!_scroll.hasClients) return;
    final target = (_padding + widget.index * _cell + _cell / 2) -
        _scroll.position.viewportDimension / 2;
    final offset = target.clamp(0.0, _scroll.position.maxScrollExtent);
    if (jump || !Motion.enabled(context)) {
      _scroll.jumpTo(offset);
    } else {
      _scroll.animateTo(offset, duration: Motion.base, curve: Motion.out);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        height: 74,
        decoration: BoxDecoration(
          color: context.jc.surface,
          border: Border(bottom: BorderSide(color: context.jc.ink, width: 3)),
        ),
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => const LinearGradient(
            colors: [
              Colors.transparent,
              Colors.black,
              Colors.black,
              Colors.transparent,
            ],
            stops: [0, .045, .955, 1],
          ).createShader(rect),
          child: ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(_padding, 8, _padding, 10),
            itemCount: widget.items.length,
            itemBuilder: (_, index) {
              final selected = index == widget.index;
              return SizedBox(
                width: _cell,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Pressable(
                    label: widget.items[index].romaji,
                    selected: selected,
                    pressedScale: 0.94,
                    onTap: () => widget.onTap(index),
                    child: AnimatedContainer(
                      duration: Motion.timed(context, Motion.fast),
                      decoration: BoxDecoration(
                        color: selected ? context.jc.acid : context.jc.canvas,
                        border: Border.all(color: context.jc.ink, width: 2.5),
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: context.jc.ink,
                                  blurRadius: 0,
                                  offset: const Offset(3, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.items[index].char,
                            style: const TextStyle(
                              fontFamily: 'ZenKakuGothicNew',
                              fontSize: 17,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.items[index].romaji.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 8.5,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
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
            character: widget.item.char,
            language: widget.language,
            kind: 'kana',
          );
      Mnemonic? pick;
      for (final mnemonic in list) {
        if (mnemonic.hasImage) {
          pick = mnemonic;
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
          character: widget.item.char,
          language: widget.language,
        ),
      ),
    );
    if (saved == true) {
      setState(() => _loading = true);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final word = _top?.story ?? '';
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final visual = _MnemonicVisual(
              item: item,
              mnemonic: _top,
              loading: _loading,
            );
            final details = _LearnDetails(
              item: item,
              word: word,
              onSay: () => Speech.instance.say(item.char),
              onDraw: _draw,
            );
            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(26),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: visual),
                    const SizedBox(width: 24),
                    Expanded(flex: 5, child: details),
                  ],
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
              child: Column(
                children: [
                  Expanded(child: visual),
                  const SizedBox(height: 18),
                  details,
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MnemonicVisual extends StatelessWidget {
  const _MnemonicVisual({
    required this.item,
    required this.mnemonic,
    required this.loading,
  });

  final KanaEntry item;
  final Mnemonic? mnemonic;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: context.jc.lime,
          border: Border.all(color: context.jc.ink, width: 3),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: context.jc.ink,
              blurRadius: 0,
              offset: const Offset(6, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (loading)
              _VisualSkeleton(character: item.char)
            else if (mnemonic?.hasImage ?? false)
              Padding(
                padding: const EdgeInsets.all(8),
                child: NetImage(
                  url: mnemonic!.imageUrl,
                  fit: BoxFit.contain,
                  cacheWidth: 900,
                  semanticLabel: 'Mnemonic drawing for ${item.char}',
                  errorBuilder: (_) => _Glyph(character: item.char),
                ),
              )
            else
              _Glyph(character: item.char),
            Positioned(
              left: 12,
              top: 12,
              child: NeoBadge(
                mnemonic?.hasImage ?? false ? 'COMMUNITY' : 'KANA',
                tone: NeoTone.magenta,
                rotate: -2,
              ),
            ),
          ],
        ),
      );
}

class _VisualSkeleton extends StatelessWidget {
  const _VisualSkeleton({required this.character});
  final String character;

  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          Text(
            character,
            style: TextStyle(
              color: context.jc.surface.withValues(alpha: 0.52),
              fontFamily: 'ZenKakuGothicNew',
              fontSize: 190,
              fontWeight: FontWeight.w900,
            ),
          ),
          NeoCard(
            tone: NeoTone.paper,
            shadow: 3,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NeoChaseLoader.small(),
                const SizedBox(width: 8),
                Text(
                  context.trText('Loading…'),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      );
}

class _Glyph extends StatelessWidget {
  const _Glyph({required this.character});
  final String character;

  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(42),
          child: Text(
            character,
            style: TextStyle(
              fontFamily: 'ZenKakuGothicNew',
              fontSize: 210,
              fontWeight: FontWeight.w900,
              color: context.jc.ink,
            ),
          ),
        ),
      );
}

class _LearnDetails extends StatelessWidget {
  const _LearnDetails({
    required this.item,
    required this.word,
    required this.onSay,
    required this.onDraw,
  });

  final KanaEntry item;
  final String word;
  final VoidCallback onSay;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: NeoTone.lavender,
        shadow: 5,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.char,
                  style: const TextStyle(
                    fontFamily: 'ZenKakuGothicNew',
                    fontSize: 44,
                    height: 0.9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.romaji.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 28,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.7,
                    ),
                  ),
                ),
                const NeoBadge('SOUND', tone: NeoTone.acid),
              ],
            ),
            if (word.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: context.jc.surface,
                  border: Border.all(color: context.jc.ink, width: 2.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  word,
                  style: TextStyle(
                    color: context.jc.body,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: NeoCard(
                    tone: NeoTone.paper,
                    shadow: 3,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onTap: () {
                      Haptics.tick();
                      onSay();
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.volume_up_rounded, size: 20),
                        const SizedBox(width: 7),
                        Text(
                          context.trText('Listen'),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeoCard(
                    tone: NeoTone.acid,
                    shadow: 4,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    onTap: onDraw,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.edit_outlined, size: 20),
                        const SizedBox(width: 7),
                        Text(
                          context.trText('Draw'),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
