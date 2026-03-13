import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:routine/main.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key, this.onProfileTap});

  static const double toolbarHeight = 68;

  final VoidCallback? onProfileTap;

  @override
  Size get preferredSize => const Size.fromHeight(toolbarHeight);

  ImageProvider<Object>? _resolveAvatar(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;

    final normalized = avatarUrl.toLowerCase();
    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return NetworkImage(avatarUrl);
    }

    final file = File(avatarUrl);
    if (file.existsSync()) {
      return FileImage(file);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<CurrentUserProfile>(
      valueListenable: currentUserProfileNotifier,
      builder: (context, profile, _) {
        final nome = profile.name.trim().isEmpty ? 'Sem nome' : profile.name;
        final primeiroNome =
            nome.isNotEmpty ? nome.split(' ').first : 'Sem nome';
        final avatarProvider = _resolveAvatar(profile.avatarUrl);

        return AppBar(
          toolbarHeight: CustomAppBar.toolbarHeight,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          flexibleSpace: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(color: scheme.primary.withValues(alpha: 0.12)),
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
                        colors: [
                          const Color(0xFFE8F1FF),
                          scheme.surface,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: MediaQuery.paddingOf(context).top,
                  child: const ColoredBox(
                    color: Color(0xFF0B3B66),
                  ),
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
                  child: CircleAvatar(
                    radius: 18,
                    backgroundImage: avatarProvider,
                    backgroundColor: Colors.white,
                    child: avatarProvider == null
                        ? Icon(Icons.person, color: scheme.primary)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    primeiroNome,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ValueListenableBuilder<bool>(
              valueListenable: notificacoesAtivasNotifier,
              builder: (context, notificacoesAtivas, _) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton.filledTonal(
                    icon: Icon(
                      notificacoesAtivas
                          ? Icons.notifications_active
                          : Icons.notifications_off,
                      size: 22,
                    ),
                    onPressed: () {},
                    color: scheme.primary,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
