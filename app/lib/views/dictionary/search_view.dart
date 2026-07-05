import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/word.dart';
import '../../repositories/dictionary_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/browse_viewmodel.dart';
import '../../viewmodels/search_viewmodel.dart';
import '../widgets/status_views.dart';
import '../widgets/word_tile.dart';
import 'browse_list_view.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => SearchViewModel(
        ctx.read<DictionaryRepository>(),
        glossLanguage: ctx.read<AppState>().mnemonicLanguage,
      ),
      child: const _SearchScreen(),
    );
  }
}

class _SearchScreen extends StatelessWidget {
  const _SearchScreen();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text(
          'jibiki',
          style: TextStyle(
            color: context.jc.brand,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              autofocus: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search kanji, kana, romaji or meaning…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: vm.isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
              ),
              onChanged: vm.onQueryChanged,
              onSubmitted: vm.submit,
            ),
          ),
          Expanded(child: _results(context, vm)),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, SearchViewModel vm) {
    if (vm.hasError) return ErrorRetry(message: vm.error!, onRetry: () => vm.submit(vm.query));
    if (!vm.hasSearched) {
      return const _ExploreLanding();
    }
    if (vm.results.isEmpty && vm.names.isEmpty && vm.isLoading) {
      return const SkeletonTileList();
    }
    if (vm.results.isEmpty && vm.names.isEmpty && !vm.isLoading) {
      return EmptyHint(icon: Icons.search_off, title: 'No matches for “${vm.query}”');
    }
    final jc = context.jc;
    return ListView(
      children: [
        for (var i = 0; i < vm.results.length; i++) ...[
          WordTile(
            word: vm.results[i],
            lang: vm.glossLanguage,
            onTap: () => context.push('/word/${vm.results[i].id}'),
          ),
          Divider(height: 1, color: jc.hairline),
        ],
        if (vm.names.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text('Names', style: context.text.titleMedium),
          ),
          ...vm.names.map((n) => _NameTile(name: n)),
        ],
      ],
    );
  }
}

/// A JMnedict proper-name result: surface + reading + romanized readings + type.
class _NameTile extends StatelessWidget {
  const _NameTile({required this.name});
  final NameItem name;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final subtitle = [
      if (name.kanji.isNotEmpty && name.reading.isNotEmpty) name.reading,
      if (name.translations.isNotEmpty) name.translations.take(3).join(', '),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.badge_outlined, size: 20, color: jc.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.display, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(subtitle, style: TextStyle(color: jc.muted, fontSize: 13)),
                  ),
              ],
            ),
          ),
          if (name.types.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: jc.surfaceAlt, borderRadius: BorderRadius.circular(Radii.pill)),
              child: Text(name.types.first.replaceAll('_', ' '),
                  style: TextStyle(color: jc.body, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

/// The empty-state of Search, turned into an Explore hub: browse the dictionary
/// by category (reading, not flashcards).
class _ExploreLanding extends StatelessWidget {
  const _ExploreLanding();

  void _open(BuildContext c, Widget page) =>
      Navigator.of(c).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text('Explore', style: context.text.headlineSmall),
        const SizedBox(height: 2),
        Text('Browse the dictionary, reading, not flashcards.',
            style: TextStyle(color: jc.muted, fontSize: 13.5)),
        const SizedBox(height: 20),
        _section(context, 'Words'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip(context, 'Common', () => _open(context,
              const BrowseListView(spec: BrowseSpec.words(title: 'Common words', common: true)))),
          _chip(context, 'All words', () => _open(context,
              const BrowseListView(spec: BrowseSpec.words(title: 'All words')))),
          for (final n in [5, 4, 3, 2, 1])
            _chip(context, 'JLPT N$n', () => _open(context,
                BrowseListView(spec: BrowseSpec.words(title: 'JLPT N$n words', jlpt: n)))),
        ]),
        const SizedBox(height: 22),
        _section(context, 'Kanji'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final n in [5, 4, 3, 2, 1])
            _chip(context, 'JLPT N$n', () => _open(context,
                BrowseListView(spec: BrowseSpec.kanji(title: 'JLPT N$n kanji', jlpt: n)))),
          _chip(context, '部 By radical', () => _open(context, const RadicalPickerView())),
        ]),
      ],
    );
  }

  Widget _section(BuildContext c, String t) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(t, style: c.text.titleMedium));

  Widget _chip(BuildContext c, String label, VoidCallback onTap) {
    final jc = c.jc;
    return Material(
      color: jc.brandSoft,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Text(label, style: TextStyle(color: jc.brandPressed, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ),
    );
  }
}
