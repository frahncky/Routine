import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:routine/features/assinatura/assinatura_screen.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CustomAppBar({super.key, this.onProfileTap});

  final VoidCallback? onProfileTap;

  Future<Map<String, String?>> _buscarDadosUsuario() async {
    final local = await DB.instance.getUser();
    if (local != null) {
      return {
        'name': local['name']?.toString() ?? 'Sem nome',
        'avatarUrl': local['avatarUrl']?.toString(),
        'typeAccount': local['typeAccount']?.toString(),
      };
    }

    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario != null) {
      return {
        'name': usuario.displayName ?? 'Sem nome',
        'avatarUrl': usuario.photoURL,
        'typeAccount': PlanRules.gratis,
      };
    }

    return {
      'name': 'Sem nome',
      'avatarUrl': null,
      'typeAccount': PlanRules.gratis,
    };
  }

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

  ({Color bg, Color border, IconData icon}) _planVisual(String plan) {
    final normalized = PlanRules.normalize(plan);
    if (normalized == PlanRules.premium) {
      return (
        bg: const Color(0xFFDFFCF2),
        border: const Color(0xFF10B981),
        icon: Icons.workspace_premium
      );
    }
    if (normalized == PlanRules.basico) {
      return (
        bg: const Color(0xFFE6F0FF),
        border: const Color(0xFF3B82F6),
        icon: Icons.star_rounded
      );
    }
    return (
      bg: const Color(0xFFFFF2E2),
      border: const Color(0xFFF59E0B),
      icon: Icons.campaign_outlined
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<int>(
      valueListenable: mergedChange,
      builder: (context, _, __) {
        return FutureBuilder<Map<String, String?>>(
          key: ValueKey(mergedChange.value),
          future: _buscarDadosUsuario(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AppBar(
                toolbarHeight: 84,
                title: const LinearProgressIndicator(minHeight: 4),
              );
            }

            if (snapshot.hasError) {
              return AppBar(
                toolbarHeight: 84,
                title: const Text('Erro ao carregar dados'),
              );
            }

            final nome = snapshot.data?['name']?.trim() ?? 'Sem nome';
            final primeiroNome =
                nome.isNotEmpty ? nome.split(' ').first : 'Sem nome';
            final avatarProvider = _resolveAvatar(snapshot.data?['avatarUrl']);
            final currentPlan =
                PlanRules.normalize(snapshot.data?['typeAccount']?.toString());
            final planVisual = _planVisual(currentPlan);

            return AppBar(
              toolbarHeight: 84,
              flexibleSpace: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFFE8F1FF),
                      scheme.surface,
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                        color: scheme.primary.withValues(alpha: 0.12)),
                  ),
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
                        radius: 21,
                        backgroundImage: avatarProvider,
                        backgroundColor: Colors.white,
                        child: avatarProvider == null
                            ? Icon(Icons.person, color: scheme.primary)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bem-vindo',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                  color:
                                      scheme.onSurface.withValues(alpha: 0.64),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          Text(
                            primeiroNome,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontSize: 22,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AssinaturaScreen(),
                        ),
                      );
                      mergedChange.markChanged();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: planVisual.bg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: planVisual.border),
                      ),
                      child: Row(
                        children: [
                          Icon(planVisual.icon,
                              size: 16, color: planVisual.border),
                          const SizedBox(width: 4),
                          Text(
                            PlanRules.displayName(currentPlan),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
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
      },
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(84);
}
