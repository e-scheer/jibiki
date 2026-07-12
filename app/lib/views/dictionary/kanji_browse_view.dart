import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/kanji.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../widgets/horizontal_overflow_cue.dart';
import '../widgets/neo_pop.dart';
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
      final s = await context
          .read<StudyRepository>()
          .studyStates(type: ItemType.kanji);
      if (mounted) setState(() => _states = s);
    } catch (_) {
      // No study state (e.g. offline) just means no badges.
    }
  }

  void _toggle(String literal) {
    Haptics.tick();
    setState(() => _selected.contains(literal)
        ? _selected.remove(literal)
        : _selected.add(literal));
  }

  Future<void> _bulk(bool known, List<KanjiEntry> visible) async {
    if (_selected.isEmpty || _busy) return;
    Haptics.medium();
    setState(() => _busy = true);
    final items = [for (final c in _selected) (type: ItemType.kanji, ref: c)];
    try {
      final summary =
          await context.read<StudyRepository>().bulkAdd(items, known: known);
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
        SnackBar(
            content: Text(known ? 'Marked $n as known' : 'Added $n to study')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.trText('Could not update your deck'))));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context
          .read<DictionaryRepository>()
          .kanjiList(jlpt: _jlpt, limit: 1500);
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

    final canPop = Navigator.of(context).canPop();
    return Scaffold(
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
          NeoPageHeader(
            title: _selecting ? '${_selected.length} selected' : 'Kanji',
            subtitle: _selecting
                ? context.trText('Choose the kanji to update together.')
                : context.trText('Filter the matrix by meaning or level.'),
            tone: _selecting ? NeoTone.acid : NeoTone.lavender,
            leading: _selecting
                ? NeoIconButton(
                    icon: Icons.close_rounded,
                    label: context.trText('Cancel'),
                    onTap: _busy
                        ? null
                        : () => setState(() {
                              _selecting = false;
                              _selected.clear();
                            }),
                  )
                : canPop
                    ? NeoIconButton(
                        icon: Icons.arrow_back_rounded,
                        label: context.trText('Back'),
                        onTap: () => Navigator.pop(context),
                      )
                    : null,
            trailing: _selecting
                ? _BrowseHeaderAction(
                    label: context.trText('Select all'),
                    enabled: list.isNotEmpty && !_busy,
                    onTap: () => setState(
                      () => _selected.addAll(list.map((k) => k.literal)),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NeoIconButton(
                        icon: Icons.checklist_rounded,
                        label: context.trText('Select kanji'),
                        onTap: _busy
                            ? null
                            : () => setState(() => _selecting = true),
                      ),
                      const SizedBox(width: 8),
                      NeoIconButton(
                        icon: Icons.settings_outlined,
                        label: context.trText('Settings'),
                        onTap: () => context.push('/settings'),
                      ),
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              onChanged: _busy ? null : (v) => setState(() => _q = v),
              enabled: !_busy,
              decoration: InputDecoration(
                hintText: context.trText('Filter by kanji or meaning…'),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 38,
            child: HorizontalOverflowCue(
              edgeColor: context.jc.canvas,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip('All', _jlpt == null, () => _setJlpt(null),
                      enabled: !_busy),
                  for (final n in [5, 4, 3, 2, 1])
                    _chip('N$n', _jlpt == n, () => _setJlpt(n),
                        enabled: !_busy),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: _chip(
                        '部 Radical',
                        false,
                        () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const RadicalPickerView())),
                        enabled: !_busy),
                  ),
                ],
              ),
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
                        ? const EmptyHint(
                            icon: Icons.search_off, title: 'No kanji found')
                        : GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 68,
                              mainAxisSpacing: 6,
                              crossAxisSpacing: 6,
                              childAspectRatio: 0.72,
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

  Widget _chip(String label, bool on, VoidCallback onTap,
      {bool enabled = true}) {
    final jc = context.jc;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: Pressable(
          label: label,
          selected: on,
          onTap: enabled ? onTap : null,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: on ? jc.acid : jc.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: jc.ink, width: 2.5),
              boxShadow: on
                  ? [
                      BoxShadow(
                        color: jc.ink,
                        blurRadius: 0,
                        offset: const Offset(3, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(label,
                style: TextStyle(
                    color: jc.ink, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

class _BrowseHeaderAction extends StatelessWidget {
  const _BrowseHeaderAction({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: enabled ? 1 : 0.45,
        child: SizedBox(
          height: 44,
          child: NeoCard(
            tone: NeoTone.paper,
            shadow: enabled ? 3 : 0,
            radius: 10,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            semanticLabel: label,
            onTap: enabled ? onTap : null,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      );
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
    // Dense matrix cells stay flat. Repeating a hard shadow across a six-column
    // grid turns the state colors into noise and diverges from the HTML contract.
    return Pressable(
      label: '${kanji.literal} ${meaning.isNotEmpty ? meaning.first : ''}',
      selected: selected,
      onTap:
          selecting ? onToggle : () => context.push('/kanji/${kanji.literal}'),
      child: AnimatedContainer(
        duration: Motion.timed(context, Motion.fast),
        curve: Motion.out,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected
              ? jc.acid
              : mark == StudyMark.known
                  ? jc.lime
                  : mark == StudyMark.seen
                      ? jc.magenta
                      : jc.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: jc.ink, width: 2.5),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                kanji.literal,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: jc.ink,
                ),
              ),
            ),
            if (mark != StudyMark.none)
              Positioned(top: 4, right: 4, child: StudyDot(mark: mark)),
          ],
        ),
      ),
    );
  }
}
