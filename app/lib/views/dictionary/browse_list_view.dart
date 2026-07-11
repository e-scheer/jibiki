import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/kanji.dart';
import '../../repositories/dictionary_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/browse_viewmodel.dart';
import '../widgets/status_views.dart';
import '../widgets/word_tile.dart';

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
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent:
                    88, // ~4 across on phones, denser on tablets
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: vm.kanji.length,
              itemBuilder: (_, i) => _KanjiCell(kanji: vm.kanji[i], lang: lang),
            );
    } else {
      body = vm.words.isEmpty
          ? const EmptyHint(
              icon: Icons.menu_book_outlined, title: 'Nothing here')
          : ListView.separated(
              itemCount: vm.words.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: context.jc.hairline),
              itemBuilder: (_, i) {
                final w = vm.words[i];
                return WordTile(
                    word: w,
                    lang: lang,
                    onTap: () => context.push('/word/${w.id}'));
              },
            );
    }

    return Scaffold(
      appBar: AppBar(title: Text(spec.title)),
      body: body,
    );
  }
}

class _KanjiCell extends StatelessWidget {
  const _KanjiCell({required this.kanji, required this.lang});
  final KanjiEntry kanji;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final meaning = kanji.meaningsFor(lang);
    return Material(
      color: jc.surface,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: () => context.push('/kanji/${kanji.literal}'),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: jc.hairline),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(kanji.literal,
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                meaning.isNotEmpty ? meaning.first : '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: jc.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    final jc = context.jc;
    final radicals = _radicals;
    return Scaffold(
      appBar: AppBar(title: Text(context.trText('By radical'))),
      body: _error != null
          ? ErrorRetry(message: _error!, onRetry: () => setState(() => _load()))
          : radicals == null
              ? const SkeletonCardGrid(
                  count: 18, crossAxisCount: 6, childAspectRatio: 1)
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent:
                        60, // ~6 across on phones, more on tablets
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1,
                  ),
                  itemCount: radicals.length,
                  itemBuilder: (_, i) {
                    final lit = radicals[i]['literal']?.toString() ?? '';
                    return Material(
                      color: jc.surface,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(Radii.sm),
                        onTap: () =>
                            Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => BrowseListView(
                            spec: BrowseSpec.kanji(
                                title: 'Kanji with $lit', contains: lit),
                          ),
                        )),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(Radii.sm),
                            border: Border.all(color: jc.hairline),
                          ),
                          child: Text(lit,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
