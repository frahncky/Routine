import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/widgets/profile_avatar.dart';

class CustomAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key, this.onProfileTap});

  static const double toolbarHeight = 68;

  final VoidCallback? onProfileTap;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final profile = ref.watch(userProfileProvider);
    final notificacoesAtivas = ref.watch(notificationsActiveProvider);
    final nome = profile.name.trim().isEmpty ? 'Sem nome' : profile.name;

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
      title: GestureDetector(
        onTap: onProfileTap,
        child: Row(
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
              child: Text(
                nome,
                key: const Key('appbar_profile_name'),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 20),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8),
          // Indicador puramente visual (não um botão): não há ação de
          // notificações "abrir" a partir daqui hoje — controle fica em
          // Configurações. Um IconButton com onPressed vazio pareceria
          // clicável sem fazer nada, então isso é deliberadamente estático.
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              notificacoesAtivas
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              size: 22,
              color: scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
