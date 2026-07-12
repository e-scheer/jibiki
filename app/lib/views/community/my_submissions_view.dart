import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:jibiki/l10n/l10n.dart';
import 'package:provider/provider.dart';

import '../../core/languages.dart';
import '../../models/mnemonic.dart';
import '../../repositories/mnemonic_repository.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/my_submissions_viewmodel.dart';
import '../../viewmodels/app_state.dart';
import '../auth/auth_required_sheet.dart';
import '../widgets/neo_pop.dart';
import '../widgets/net_image.dart';
import '../widgets/status_views.dart';

/// The user's drawings, moderation status and a shortcut to owned packs.
class MySubmissionsView extends StatelessWidget {
  const MySubmissionsView({super.key});

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AppState>().isAuthenticated) {
      return Scaffold(
        body: Column(
          children: [
            NeoPageHeader(
              title: context.trText('My submissions'),
              subtitle: context.trText('Your drawings and review status.'),
              tone: NeoTone.magenta,
              leading: NeoIconButton(
                icon: Icons.arrow_back_rounded,
                label: context.trText('Back'),
                onTap: () => context.pop(),
              ),
            ),
            Expanded(
              child: AuthRequiredPanel(
                title: context.trText('Sign in to see your drawings'),
                description: context.trText(
                  'Your submissions, packs and moderation updates stay together on your account.',
                ),
                icon: Icons.brush_outlined,
              ),
            ),
          ],
        ),
      );
    }
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
      body: Column(
        children: [
          NeoPageHeader(
            title: context.trText('My submissions'),
            subtitle: context.trText(
              'Your drawings, their review status and the packs you build.',
            ),
            tone: NeoTone.magenta,
            leading: NeoIconButton(
              icon: Icons.arrow_back,
              label: context.trText('Back'),
              onTap: () => context.pop(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: jc.brand,
              backgroundColor: jc.acid,
              onRefresh: vm.load,
              child: vm.hasError
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        ErrorRetry(message: vm.error!, onRetry: vm.load),
                      ],
                    )
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        NeoContent(
                          maxWidth: 760,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              NeoListRow(
                                tone: NeoTone.lavender,
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: jc.acid,
                                    borderRadius: BorderRadius.circular(9),
                                    border:
                                        Border.all(color: jc.ink, width: 2.5),
                                  ),
                                  child: const Icon(
                                    Icons.collections_bookmark_outlined,
                                    size: 22,
                                  ),
                                ),
                                title: Text(context.trText('My packs')),
                                subtitle: Text(context
                                    .trText('Drafts, in review and published')),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () =>
                                    context.push('/decks/community?tab=mine'),
                              ),
                              const SizedBox(height: 24),
                              NeoSectionTitle(
                                context.trText('Mnemonics you\'ve drawn'),
                                trailing: vm.items.isEmpty
                                    ? null
                                    : NeoBadge(
                                        '${vm.items.length}',
                                        tone: NeoTone.acid,
                                      ),
                              ),
                              Text(
                                context.trText(
                                  'Held submissions appear publicly once moderation approves them.',
                                ),
                                style: TextStyle(
                                  color: jc.body,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (vm.isLoading && vm.items.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: LoadingView(),
                                )
                              else if (vm.items.isEmpty)
                                const EmptyHint(
                                  icon: Icons.brush_outlined,
                                  title: 'Nothing yet',
                                  subtitle:
                                      'Open a kana or kanji and tap Draw to make your first mnemonic.',
                                )
                              else
                                ...vm.items.map(
                                  (mnemonic) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _SubmissionTile(
                                      mnemonic: mnemonic,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
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
    return NeoCard(
      tone: NeoTone.paper,
      padding: const EdgeInsets.all(10),
      semanticLabel: '${m.character} mnemonic',
      onTap: () => context.push(
        m.kind == 'kanji' ? '/kanji/${m.character}' : '/kana/${m.character}',
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: jc.lavender,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: jc.ink, width: 2.5),
            ),
            child: m.hasImage
                ? NetImage(
                    url: m.imageUrl,
                    cacheWidth: 150,
                    semanticLabel: 'Mnemonic drawing for ${m.character}',
                  )
                : Center(
                    child: Text(
                      m.character,
                      style: TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: jc.ink,
                      ),
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
                    '${m.character} · ${mnemonicLanguageName(m.language)}',
                  ),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  m.story,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: jc.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _StatusChip(status: m.status),
        ],
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
      'visible' => ('Published', jc.lime),
      'pending' => ('In review', jc.acid),
      'hidden' => ('Hidden', jc.coral),
      _ => ('Removed', jc.lavender),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: jc.ink, width: 2),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: jc.ink,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
