import 'package:jibiki/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/languages.dart';
import '../../models/mnemonic.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/my_submissions_viewmodel.dart';
import '../widgets/net_image.dart';
import '../widgets/status_views.dart';

/// Everything the user has contributed: their individual mnemonic drawings (with
/// each one's moderation status) plus a shortcut to their packs.
class MySubmissionsView extends StatelessWidget {
  const MySubmissionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) =>
          MySubmissionsViewModel(ctx.read<MnemonicRepository>())..load(),
      child: const _MySubmissions(),
    );
  }
}

class _MySubmissions extends StatelessWidget {
  const _MySubmissions();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MySubmissionsViewModel>();
    final jc = context.jc;

    return Scaffold(
      appBar: AppBar(title: Text(context.trText('My submissions'))),
      body: RefreshIndicator(
        color: jc.brand,
        onRefresh: vm.load,
        child: vm.hasError
            ? ListView(
                children: [ErrorRetry(message: vm.error!, onRetry: vm.load)])
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.collections_bookmark_outlined,
                        color: jc.brand),
                    title: Text(context.trText('My packs')),
                    subtitle: Text(
                        context.trText('Drafts, in review and published'),
                        style: TextStyle(color: jc.muted, fontSize: 12.5)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/decks/community?tab=mine'),
                  ),
                  Divider(color: jc.hairline, height: 8),
                  const SizedBox(height: 8),
                  Text(context.trText('Mnemonics you\'ve drawn'),
                      style: context.text.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                      context.trText(
                          'Held submissions post once approved by moderation.'),
                      style: TextStyle(color: jc.muted, fontSize: 12.5)),
                  const SizedBox(height: 12),
                  if (vm.isLoading && vm.items.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()))
                  else if (vm.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: EmptyHint(
                        icon: Icons.brush_outlined,
                        title: 'Nothing yet',
                        subtitle:
                            'Open a kana or kanji and tap Draw to make your first mnemonic.',
                      ),
                    )
                  else
                    ...vm.items.map((m) => _SubmissionTile(mnemonic: m)),
                ],
              ),
      ),
    );
  }
}

class _SubmissionTile extends StatelessWidget {
  const _SubmissionTile({required this.mnemonic});
  final Mnemonic mnemonic;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final m = mnemonic;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: () => context.push(
          m.kind == 'kanji' ? '/kanji/${m.character}' : '/kana/${m.character}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.sm),
              child: SizedBox(
                width: 56,
                height: 56,
                child: m.hasImage
                    ? NetImage(
                        url: m.imageUrl,
                        cacheWidth: 150,
                        semanticLabel: 'Mnemonic drawing for ${m.character}')
                    : Container(
                        color: jc.surfaceAlt,
                        alignment: Alignment.center,
                        child: Text(m.character,
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: jc.brand)),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      context.trText(
                          '${m.character} · ${mnemonicLanguageName(m.language)}'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(m.story,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: jc.body, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _StatusChip(status: m.status),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final jc = context.jc;
    final (label, color) = switch (status) {
      'visible' => ('Published', jc.success),
      'pending' => ('In review', jc.warn),
      'hidden' => ('Hidden', jc.ratingAgain),
      _ => ('Removed', jc.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }
}
