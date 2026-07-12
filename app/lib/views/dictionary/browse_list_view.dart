import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../models/kanji.dart';
import '../../repositories/dictionary_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/browse_viewmodel.dart';
import '../widgets/status_views.dart';
import '../widgets/word_tile.dart';
import '../widgets/neo_pop.dart';

/// A read-only browse of one dictionary category (words or kanji). Reachable from
/// the Explore landing, deliberately NOT flashcards.
class BrowseListView extends StatelessWidget {
  const BrowseListView({super.key, required this.spec});
  final BrowseSpec spec;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          BrowseViewModel(ctx.read<DictionaryRepository>(), spec)..load(),
      child: _Browse(spec: spec),
    );
  }
}

class _Browse extends StatelessWidget {
  const _Browse({required this.spec});
  final BrowseSpec spec;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BrowseViewModel>();
    final lang = context.read<AppState>().mnemonicLanguage;

    Widget body;
    if (vm.isLoading && vm.words.isEmpty && vm.kanji.isEmpty) {
      body = spec.isKanji
          ? const SkeletonCardGrid(
              count: 12, crossAxisCount: 4, childAspectRatio: 0.82)
          : const SkeletonTileList();
    } else if (vm.hasError) {
      body = ErrorRetry(message: vm.error!, onRetry: vm.load);
    } else if (spec.isKanji) {
      body = vm.kanji.isEmpty
          ? const EmptyHint(
              icon: Icons.grid_view_outlined, title: 'Nothing here')
          : BoundedContent(
              maxWidth: 920,
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: context.isWide ? 104 : 88,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemCount: vm.kanji.length,
                itemBuilder: (_, i) =>
                    _KanjiCell(kanji: vm.kanji[i], lang: lang),
              ),
            );
    } else {
      body = vm.words.isEmpty
          ? const EmptyHint(
              icon: Icons.menu_book_outlined, title: 'Nothing here')
          : BoundedContent(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 26),
                itemCount: vm.words.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (_, i) {
                  final w = vm.words[i];
                  return WordTile(
                      word: w,
                      lang: lang,
                      onTap: () => context.push('/word/${w.id}'));
                },
              ),
            );
    }

    return Scaffold(
      body: Column(
        children: [
          NeoPageHeader(
            title: spec.title,
            subtitle: spec.isKanji
                ? context.trText('A dense, searchable kanji collection.')
                : context.trText('Dictionary entries ready to explore.'),
            tone: spec.isKanji ? NeoTone.lavender : NeoTone.blue,
            leading: NeoIconButton(
              icon: Icons.arrow_back_rounded,
              label: context.trText('Back'),
              onTap: () => Navigator.pop(context),
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _KanjiCell extends StatelessWidget {
  const _KanjiCell({required this.kanji, required this.lang});
  final KanjiEntry kanji;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final meaning = kanji.meaningsFor(lang);
    final tones = [
      NeoTone.paper,
      NeoTone.lavender,
      NeoTone.lime,
      NeoTone.acid,
    ];
    final tone = tones[kanji.literal.runes.fold<int>(0, (a, b) => a + b) % 4];
    return NeoCard(
      tone: tone,
      shadow: 0,
      radius: 10,
      padding: const EdgeInsets.all(6),
      onTap: () => context.push('/kanji/${kanji.literal}'),
      semanticLabel: '${kanji.literal}, ${meaning.take(1).join()}',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(kanji.literal,
              style:
                  const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(
            meaning.isNotEmpty ? meaning.first : '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: context.jc.body,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RadicalCell extends StatelessWidget {
  const _RadicalCell({required this.literal, required this.onTap});

  final String literal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NeoCard(
        tone: NeoTone.paper,
        shadow: 0,
        radius: 9,
        padding: EdgeInsets.zero,
        onTap: onTap,
        semanticLabel: context.trText('Radical $literal'),
        child: Center(
          child: Text(
            literal,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
      );
}

/// Pick a radical/key, then browse every kanji that contains it.
class RadicalPickerView extends StatefulWidget {
  const RadicalPickerView({super.key});

  @override
  State<RadicalPickerView> createState() => _RadicalPickerViewState();
}

class _RadicalPickerViewState extends State<RadicalPickerView> {
  List<Map<String, dynamic>>? _radicals;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<DictionaryRepository>().radicals();
      if (mounted) setState(() => _radicals = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final radicals = _radicals;
    final content = _error != null
        ? ErrorRetry(message: _error!, onRetry: () => setState(() => _load()))
        : radicals == null
            ? const SkeletonCardGrid(
                count: 18,
                crossAxisCount: 6,
                childAspectRatio: 1,
              )
            : BoundedContent(
                maxWidth: 920,
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 60,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 1,
                  ),
                  itemCount: radicals.length,
                  itemBuilder: (_, i) {
                    final lit = radicals[i]['literal']?.toString() ?? '';
                    return _RadicalCell(
                      literal: lit,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BrowseListView(
                            spec: BrowseSpec.kanji(
                              title: 'Kanji with $lit',
                              contains: lit,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
    return Scaffold(
      body: Column(
        children: [
          NeoPageHeader(
            title: context.trText('By radical'),
            subtitle: context.trText(
              'Choose a component to narrow the kanji matrix.',
            ),
            tone: NeoTone.lime,
            leading: NeoIconButton(
              icon: Icons.arrow_back_rounded,
              label: context.trText('Back'),
              onTap: () => Navigator.pop(context),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}
