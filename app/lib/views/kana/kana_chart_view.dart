import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/breakpoints.dart';
import '../../l10n/l10n.dart';
import '../../models/enums.dart';
import '../../models/kana.dart';
import '../../repositories/dictionary_repository.dart';
import '../../repositories/study_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/app_state.dart';
import '../../viewmodels/kana_viewmodel.dart';
import '../learn/learn_carousel_view.dart';
import '../auth/auth_required_sheet.dart';
import '../widgets/neo_pop.dart';
import '../widgets/pressable.dart';
import '../widgets/selection_action_bar.dart';
import '../widgets/status_views.dart';
import '../widgets/study_mark.dart';
import 'kana_cell.dart';
import 'kana_detail_view.dart';

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

class _Selection {
  const _Selection({
    required this.active,
    required this.chars,
    required this.states,
    required this.dueChars,
    required this.onToggle,
  });

  final bool active;
  final Set<String> chars;
  final Map<String, int> states;
  final Set<String> dueChars;
  final void Function(List<KanaEntry> entries) onToggle;

  bool contains(String char) => chars.contains(char);
  bool isDue(String char) => dueChars.contains(char);
}

class _KanaChart extends StatefulWidget {
  const _KanaChart();

  @override
  State<_KanaChart> createState() => _KanaChartState();
}

class _KanaChartState extends State<_KanaChart> {
  static const _extras = {
    'dakuten': 'Dakuten ゛',
    'handakuten': 'Handakuten ゜',
    'yoon': 'Yōon',
  };

  bool _selecting = false;
  bool _busy = false;
  String? _focusedChar;
  final Set<String> _selected = {};
  Map<String, int> _states = const {};
  Set<String> _dueChars = const {};

  @override
  void initState() {
    super.initState();
    _loadStates();
  }

  void _changeScript(KanaViewModel vm, String script) {
    if (script == vm.script) return;
    setState(() {
      _selected.clear();
      _focusedChar = null;
    });
    vm.setScript(script);
  }

  void _focusKana(String char) {
    if (_focusedChar != char) setState(() => _focusedChar = char);
  }

  Future<void> _loadStates() async {
    try {
      final repository = context.read<StudyRepository>();
      final statesFuture = repository.studyStates(type: ItemType.kana);
      final cardsFuture = repository.cards(type: ItemType.kana);
      final states = await statesFuture;
      final cards = await cardsFuture;
      final now = DateTime.now();
      final due = {
        for (final card in cards)
          if (!card.isNew && !card.due.isAfter(now)) card.itemRef,
      };
      if (mounted) {
        setState(() {
          _states = states;
          _dueChars = due;
        });
      }
    } catch (_) {
      // Study state is supplementary. The reference chart stays available.
    }
  }

  void _toggleCell(List<KanaEntry> entries) {
    setState(() {
      final chars = entries.map((entry) => entry.char);
      final allSelected = chars.every(_selected.contains);
      for (final char in chars) {
        allSelected ? _selected.remove(char) : _selected.add(char);
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
    setState(() => _selected.addAll(vm.current.map((entry) => entry.char)));
  }

  Future<void> _bulk(bool known) async {
    if (_selected.isEmpty || _busy) return;
    Haptics.medium();
    setState(() => _busy = true);
    final items = [
      for (final char in _selected) (type: ItemType.kana, ref: char),
    ];
    try {
      final summary = await context.read<StudyRepository>().bulkAdd(
            items,
            known: known,
          );
      if (!mounted) return;
      await _loadStates();
      if (!mounted) return;
      final count = summary['resolved'] ?? items.length;
      setState(() {
        _selecting = false;
        _selected.clear();
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            known ? 'Marked $count as known' : 'Added $count to study',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.trText('Could not update your deck')),
        ),
      );
    }
  }

  void _openMnemonics(KanaViewModel vm) {
    final language = context.read<AppState>().mnemonicLanguage;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearnCarouselView(
          items: vm.current,
          language: language,
          title: switch (vm.script) {
            'hiragana' => 'Hiragana',
            'katakana' => 'Katakana',
            _ => 'Kana',
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<KanaViewModel>();
    final selection = _Selection(
      active: _selecting,
      chars: _selected,
      states: _states,
      dueChars: _dueChars,
      onToggle: _toggleCell,
    );

    return Scaffold(
      bottomNavigationBar: _selecting
          ? SelectionActionBar(
              count: _selected.length,
              busy: _busy,
              onKnown: () => _bulk(true),
              onAdd: () => _bulk(false),
            )
          : null,
      body: SafeArea(
        child: vm.isLoading
            ? const _KanaLoadingSkeleton()
            : vm.hasError
                ? ErrorRetry(message: vm.error!, onRetry: vm.load)
                : AnimatedSwitcher(
                    duration: Motion.timed(context, Motion.fast),
                    switchInCurve: Motion.out,
                    switchOutCurve: Motion.out,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: _KanaLayout(
                      key: ValueKey(vm.script),
                      vm: vm,
                      selection: selection,
                      selecting: _selecting,
                      selectedCount: _selected.length,
                      extras: _extras,
                      onScriptChanged: (script) => _changeScript(vm, script),
                      onSelect: _enterSelect,
                      onCancelSelection: _exitSelect,
                      onSelectAll: () => _selectAllVisible(vm),
                      onMnemonics: () => _openMnemonics(vm),
                      focusedChar: _focusedChar,
                      onFocused: _focusKana,
                    ),
                  ),
      ),
    );
  }
}

class _KanaLayout extends StatelessWidget {
  const _KanaLayout({
    super.key,
    required this.vm,
    required this.selection,
    required this.selecting,
    required this.selectedCount,
    required this.extras,
    required this.onScriptChanged,
    required this.onSelect,
    required this.onCancelSelection,
    required this.onSelectAll,
    required this.onMnemonics,
    required this.focusedChar,
    required this.onFocused,
  });

  final KanaViewModel vm;
  final _Selection selection;
  final bool selecting;
  final int selectedCount;
  final Map<String, String> extras;
  final ValueChanged<String> onScriptChanged;
  final VoidCallback onSelect;
  final VoidCallback onCancelSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onMnemonics;
  final String? focusedChar;
  final ValueChanged<String> onFocused;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width >= Breakpoints.expanded) {
      final basic = vm.byKind('gojuon');
      if (basic.isEmpty) {
        return EmptyHint(
          icon: Icons.grid_off_rounded,
          title: _copy(
            context,
            'No basic kana in this content pack.',
            'Aucun kana de base dans ce pack de contenu.',
          ),
        );
      }
      final resolvedFocus = basic.any((entry) => entry.char == focusedChar)
          ? focusedChar!
          : basic.first.char;
      return _KanaTabletWorkspace(
        vm: vm,
        selection: selection,
        focusedChar: resolvedFocus,
        onFocused: onFocused,
        onScriptChanged: onScriptChanged,
      );
    }
    return BoundedContent(
      maxWidth: context.isExpanded ? 940 : 560,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tablet = constraints.maxWidth >= 760;
          if (!tablet) {
            return ListView(
              padding: const EdgeInsets.only(top: 12, bottom: 28),
              children: [
                _KanaPrimary(
                  vm: vm,
                  selection: selection,
                  selecting: selecting,
                  selectedCount: selectedCount,
                  onScriptChanged: onScriptChanged,
                  onCancelSelection: onCancelSelection,
                  onSelectAll: onSelectAll,
                ),
                _KanaTools(
                  selecting: selecting,
                  onSelect: onSelect,
                  onCancelSelection: onCancelSelection,
                  onMnemonics: onMnemonics,
                ),
                _KanaExtras(
                  vm: vm,
                  selection: selection,
                  extras: extras,
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 410,
                    child: _KanaPrimary(
                      vm: vm,
                      selection: selection,
                      selecting: selecting,
                      selectedCount: selectedCount,
                      onScriptChanged: onScriptChanged,
                      onCancelSelection: onCancelSelection,
                      onSelectAll: onSelectAll,
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Column(
                      children: [
                        NeoCard(
                          tone: NeoTone.lavender,
                          shadow: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _copy(context, 'Kana studio', 'Studio kana'),
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _copy(
                                  context,
                                  'Open a glyph for its sound, origin and community mnemonics.',
                                  'Ouvrez un glyphe pour son son, son origine et les mnémos de la communauté.',
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _KanaTools(
                          selecting: selecting,
                          onSelect: onSelect,
                          onCancelSelection: onCancelSelection,
                          onMnemonics: onMnemonics,
                        ),
                        _KanaExtras(
                          vm: vm,
                          selection: selection,
                          extras: extras,
                          inset: 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KanaTabletWorkspace extends StatelessWidget {
  const _KanaTabletWorkspace({
    required this.vm,
    required this.selection,
    required this.focusedChar,
    required this.onFocused,
    required this.onScriptChanged,
  });

  final KanaViewModel vm;
  final _Selection selection;
  final String focusedChar;
  final ValueChanged<String> onFocused;
  final ValueChanged<String> onScriptChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 524,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: context.jc.ink, width: 3)),
          ),
          child: Column(
            children: [
              _KanaHeader(
                vm: vm,
                selection: selection,
                onScriptChanged: onScriptChanged,
                inset: 0,
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 2, 4, 6),
                    child: _KanaMatrix(
                      items: vm.byKind('gojuon'),
                      selection: selection,
                      focusedChar: focusedChar,
                      onOpen: (entry) => onFocused(entry.char),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.timed(context, Motion.base),
            switchInCurve: Motion.outStrong,
            switchOutCurve: Motion.out,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(.025, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KanaDetailPane(
              key: ValueKey(focusedChar),
              char: focusedChar,
              onSelectKana: onFocused,
            ),
          ),
        ),
      ],
    );
  }
}

class _KanaPrimary extends StatelessWidget {
  const _KanaPrimary({
    required this.vm,
    required this.selection,
    required this.selecting,
    required this.selectedCount,
    required this.onScriptChanged,
    required this.onCancelSelection,
    required this.onSelectAll,
  });

  final KanaViewModel vm;
  final _Selection selection;
  final bool selecting;
  final int selectedCount;
  final ValueChanged<String> onScriptChanged;
  final VoidCallback onCancelSelection;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _KanaHeader(
          vm: vm,
          selection: selection,
          onScriptChanged: onScriptChanged,
        ),
        if (selecting)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _copy(
                      context,
                      '$selectedCount selected',
                      '$selectedCount sélectionnés',
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onSelectAll,
                  child:
                      Text(_copy(context, 'Select all', 'Tout sélectionner')),
                ),
                IconButton(
                  tooltip: _copy(context, 'Cancel', 'Annuler'),
                  onPressed: onCancelSelection,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 0),
          child: _KanaMatrix(
            items: vm.byKind('gojuon'),
            selection: selection,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
          child: _ReviewKanaButton(
            onTap: () => context.push('/session'),
          ),
        ),
      ],
    );
  }
}

class _KanaHeader extends StatelessWidget {
  const _KanaHeader({
    required this.vm,
    required this.selection,
    required this.onScriptChanged,
    this.inset = 14,
  });

  final KanaViewModel vm;
  final _Selection selection;
  final ValueChanged<String> onScriptChanged;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final learned = vm.current
        .where((entry) => (selection.states[entry.char] ?? -1) >= 2)
        .length;
    final total = vm.current.length;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: NeoSegmentedControl<String>(
                  selected: vm.script,
                  onChanged: onScriptChanged,
                  segments: [
                    const NeoSegment('hiragana', 'ひらがな'),
                    const NeoSegment('katakana', 'カタカナ'),
                    NeoSegment('both', _copy(context, 'Both', 'Les deux')),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$learned/$total',
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 21,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _copy(context, 'learned', 'apprises'),
                      style: const TextStyle(
                        fontSize: 11.5,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 11,
            runSpacing: 7,
            children: [
              _LegendItem(
                color: context.jc.lime,
                mark: '✓',
                label: _copy(context, 'learned', 'apprise'),
              ),
              _LegendItem(
                color: context.jc.acid,
                mark: '●',
                label: _copy(context, 'in progress', 'en cours'),
              ),
              _LegendItem(
                color: context.jc.magenta,
                mark: _copy(context, 'due', 'dû'),
                label: _copy(context, 'to review', 'à revoir'),
              ),
              _LegendItem(
                color: context.jc.surface,
                label: _copy(context, 'new', 'nouvelle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.mark = ''});

  final Color color;
  final String label;
  final String mark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 17,
          height: 17,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: context.jc.ink, width: 2),
            borderRadius: BorderRadius.circular(5),
          ),
          child: mark.isEmpty
              ? null
              : Text(
                  mark,
                  style: TextStyle(
                    fontSize: mark.length > 1 ? 6.5 : 8.5,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _KanaTools extends StatelessWidget {
  const _KanaTools({
    required this.selecting,
    required this.onSelect,
    required this.onCancelSelection,
    required this.onMnemonics,
  });

  final bool selecting;
  final VoidCallback onSelect;
  final VoidCallback onCancelSelection;
  final VoidCallback onMnemonics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          Expanded(
            child: _KanaToolButton(
              icon: selecting ? Icons.close_rounded : Icons.checklist_rounded,
              label: selecting
                  ? _copy(context, 'Cancel', 'Annuler')
                  : _copy(context, 'Select', 'Sélectionner'),
              onTap: selecting ? onCancelSelection : onSelect,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _KanaToolButton(
              icon: Icons.auto_stories_outlined,
              label: _copy(context, 'Mnemonics', 'Mnémos'),
              onTap: onMnemonics,
            ),
          ),
        ],
      ),
    );
  }
}

class _KanaToolButton extends StatelessWidget {
  const _KanaToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final signedIn = context.watch<AppState>().isAuthenticated;
    return Pressable(
      onTap: () {
        if (signedIn) {
          onTap();
        } else {
          showAuthRequiredSheet(
            context,
            title: _copy(context, 'Review your kana', 'Réviser vos kana'),
          );
        }
      },
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: context.jc.surface,
          border: Border.all(color: context.jc.ink, width: 2.5),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanaExtras extends StatelessWidget {
  const _KanaExtras({
    required this.vm,
    required this.selection,
    required this.extras,
    this.inset = 14,
  });

  final KanaViewModel vm;
  final _Selection selection;
  final Map<String, String> extras;
  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final extra in extras.entries)
            if (vm.byKind(extra.key).isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                extra.value,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              _KanaMatrix(
                items: vm.byKind(extra.key),
                selection: selection,
              ),
            ],
        ],
      ),
    );
  }
}

class _ReviewKanaButton extends StatelessWidget {
  const _ReviewKanaButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: context.jc.ink,
          border: Border.all(color: context.jc.ink, width: 3),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: context.jc.ink,
              blurRadius: 0,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _copy(context, 'Review due kana', 'Réviser les kana dues'),
              style: TextStyle(
                color: context.jc.acid,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.play_arrow_rounded, color: context.jc.acid, size: 21),
          ],
        ),
      ),
    );
  }
}

class _KanaMatrix extends StatelessWidget {
  const _KanaMatrix({
    required this.items,
    required this.selection,
    this.focusedChar,
    this.onOpen,
  });

  final List<KanaEntry> items;
  final _Selection selection;
  final String? focusedChar;
  final ValueChanged<KanaEntry>? onOpen;

  static const _vowels = ['a', 'i', 'u', 'e', 'o'];

  String _vowelOf(String romaji) {
    if (romaji.isEmpty) return '';
    final last = romaji[romaji.length - 1];
    return _vowels.contains(last) ? last : '';
  }

  @override
  Widget build(BuildContext context) {
    final byKey = <String, List<KanaEntry>>{};
    final noVowel = <KanaEntry>[];
    final rowOrder = <String, int>{};

    for (final kana in items) {
      final vowel = _vowelOf(kana.romaji);
      if (vowel.isEmpty) {
        noVowel.add(kana);
        continue;
      }
      (byKey['${kana.row}$vowel'] ??= []).add(kana);
      final currentOrder = rowOrder[kana.row];
      if (currentOrder == null || kana.order < currentOrder) {
        rowOrder[kana.row] = kana.order;
      }
    }

    for (final entries in byKey.values) {
      entries.sort(
        (a, b) => (a.isHiragana ? 0 : 1).compareTo(b.isHiragana ? 0 : 1),
      );
    }
    noVowel.sort(
      (a, b) => (a.isHiragana ? 0 : 1).compareTo(b.isHiragana ? 0 : 1),
    );
    final rows = rowOrder.keys.toList()
      ..sort((a, b) => rowOrder[a]!.compareTo(rowOrder[b]!));
    final slots = <List<KanaEntry>?>[
      for (final row in rows)
        for (final vowel in _vowels) byKey['$row$vowel'],
      if (noVowel.isNotEmpty) noVowel,
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        mainAxisExtent: 56,
      ),
      itemBuilder: (context, index) {
        final entries = slots[index];
        if (entries == null || entries.isEmpty) return const _KanaVoidCell();

        final selected = selection.active &&
            entries.map((entry) => entry.char).every(selection.contains);
        int? furthestState;
        var due = false;
        for (final entry in entries) {
          final state = selection.states[entry.char];
          if (state != null &&
              (furthestState == null || state > furthestState)) {
            furthestState = state;
          }
          due = due || selection.isDue(entry.char);
        }
        return KanaCell(
          entries: entries,
          selected: selected,
          focused: entries.any((entry) => entry.char == focusedChar),
          mark: studyMarkFor(furthestState),
          due: due,
          onTap: selection.active
              ? () => selection.onToggle(entries)
              : onOpen == null
                  ? () => context.push('/kana/${entries.first.char}')
                  : () => onOpen!(entries.first),
        );
      },
    );
  }
}

class _KanaVoidCell extends StatelessWidget {
  const _KanaVoidCell();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRoundedBorderPainter(color: context.jc.muted),
      child: const SizedBox.expand(),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  const _DashedRoundedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(10),
        ),
      );
    final paint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, (distance + 5).clamp(0, metric.length)),
          paint,
        );
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRoundedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _KanaLoadingSkeleton extends StatelessWidget {
  const _KanaLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return BoundedContent(
      maxWidth: 420,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          Row(
            children: [
              const Expanded(child: _SkeletonBox(height: 56)),
              const SizedBox(width: 10),
              _SkeletonBox(width: 62, height: 40, color: context.jc.surfaceAlt),
            ],
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 9,
            runSpacing: 7,
            children: [
              _SkeletonBox(width: 72, height: 17),
              _SkeletonBox(width: 78, height: 17),
              _SkeletonBox(width: 72, height: 17),
              _SkeletonBox(width: 68, height: 17),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 46,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              mainAxisExtent: 56,
            ),
            itemBuilder: (_, index) => _SkeletonBox(
              height: 56,
              color: index < 22
                  ? context.jc.lime.withValues(alpha: 0.38)
                  : context.jc.surfaceAlt,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.width, required this.height, this.color});

  final double? width;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color ?? context.jc.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.jc.ink.withValues(alpha: 0.28),
          width: 2,
        ),
      ),
    );
  }
}

String _copy(BuildContext context, String english, String french) =>
    Localizations.localeOf(context).languageCode == 'fr' ? french : english;
