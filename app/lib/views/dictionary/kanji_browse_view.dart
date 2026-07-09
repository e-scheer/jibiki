import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/kanji.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../widgets/pressable.dart';
import '../widgets/selection_action_bar.dart';
import '../widgets/status_views.dart';
import '../widgets/study_mark.dart';
import 'browse_list_view.dart';

/// Browse every kanji with a fast, intuitive finder: a text filter (by character
/// or meaning), JLPT level chips, and a "by radical" shortcut.
class KanjiBrowseView extends StatefulWidget {
  const KanjiBrowseView({super.key});

  @override
  State<KanjiBrowseView> createState() => _KanjiBrowseViewState();
}

class _KanjiBrowseViewState extends State<KanjiBrowseView> {
  List<KanjiEntry> _all = [];
  bool _loading = true;
  String? _error;
  int? _jlpt; // modern N5–N1 (populated by the JLPT community mapping)
  String _q = '';

  bool _selecting = false;
  bool _busy = false;
  final Set<String> _selected = {};
  Map<String, int> _states = const {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadStates();
  }

  Future<void> _loadStates() async {
    try {
      final s = await context.read<StudyRepository>().studyStates(type: ItemType.kanji);
      if (mounted) setState(() => _states = s);
    } catch (_) {
      // No study state (e.g. offline) just means no badges.
    }
  }

  void _toggle(String literal) {
    Haptics.tick();
    setState(() => _selected.contains(literal) ? _selected.remove(literal) : _selected.add(literal));
  }

  Future<void> _bulk(bool known, List<KanjiEntry> visible) async {
    if (_selected.isEmpty || _busy) return;
    Haptics.medium();
    setState(() => _busy = true);
    final items = [for (final c in _selected) (type: ItemType.kanji, ref: c)];
    try {
      final summary = await context.read<StudyRepository>().bulkAdd(items, known: known);
      if (!mounted) return;
      await _loadStates();
      if (!mounted) return;
      final n = summary['resolved'] ?? items.length;
      setState(() {
        _selecting = false;
        _selected.clear();
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(known ? 'Marked $n as known' : 'Added $n to study')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update your deck')));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<DictionaryRepository>().kanjiList(jlpt: _jlpt, limit: 1500);
      if (mounted) setState(() => _all = r);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<KanjiEntry> _filtered(String lang) {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return _all;
    return _all.where((k) {
      if (k.literal.contains(q)) return true;
      return k.meaningsFor(lang).any((m) => m.toLowerCase().contains(q));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.read<AppState>().mnemonicLanguage;
    final list = _filtered(lang);

    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel',
                onPressed: () => setState(() {
                  _selecting = false;
                  _selected.clear();
                }),
              )
            : null,
        title: Text(_selecting ? '${_selected.length} selected' : 'Kanji'),
        actions: _selecting
            ? [
                TextButton(
                  onPressed: list.isEmpty
                      ? null
                      : () {
                          Haptics.tick();
                          setState(() => _selected.addAll(list.map((k) => k.literal)));
                        },
                  child: const Text('Select all'),
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Select kanji',
                  icon: const Icon(Icons.checklist_rounded),
                  onPressed: () => setState(() => _selecting = true),
                ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push('/settings'),
                ),
              ],
      ),
      bottomNavigationBar: _selecting
          ? SelectionActionBar(
              count: _selected.length,
              busy: _busy,
              onKnown: () => _bulk(true, list),
              onAdd: () => _bulk(false, list),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Filter by kanji or meaning…',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('All', _jlpt == null, () => _setJlpt(null)),
                for (final n in [5, 4, 3, 2, 1]) _chip('N$n', _jlpt == n, () => _setJlpt(n)),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: _chip('部 Radical', false,
                      () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RadicalPickerView()))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const SkeletonCardGrid(
                    count: 12,
                    crossAxisCount: 4,
                    childAspectRatio: 0.9,
                    padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                  )
                : _error != null
                    ? ErrorRetry(message: _error!, onRetry: _load)
                    : list.isEmpty
                        ? const EmptyHint(icon: Icons.search_off, title: 'No kanji found')
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 88, // ~4 across on phones, denser on tablets
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.9,
                            ),
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final k = list[i];
                              return _KanjiTile(
                                kanji: k,
                                lang: lang,
                                selecting: _selecting,
                                selected: _selected.contains(k.literal),
                                mark: studyMarkFor(_states[k.literal]),
                                onToggle: () => _toggle(k.literal),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _setJlpt(int? n) {
    setState(() => _jlpt = n);
    _load();
  }

  Widget _chip(String label, bool on, VoidCallback onTap) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Pressable(
        label: label,
        selected: on,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: on ? jc.brand : jc.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.pill),
          ),
          child: Text(label,
              style: TextStyle(
                  color: on ? Colors.white : jc.body, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ),
    );
  }
}

class _KanjiTile extends StatelessWidget {
  const _KanjiTile({
    required this.kanji,
    required this.lang,
    required this.selecting,
    required this.selected,
    required this.mark,
    required this.onToggle,
  });
  final KanjiEntry kanji;
  final String lang;
  final bool selecting;
  final bool selected;
  final StudyMark mark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final meaning = kanji.meaningsFor(lang);
    // Soft filled tile (no per-tile border) to match the kana chart: a calm grid
    // where the glyph is the loudest thing. Selected lifts with the vermilion
    // wash + ring; a press gives a real button response via Pressable.
    return Pressable(
      label: '${kanji.literal} ${meaning.isNotEmpty ? meaning.first : ''}',
      selected: selected,
      onTap: selecting ? onToggle : () => context.push('/kanji/${kanji.literal}'),
      child: AnimatedContainer(
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.out,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? jc.brandSoft : jc.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: selected ? jc.brand : Colors.transparent, width: 1.5),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(kanji.literal,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, height: 1, color: jc.ink)),
                  const SizedBox(height: 5),
                  Text(
                    meaning.isNotEmpty ? meaning.first : '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: jc.muted, height: 1.1),
                  ),
                ],
              ),
            ),
            if (mark != StudyMark.none) Positioned(top: 4, right: 4, child: StudyDot(mark: mark)),
          ],
        ),
      ),
    );
  }
}
