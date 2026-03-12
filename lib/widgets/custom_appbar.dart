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

  Color _planBgColor(String plan) {
    final normalized = PlanRules.normalize(plan);
    if (normalized == PlanRules.premium) return const Color(0xFFD1FAE5);
    if (normalized == PlanRules.basico) return const Color(0xFFDBEAFE);
    return const Color(0xFFFFEDD5);
  }

  Color _planBorderColor(String plan) {
    final normalized = PlanRules.normalize(plan);
    if (normalized == PlanRules.premium) return const Color(0xFF34D399);
    if (normalized == PlanRules.basico) return const Color(0xFF60A5FA);
    return const Color(0xFFF59E0B);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: mergedChange,
      builder: (context, _, __) {
        return FutureBuilder<Map<String, String?>>(
          key: ValueKey(mergedChange.value),
          future: _buscarDadosUsuario(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AppBar(
                title: Row(
                  children: const [
                    CircleAvatar(radius: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(minHeight: 4),
                    ),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return AppBar(
                title: const Row(
                  children: [
                    CircleAvatar(radius: 20),
                    SizedBox(width: 12),
                    Expanded(child: Text('Erro ao carregar dados')),
                  ],
                ),
              );
            }

            final nome = snapshot.data?['name']?.trim() ?? 'Sem nome';
            final primeiroNome =
                nome.isNotEmpty ? nome.split(' ').first : 'Sem nome';
            final avatarUrl = snapshot.data?['avatarUrl'];
            final avatarProvider = _resolveAvatar(avatarUrl);
            final currentPlan =
                PlanRules.normalize(snapshot.data?['typeAccount']?.toString());

            return AppBar(
              toolbarHeight: 72,
              title: GestureDetector(
                onTap: onProfileTap,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: avatarProvider,
                      child: avatarProvider == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        primeiroNome,
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _planBgColor(currentPlan),
                        borderRadius: BorderRadius.circular(999),
                        border:
                            Border.all(color: _planBorderColor(currentPlan)),
                      ),
                      child: Text(
                        PlanRules.displayName(currentPlan),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ValueListenableBuilder<bool>(
                  valueListenable: notificacoesAtivasNotifier,
                  builder: (context, notificacoesAtivas, _) {
                    return IconButton(
                      icon: Icon(
                        notificacoesAtivas
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        size: 25,
                        color: notificacoesAtivas ? Colors.blue : Colors.grey,
                      ),
                      onPressed: () {},
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
  Size get preferredSize => const Size.fromHeight(72);
}
