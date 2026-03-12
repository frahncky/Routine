import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  CustomAppBar({super.key, this.onProfileTap});

  final VoidCallback? onProfileTap;

  Future<Map<String, String?>> _buscarDadosUsuario() async {
    final local = await DB.instance.getUser();
    if (local != null) {
      return {
        'name': local['name'] ?? 'Sem nome',
        'avatarUrl': local['avatarUrl'],
      };
    }
    // Se não tiver no local, busca no FirebaseAuth
    // e retorna o nome e a URL do avatar
    // Se não tiver no FirebaseAuth, retorna 'Sem nome' e null
    // para o avatarUrl
    // Isso é útil para mostrar o nome e o avatar do usuário
    // mesmo que ele não tenha feito login ainda
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario != null) {
      return {
        'name': usuario.displayName ?? 'Sem nome',
        'avatarUrl': usuario.photoURL,
      };
    }

    return {'name': 'Sem nome', 'avatarUrl': null};
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: mergedChange,
      builder: (context, _, __) {
        return FutureBuilder<Map<String, String?>>(
          key: ValueKey(mergedChange.value), // força reconstrução do FutureBuilder
          future: _buscarDadosUsuario(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return AppBar(
                title: Row(
                  children: [
                    CircleAvatar(radius: 20),
                    SizedBox(width: 12),
                    Expanded(child: CircularProgressIndicator()),
                  ],
                ),
              );
            }

            if (snapshot.hasError) {
              return AppBar(
                title: Row(
                  children: [
                    CircleAvatar(radius: 20),
                    SizedBox(width: 12),
                    Expanded(child: Text("Erro ao carregar dados")),
                  ],
                ),
              );
            }

            final nome = snapshot.data?['name']?.trim() ?? 'Sem nome';
            final primeiroNome =
                nome.isNotEmpty ? nome.split(' ').first : 'Sem nome';
            final profileImageUrl = snapshot.data?['avatarUrl'];

            return AppBar(
              toolbarHeight: 72,
              title: GestureDetector(
                onTap: onProfileTap,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: profileImageUrl != null &&
                              profileImageUrl.isNotEmpty &&
                              File(profileImageUrl).existsSync()
                          ? FileImage(File(profileImageUrl))
                          : null,
                      child: profileImageUrl == null || profileImageUrl.isEmpty
                          ?  Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                     SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        primeiroNome,
                        style:  TextStyle(
                          fontSize: 20,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ValueListenableBuilder<bool>(
                  valueListenable: notificacoesAtivasNotifier,
                  builder: (context, notificacoesAtivas, _) {
                    return IconButton(
                      icon: Icon(
                        notificacoesAtivas ? Icons.notifications_active : Icons.notifications_off,
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
  Size get preferredSize =>  Size.fromHeight(72);
}