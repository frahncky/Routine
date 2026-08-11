import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/widgets/profile_avatar.dart';

class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CustomAppBar({
    super.key,
    this.onProfileTap,
    this.sectionTitle,
  });

  static const double toolbarHeight = 68;

  final VoidCallback? onProfileTap;
  final String? sectionTitle;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(userProfileProvider);
    final notificacoesAtivas = ref.watch(notificationsActiveProvider);
    final nome = profile.name.trim().isEmpty ? 'Sem nome' : profile.name;
    final isPt = Localizations.localeOf(context).languageCode == 'pt';
    final profileLabel = isPt ? 'Perfil: $nome' : 'Profile: $nome';
    final openProfileLabel =
        isPt ? 'Abrir perfil de $nome' : 'Open $nome profile';
    final headerLabel =
        sectionTitle == null ? profileLabel : '$sectionTitle. $profileLabel';
    final actionableHeaderLabel = sectionTitle == null
        ? openProfileLabel
        : '$sectionTitle. $openProfileLabel';
    final notificationsLabel = notificacoesAtivas
        ? (isPt
            ? 'Notificações ativas. Altere em Configurações.'
            : 'Notifications on. Change this in Settings.')
        : (isPt
            ? 'Notificações pausadas. Altere em Configurações.'
            : 'Notifications paused. Change this in Settings.');
    final notificationsStatus = notificacoesAtivas
        ? (isPt ? 'Ativas' : 'On')
        : (isPt ? 'Pausadas' : 'Paused');

    final profileContent = Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.22),
              width: 2,
            ),
          ),
          child: ProfileAvatar(
            key: const Key('appbar_profile_avatar'),
            avatarUrl: profile.avatarUrl,
            radius: 18,
            revision: profile.revision,
            backgroundColor: Colors.white,
            iconColor: scheme.primary,
            iconSize: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sectionTitle ?? nome,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              if (sectionTitle != null)
                Text(
                  nome,
                  key: const Key('appbar_profile_name'),
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                )
              else
                Offstage(
                  child: Text(
                    nome,
                    key: const Key('appbar_profile_name'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    final profileTitle = onProfileTap == null
        ? Semantics(
            container: true,
            header: true,
            label: headerLabel,
            child: ExcludeSemantics(child: profileContent),
          )
        : Semantics(
            container: true,
            button: true,
            label: actionableHeaderLabel,
            child: Tooltip(
              message: openProfileLabel,
              excludeFromSemantics: true,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: ExcludeSemantics(child: profileContent),
                  ),
                ),
              ),
            ),
          );

    return AppBar(
      toolbarHeight: CustomAppBar.toolbarHeight,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: scheme.primary.withValues(alpha: 0.12)),
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFFE8F1FF), scheme.surface],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.paddingOf(context).top,
              child: const ColoredBox(color: Color(0xFF0B3B66)),
            ),
          ],
        ),
      ),
      titleSpacing: 12,
      title: profileTitle,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Semantics(
            container: true,
            label: notificationsLabel,
            child: Tooltip(
              message: notificationsLabel,
              excludeFromSemantics: true,
              child: ExcludeSemantics(
                child: Container(
                  key: const Key('appbar_notifications_status'),
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: notificacoesAtivas
                        ? scheme.secondaryContainer
                        : scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        notificacoesAtivas
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        size: 18,
                        color: notificacoesAtivas
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        notificationsStatus,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: notificacoesAtivas
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
