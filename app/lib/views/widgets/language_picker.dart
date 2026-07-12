import 'package:flutter/material.dart';
import 'package:jibiki/l10n/l10n.dart';

import '../../core/breakpoints.dart';
import '../../core/languages.dart';
import '../../theme/app_theme.dart';
import 'pressable.dart';

/// NeoPop language picker. Every ISO 639-1 language stays selectable so a
/// community can start contributing before a curated set exists.
Future<String?> showMnemonicLanguagePicker(
  BuildContext context,
  String current,
) {
  if (context.isWide) {
    return showDialog<String>(
      context: context,
      barrierColor: context.jc.ink.withValues(alpha: 0.52),
      builder: (ctx) => Dialog(
        elevation: 0,
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 720),
          child: _LanguageSheet(current: current, dialog: true),
        ),
      ),
    );
  }
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    barrierColor: context.jc.ink.withValues(alpha: 0.52),
    builder: (ctx) => _LanguageSheet(current: current),
  );
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet({required this.current, this.dialog = false});

  final String current;
  final bool dialog;

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  String _query = '';
  final ScrollController _scrollController = ScrollController();
  bool _fadeTop = false;
  bool _fadeBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_syncFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFades());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_syncFades)
      ..dispose();
    super.dispose();
  }

  void _syncFades() {
    if (!_scrollController.hasClients || !mounted) return;
    final position = _scrollController.position;
    final top = position.pixels > 2;
    final bottom = position.pixels < position.maxScrollExtent - 2;
    if (top != _fadeTop || bottom != _fadeBottom) {
      setState(() {
        _fadeTop = top;
        _fadeBottom = bottom;
      });
    }
  }

  void _setQuery(String value) {
    setState(() => _query = value);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
      _syncFades();
    });
  }

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final media = MediaQuery.of(context);
    final query = _query.trim().toLowerCase();
    final all = allMnemonicLanguages;
    final featured = featuredMnemonicLanguages;
    final filtered = query.isEmpty
        ? null
        : [
            for (final language in all)
              if (language.nativeName.toLowerCase().contains(query) ||
                  language.code.contains(query))
                language,
          ];

    return AnimatedPadding(
      duration: Motion.timed(context, Motion.base),
      curve: Motion.out,
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: widget.dialog,
        child: SizedBox(
          height: media.size.height * (widget.dialog ? 0.82 : 0.88),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: jc.canvas,
              borderRadius: widget.dialog
                  ? BorderRadius.circular(24)
                  : const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: jc.ink, width: 3),
            ),
            child: Column(
              children: [
                _SheetHeader(
                  showHandle: !widget.dialog,
                  onQueryChanged: _setQuery,
                ),
                Expanded(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        _fadeTop ? Colors.transparent : Colors.black,
                        Colors.black,
                        Colors.black,
                        _fadeBottom ? Colors.transparent : Colors.black,
                      ],
                      stops: [0, .035, .94, 1],
                    ).createShader(rect),
                    child: ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      children: [
                        if (filtered == null) ...[
                          _SectionSticker(label: context.trText('Featured')),
                          const SizedBox(height: 10),
                          for (final language in featured) ...[
                            _LanguageRow(
                              language: language,
                              selected: language.code == widget.current,
                            ),
                            const SizedBox(height: 8),
                          ],
                          const SizedBox(height: 10),
                          _SectionSticker(
                              label: context.trText('All languages')),
                          const SizedBox(height: 10),
                          for (final language in all)
                            if (!featured.any((featured) =>
                                featured.code == language.code)) ...[
                              _LanguageRow(
                                language: language,
                                selected: language.code == widget.current,
                              ),
                              const SizedBox(height: 8),
                            ],
                        ] else if (filtered.isEmpty)
                          _NoMatch(query: _query)
                        else
                          for (final language in filtered) ...[
                            _LanguageRow(
                              language: language,
                              selected: language.code == widget.current,
                            ),
                            const SizedBox(height: 8),
                          ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.onQueryChanged,
    required this.showHandle,
  });

  final ValueChanged<String> onQueryChanged;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: jc.magenta,
        border: Border(bottom: BorderSide(color: jc.ink, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHandle) ...[
            Align(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: jc.ink,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            context.trText('Mnemonic language'),
            style: context.text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: jc.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.trText(
              'Mnemonics ride on sound. Pick the language that makes the hint click for you.',
            ),
            style: TextStyle(
              color: jc.ink,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: jc.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: jc.ink, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: jc.ink,
                  blurRadius: 0,
                  offset: const Offset(4, 4),
                ),
              ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: context.trText('Search languages...'),
                prefixIcon: const Icon(Icons.search, size: 21),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onChanged: onQueryChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionSticker extends StatelessWidget {
  const _SectionSticker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: context.jc.acid,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: context.jc.ink, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: context.jc.ink,
              blurRadius: 0,
              offset: const Offset(3, 3),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
      );
}

class _LanguageRow extends StatelessWidget {
  const _LanguageRow({required this.language, required this.selected});

  final MnemonicLanguage language;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    return Pressable(
      label: language.nativeName,
      selected: selected,
      pressedScale: 1,
      onTap: () => Navigator.pop(context, language.code),
      child: AnimatedContainer(
        duration: Motion.timed(context, Motion.fast),
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? jc.acid : jc.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: jc.ink, width: 2.5),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: jc.ink,
                    blurRadius: 0,
                    offset: const Offset(3, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? jc.lime : jc.lavender,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: jc.ink, width: 2),
              ),
              child: Text(
                language.code.toUpperCase(),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    language.nativeName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (!language.seeded)
                    Text(
                      context.trText('No content yet, be the first!'),
                      style: TextStyle(
                        color: jc.body,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: jc.ink,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(Icons.check, size: 18, color: jc.acid),
              )
            else
              Text(
                language.code,
                style: TextStyle(
                  color: jc.body,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends StatelessWidget {
  const _NoMatch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: context.jc.lavender,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.jc.ink, width: 2.5),
        ),
        child: Text(
          context.trText('No language matches "$query".'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
}
