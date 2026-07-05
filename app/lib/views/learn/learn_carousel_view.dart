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
  late final PageController _pager = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _goto(int i) {
    _pager.animateToPage(i, duration: Motion.timed(context, Motion.base), curve: Motion.out);
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

class _Strip extends StatelessWidget {
  const _Strip({required this.items, required this.index, required this.onTap});
  final List<KanaEntry> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final on = i == index;
          return Pressable(
            label: items[i].romaji,
            selected: on,
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: Motion.timed(context, Motion.fast),
              alignment: Alignment.center,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: on ? jc.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
              child: Text(
                items[i].romaji.toUpperCase(),
                style: TextStyle(
                  color: on ? Colors.white : jc.muted,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                  fontSize: on ? 14 : 12.5,
                ),
              ),
            ),
          );
        },
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
      final list = await context
          .read<MnemonicRepository>()
          .list(character: widget.item.char, language: widget.language, kind: 'kana');
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
      MaterialPageRoute(builder: (_) => DrawMascotView(character: widget.item.char, language: widget.language)),
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
          Text(item.romaji, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: jc.ink)),
          if (word.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(word,
                  textAlign: TextAlign.center, style: TextStyle(color: jc.body, fontSize: 14.5, height: 1.35)),
            ),
          const SizedBox(height: 16),
          _BottomBar(char: item.char, onSay: () => Speech.instance.say(item.char), onDraw: _draw),
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
        child: Text(char, style: TextStyle(fontSize: 200, fontWeight: FontWeight.w700, color: context.jc.brand)),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.char, required this.onSay, required this.onDraw});
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
          Text(char, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: jc.ink)),
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
