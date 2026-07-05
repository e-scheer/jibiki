import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/enums.dart';
import '../../models/kana.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/kana_viewmodel.dart';
import '../learn/learn_carousel_view.dart';
import '../widgets/pressable.dart';
import '../widgets/selection_action_bar.dart';
import '../widgets/status_views.dart';
import '../widgets/study_mark.dart';

class KanaChartView extends StatelessWidget {
  const KanaChartView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => KanaViewModel(ctx.read<DictionaryRepository>())..load(),
      child: const _KanaChart(),
    );
  }
}

/// Passed down to each cell: which chars are already carded (for the badge), and,
/// in select mode, which are picked plus how to toggle them.
class _Selection {
  const _Selection({required this.active, required this.chars, required this.states, required this.onToggle});
  final bool active;
  final Set<String> chars;
  final Map<String, int> states;
  final void Function(List<KanaEntry> entries) onToggle;

  bool contains(String c) => chars.contains(c);
}

class _KanaChart extends StatefulWidget {
  const _KanaChart();

  @override
  State<_KanaChart> createState() => _KanaChartState();
}

class _KanaChartState extends State<_KanaChart> {
  // Extra kana shown below the main gojūon table.
  static const _extras = {
    'dakuten': 'Dakuten ゛',
    'handakuten': 'Handakuten ゜',
    'yoon': 'Yōon',
  };

  bool _selecting = false;
  bool _busy = false;
  final Set<String> _selected = {};
  Map<String, int> _states = const {};

  // +1 when the new script sits to the right of the old one in the toggle, -1 to
  // the left — so the matrix slides in the direction you moved the pill.
  double _slideDir = 1;

  static int _scriptIndex(String s) => switch (s) { 'hiragana' => 0, 'katakana' => 1, _ => 2 };

  void _changeScript(KanaViewModel vm, String s) {
    if (s == vm.script) return;
    final dir = _scriptIndex(s) >= _scriptIndex(vm.script) ? 1.0 : -1.0;
    setState(() {
      _slideDir = dir;
      _selected.clear();
    });
    vm.setScript(s);
  }

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  Future<void> _loadStates() async {
    try {
      final s = await context.read<StudyRepository>().studyStates(type: ItemType.kana);
      if (mounted) setState(() => _states = s);
    } catch (_) {
      // No study state (e.g. offline) just means no badges — never block the chart.
    }
  }

  void _toggleCell(List<KanaEntry> entries) {
    Haptics.tick();
    setState(() {
      final chars = entries.map((e) => e.char);
      final allIn = chars.every(_selected.contains);
      for (final c in chars) {
        allIn ? _selected.remove(c) : _selected.add(c);
      }
    });
  }

  void _enterSelect() => setState(() => _selecting = true);

  void _exitSelect() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  void _selectAllVisible(KanaViewModel vm) {
    Haptics.tick();
    setState(() => _selected.addAll(vm.current.map((k) => k.char)));
  }

  Future<void> _bulk(bool known) async {
    if (_selected.isEmpty || _busy) return;
    Haptics.medium();
    setState(() => _busy = true);
    final items = [for (final c in _selected) (type: ItemType.kana, ref: c)];
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KanaViewModel>();
    final sel = _Selection(
      active: _selecting,
      chars: _selected,
      states: _states,
      onToggle: _toggleCell,
    );

    return Scaffold(
      appBar: AppBar(
        leading: _selecting
            ? IconButton(icon: const Icon(Icons.close), tooltip: 'Cancel', onPressed: _exitSelect)
            : null,
        title: Text(_selecting ? '${_selected.length} selected' : 'Kana'),
        actions: _selecting
            ? [
                TextButton(
                  onPressed: vm.current.isEmpty ? null : () => _selectAllVisible(vm),
                  child: const Text('Select all'),
                ),
              ]
            : [
                if (vm.current.isNotEmpty)
                  IconButton(
                    tooltip: 'Mark what you know',
                    icon: const Icon(Icons.checklist_rounded),
                    onPressed: _enterSelect,
                  ),
                if (vm.current.isNotEmpty)
                  IconButton(
                    tooltip: 'Learn with mnemonics',
                    icon: const Icon(Icons.auto_stories_outlined),
                    onPressed: () {
                      final lang = context.read<AppState>().mnemonicLanguage;
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => LearnCarouselView(
                          items: vm.current,
                          language: lang,
                          title: switch (vm.script) {
                            'hiragana' => 'Hiragana',
                            'katakana' => 'Katakana',
                            _ => 'Kana',
                          },
                        ),
                      ));
                    },
                  ),
                IconButton(
                  tooltip: 'Settings',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => context.push('/settings'),
                ),
              ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: _ScriptToggle(
              script: vm.script,
              onChanged: (s) => _changeScript(vm, s),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _selecting
          ? SelectionActionBar(
              count: _selected.length,
              busy: _busy,
              onKnown: () => _bulk(true),
              onAdd: () => _bulk(false),
            )
          : null,
      body: vm.isLoading
          ? const LoadingView()
          : vm.hasError
              ? ErrorRetry(message: vm.error!, onRetry: vm.load)
              : AnimatedSwitcher(
                  duration: Motion.timed(context, Motion.base),
                  switchInCurve: Motion.out,
                  switchOutCurve: Motion.out,
                  // Crossfade + a small slide in the direction the toggle moved.
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(begin: Offset(0.05 * _slideDir, 0), end: Offset.zero)
                          .animate(animation),
                      child: child,
                    ),
                  ),
                  child: ListView(
                    key: ValueKey(vm.script),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: [
                      if (!_selecting)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Tap the checklist to mark the kana you already know.',
                            style: TextStyle(color: context.jc.muted, fontSize: 12.5),
                          ),
                        ),
                      _KanaMatrix(items: vm.byKind('gojuon'), sel: sel),
                      for (final entry in _extras.entries)
                        if (vm.byKind(entry.key).isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 22, bottom: 6),
                            child: Text(entry.value, style: context.text.titleMedium),
                          ),
                          _KanaMatrix(items: vm.byKind(entry.key), sel: sel),
                        ],
                    ],
                  ),
                ),
    );
  }
}

/// A flat pill toggle in place of the Material SegmentedButton.
class _ScriptToggle extends StatelessWidget {
  const _ScriptToggle({required this.script, required this.onChanged});
  final String script;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    Widget seg(String value, String label) {
      final on = script == value;
      return Expanded(
        child: Pressable(
          label: label,
          selected: on,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: Motion.timed(context, Motion.fast),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: on ? jc.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Text(label,
                style: TextStyle(
                    color: on ? Colors.white : jc.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: jc.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
      child: Row(children: [
        seg('hiragana', 'Hiragana'),
        seg('katakana', 'Katakana'),
        seg('both', 'Both'),
      ]),
    );
  }
}

/// A canonical kana matrix, vowel columns (a/i/u/e/o) × consonant rows, used
/// for gojūon, dakuten and handakuten alike, so any set is found "where is it" at
/// a glance. Rows are derived from the data (so g/z/d/b, p… order themselves);
/// each cell shows one script, or both side by side in "Both" mode. ん (no vowel)
/// sits on its own line.
class _KanaMatrix extends StatelessWidget {
  const _KanaMatrix({required this.items, required this.sel});
  final List<KanaEntry> items;
  final _Selection sel;

  static const _vowels = ['a', 'i', 'u', 'e', 'o'];
  static const _rowLabel = {'a': ''}; // vowel-only row has no consonant label

  String _vowelOf(String romaji) {
    if (romaji.isEmpty) return '';
    final last = romaji[romaji.length - 1];
    return _vowels.contains(last) ? last : '';
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    // key "row+vowel" → entries (1 per script; 2 in Both mode, hiragana first).
    final byKey = <String, List<KanaEntry>>{};
    final noVowel = <KanaEntry>[]; // ん / ン
    final rowMinOrder = <String, int>{};
    for (final k in items) {
      final v = _vowelOf(k.romaji);
      if (v.isEmpty) {
        noVowel.add(k);
        continue;
      }
      (byKey['${k.row}$v'] ??= <KanaEntry>[]).add(k);
      final cur = rowMinOrder[k.row];
      if (cur == null || k.order < cur) rowMinOrder[k.row] = k.order;
    }
    for (final list in byKey.values) {
      list.sort((a, b) => (a.isHiragana ? 0 : 1).compareTo(b.isHiragana ? 0 : 1));
    }
    noVowel.sort((a, b) => (a.isHiragana ? 0 : 1).compareTo(b.isHiragana ? 0 : 1));
    final rows = rowMinOrder.keys.toList()
      ..sort((a, b) => rowMinOrder[a]!.compareTo(rowMinOrder[b]!));

    final headerStyle = TextStyle(color: jc.muted, fontWeight: FontWeight.w800, fontSize: 12);

    Widget cell(List<KanaEntry>? entries) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(2.5),
            child: (entries == null || entries.isEmpty)
                ? const SizedBox(height: 48)
                : _TableCell(entries: entries, sel: sel),
          ),
        );

    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 20),
            for (final v in _vowels) Expanded(child: Center(child: Text(v.toUpperCase(), style: headerStyle))),
          ],
        ),
        const SizedBox(height: 4),
        for (final r in rows)
          Row(
            children: [
              SizedBox(
                width: 20,
                child: Center(child: Text(_rowLabel[r] ?? r.toUpperCase(), style: headerStyle)),
              ),
              for (final v in _vowels) cell(byKey['$r$v']),
            ],
          ),
        if (noVowel.isNotEmpty)
          Row(
            children: [
              const SizedBox(width: 20),
              cell(noVowel),
              const Expanded(flex: 4, child: SizedBox()),
            ],
          ),
      ],
    );
  }
}

class _TableCell extends StatelessWidget {
  const _TableCell({required this.entries, required this.sel});
  final List<KanaEntry> entries; // 1 (single script) or 2 (Both: hiragana, katakana)
  final _Selection sel;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final both = entries.length > 1;
    final romaji = entries.first.romaji;

    // Study status = the furthest-along state among this cell's glyphs.
    int? maxState;
    for (final e in entries) {
      final s = sel.states[e.char];
      if (s != null && (maxState == null || s > maxState)) maxState = s;
    }
    final mark = studyMarkFor(maxState);

    final picked = sel.active && entries.map((e) => e.char).every(sel.contains);

    return Material(
      color: picked ? jc.brandSoft : jc.surface,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.sm),
        onTap: sel.active ? () => sel.onToggle(entries) : () => context.push('/kana/${entries.first.char}'),
        child: Stack(
          children: [
            Container(
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.sm),
                border: Border.all(color: picked ? jc.brand : jc.hairline, width: picked ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (both)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(entries[0].char, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 3),
                        Text(entries[1].char,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: jc.muted)),
                      ],
                    )
                  else
                    Text(entries.first.char, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w600)),
                  Text(romaji, style: TextStyle(fontSize: 9, color: jc.muted, height: 1)),
                ],
              ),
            ),
            // A small status dot; selection itself reads from the border + tint.
            if (mark != StudyMark.none) Positioned(top: 4, right: 4, child: StudyDot(mark: mark)),
          ],
        ),
      ),
    );
  }
}
