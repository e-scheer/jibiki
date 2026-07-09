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
import 'kana_cell.dart';

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

  void _changeScript(KanaViewModel vm, String s) {
    if (s == vm.script) return;
    setState(() => _selected.clear());
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
      // No study state (e.g. offline) just means no badges - never block the chart.
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
                    tooltip: 'Select kana',
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
                  duration: Motion.timed(context, Motion.fast),
                  switchInCurve: Motion.out,
                  switchOutCurve: Motion.out,
                  // A clean, quick crossfade between scripts. The three matrices
                  // share the same rows, so heights match and nothing jumps - no
                  // more half-sliding matrices ghosting over each other.
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: ListView(
                    key: ValueKey(vm.script),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                    children: [
                      if (!_selecting)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Text(
                            'Tap the checklist to pick kana, then mark the ones you know or add the rest to learn.',
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

/// A flat pill toggle where the vermilion selection **slides** between segments
/// (a single moving pill) instead of snapping colour, so the active script reads
/// as one continuous control. Collapses to an instant move under reduce-motion.
class _ScriptToggle extends StatelessWidget {
  const _ScriptToggle({required this.script, required this.onChanged});
  final String script;
  final ValueChanged<String> onChanged;

  static const _opts = [
    (value: 'hiragana', label: 'Hiragana'),
    (value: 'katakana', label: 'Katakana'),
    (value: 'both', label: 'Both'),
  ];

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final index = _opts.indexWhere((o) => o.value == script).clamp(0, _opts.length - 1);
    // -1 (first) … +1 (last): the alignment the pill slides to.
    final x = -1.0 + index * (2.0 / (_opts.length - 1));

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: jc.surfaceAlt, borderRadius: BorderRadius.circular(Radii.md)),
      child: SizedBox(
        height: 34,
        child: Stack(
          children: [
            // The single pill that glides to the selected segment.
            AnimatedAlign(
              alignment: Alignment(x, 0),
              duration: Motion.timed(context, Motion.base),
              curve: Motion.outStrong,
              child: FractionallySizedBox(
                widthFactor: 1 / _opts.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(color: jc.brand, borderRadius: BorderRadius.circular(Radii.sm)),
                ),
              ),
            ),
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final o in _opts)
                    Expanded(
                      child: Pressable(
                        label: o.label,
                        selected: script == o.value,
                        haptic: false,
                        onTap: () {
                          Haptics.tick();
                          onChanged(o.value);
                        },
                        child: AnimatedDefaultTextStyle(
                          duration: Motion.timed(context, Motion.base),
                          curve: Motion.out,
                          style: TextStyle(
                            color: script == o.value ? Colors.white : jc.muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                          child: Center(child: Text(o.label)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
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

    Widget cell(List<KanaEntry>? entries) {
      if (entries == null || entries.isEmpty) {
        return const Expanded(child: Padding(padding: EdgeInsets.all(2.5), child: SizedBox(height: 56)));
      }
      final picked = sel.active && entries.map((e) => e.char).every(sel.contains);
      // Study status = the furthest-along state among this cell's glyphs.
      int? maxState;
      for (final e in entries) {
        final s = sel.states[e.char];
        if (s != null && (maxState == null || s > maxState)) maxState = s;
      }
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(2.5),
          child: KanaCell(
            entries: entries,
            selected: picked,
            mark: studyMarkFor(maxState),
            onTap: sel.active
                ? () => sel.onToggle(entries)
                : () => context.push('/kana/${entries.first.char}'),
          ),
        ),
      );
    }

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

