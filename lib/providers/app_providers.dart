import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/models/user_profile.dart';

class UserProfileNotifier extends Notifier<UserProfile> {
  static const _guestName = 'Visitante';

  @override
  UserProfile build() => const UserProfile(
        name: _guestName,
        avatarUrl: null,
        revision: 0,
      );

  Future<void> refresh() async {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      state = UserProfile(name: _guestName, avatarUrl: null, revision: state.revision + 1);
      return;
    }

    final local = await DB.instance.getUser();
    if (local != null) {
      state = UserProfile(
        name: _normalizeName(local['name']?.toString()),
        avatarUrl: _normalizeAvatarUrl(local['avatarUrl']?.toString()),
        revision: state.revision + 1,
      );
      return;
    }

    state = UserProfile(
      name: _normalizeName(usuario.displayName),
      avatarUrl: _normalizeAvatarUrl(usuario.photoURL),
      revision: state.revision + 1,
    );
  }

  void updateProfile({required String name, required String? avatarUrl}) {
    state = UserProfile(
      name: name.trim().isEmpty ? 'Sem nome' : name,
      avatarUrl: avatarUrl,
      revision: state.revision + 1,
    );
  }

  void updateName(String name) {
    state = UserProfile(
      name: name.trim().isEmpty ? 'Sem nome' : name,
      avatarUrl: state.avatarUrl,
      revision: state.revision + 1,
    );
  }

  void updateAvatar(String? avatarUrl) {
    state = UserProfile(
      name: state.name,
      avatarUrl: avatarUrl,
      revision: state.revision + 1,
    );
  }

  void clear() {
    state = UserProfile(name: _guestName, avatarUrl: null, revision: state.revision + 1);
  }

  static String _normalizeName(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? 'Sem nome' : trimmed;
  }

  static String? _normalizeAvatarUrl(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }
}

// Perfil do usuário atual.
final userProfileProvider = NotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);

// Notificações ativas globalmente.
final notificationsActiveProvider = StateProvider<bool>((ref) => true);

// Contador global de mudanças: plano, atividades, perfil — screens usam
// ref.listen para reagir e recarregar dados.
final appChangeProvider = StateProvider<int>((ref) => 0);
