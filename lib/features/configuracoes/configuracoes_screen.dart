import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:routine/features/assinatura/assinatura_screen.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:image_picker/image_picker.dart';
import 'package:routine/features/configuracoes/delete_account.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/login/login_screen.dart';
import 'package:routine/login/user.dart';
import 'package:routine/main.dart';
import 'package:routine/notifications/notifications.dart';
import 'package:routine/widgets/custom_appbar.dart';
import 'package:routine/widgets/profile_avatar.dart';
import 'package:routine/widgets/show_snackbar.dart';

class ConfiguracoesScreen extends StatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  State<ConfiguracoesScreen> createState() => _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends State<ConfiguracoesScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  LocalUser? user;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _minutosAntesController = TextEditingController();
  bool _isEditingName = false;

  int _minutosAntes = 10;
  bool _notificacoesAtivas = true;
  int _pendingNotificationsCount = -1;
  bool _isResyncingNotifications = false;

  @override
  void initState() {
    super.initState();
    _minutosAntesController.text = _minutosAntes.toString();
    planChangeNotifier.addListener(_onPlanChanged);
    _loadUser();
    _loadMinutosAntes();
    _loadNotificacoesAtivas();
    _refreshPendingNotificationsCount();
  }

  @override
  void dispose() {
    planChangeNotifier.removeListener(_onPlanChanged);
    _nameController.dispose();
    _minutosAntesController.dispose();
    super.dispose();
  }

  void _onPlanChanged() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final userMap = await DB.instance.getUser();
    if (!mounted) return;
    final loadedUser = userMap != null ? LocalUser.fromMap(userMap) : null;
    setState(() {
      user = loadedUser;
      _nameController.text = user?.name ?? '';
    });
    if (loadedUser != null) {
      updateCurrentUserProfile(
        name: loadedUser.name,
        avatarUrl: loadedUser.avatarUrl,
      );
      return;
    }
    await refreshCurrentUserProfile();
  }

  Future<void> _loadMinutosAntes() async {
    final minutos = await DB.instance.getConfig('minutosAntesNotificacao');
    final resolvedMinutes = minutos != null ? int.tryParse(minutos) ?? 10 : 10;
    if (!mounted) return;
    setState(() {
      _minutosAntes = resolvedMinutes;
      _minutosAntesController.text = resolvedMinutes.toString();
    });
  }

  Future<void> _salvarMinutosAntes(int value) async {
    await DB.instance.setConfig('minutosAntesNotificacao', value.toString());
    await syncAllActivityNotifications();
    await _refreshPendingNotificationsCount();
    if (!mounted) return;
    setState(() {
      _minutosAntes = value;
      _minutosAntesController.text = value.toString();
    });
    showSnackbar(
      title: 'Configuração salva',
      message: 'Tempo de notificação atualizado!',
      backgroundColor: Colors.green.shade200,
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _loadNotificacoesAtivas() async {
    final ativo = await DB.instance.getConfig('notificacoesAtivas');
    if (!mounted) return;
    setState(() {
      _notificacoesAtivas = ativo == null ? true : ativo == 'true';
    });
  }

  Future<void> _salvarNotificacoesAtivas(bool value) async {
    await DB.instance.setConfig('notificacoesAtivas', value.toString());
    await syncAllActivityNotifications();
    await _refreshPendingNotificationsCount();
    if (!mounted) return;
    setState(() {
      _notificacoesAtivas = value;
    });
    notificacoesAtivasNotifier.value = value;
  }

  Future<void> _refreshPendingNotificationsCount() async {
    final count = await debugPendingNotificationCount();
    if (!mounted) return;
    setState(() {
      _pendingNotificationsCount = count;
    });
  }

  Future<void> _resyncNotifications() async {
    if (_isResyncingNotifications) return;
    setState(() => _isResyncingNotifications = true);
    await syncAllActivityNotifications();
    await _refreshPendingNotificationsCount();
    if (!mounted) return;
    setState(() => _isResyncingNotifications = false);
    showSnackbar(
      title: 'Notificacoes',
      message: 'Agendamento atualizado.',
      backgroundColor: Colors.blue.shade200,
      icon: Icons.notifications_active,
    );
  }

  Future<void> _syncFirebaseProfile({
    String? name,
    String? avatarUrl,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      if (name != null) {
        await currentUser.updateDisplayName(name);
      }
      if (avatarUrl != null) {
        await currentUser.updatePhotoURL(avatarUrl);
      }
      await currentUser.reload();
    } catch (e) {
      debugPrint('Falha ao sincronizar perfil no Firebase Auth: $e');
    }
  }

  Future<void> _editarFoto() async {
    if (user == null) {
      showSnackbar(
        title: 'Erro',
        message: 'Usuário não encontrado!',
        backgroundColor: Colors.red.shade200,
        icon: Icons.error_outline,
      );
      return;
    }

    String? imagePath;
    final pickerOverride = profileImagePickerOverride;
    if (pickerOverride != null) {
      imagePath = await pickerOverride();
    } else {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      imagePath = pickedFile?.path;
    }
    if (imagePath == null || imagePath.isEmpty) return;
    final previousUser = user!;
    final updatedUser = previousUser.copyWith(avatarUrl: imagePath);

    if (!mounted) return;
    setState(() {
      user = updatedUser;
    });
    updateCurrentUserProfile(
      name: updatedUser.name,
      avatarUrl: updatedUser.avatarUrl,
    );

    final provider = FileImage(File(imagePath));
    await provider.evict();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    try {
      final targetEmail = previousUser.email.trim().isNotEmpty
          ? previousUser.email
          : (FirebaseAuth.instance.currentUser?.email ?? '');
      await DB.instance.updateAccount(email: targetEmail, avatarUrl: imagePath);
      await _syncFirebaseProfile(avatarUrl: imagePath);
      await refreshCurrentUserProfile();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        user = previousUser;
      });
      updateCurrentUserProfile(
        name: previousUser.name,
        avatarUrl: previousUser.avatarUrl,
      );
      showSnackbar(
        title: 'Erro',
        message: 'Não foi possível salvar a foto agora.',
        backgroundColor: Colors.red.shade200,
        icon: Icons.error_outline,
      );
      return;
    }

    changeAvatar.value = !changeAvatar.value;
    mergedChange.markChanged();

    showSnackbar(
      title: 'Foto atualizada',
      message: 'Sua foto de perfil foi atualizada com sucesso!',
      backgroundColor: Colors.green.shade200,
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _toggleEditarNome() async {
    if (_isEditingName) {
      await _salvarNome();
      return;
    }
    setState(() => _isEditingName = true);
  }

  Future<void> _salvarNome() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (user == null) return;

    final newName = _nameController.text.trim();
    final previousUser = user!;
    final updatedUser = previousUser.copyWith(name: newName);
    if (!mounted) return;
    setState(() {
      user = updatedUser;
      _isEditingName = false;
    });

    updateCurrentUserProfile(
      name: updatedUser.name,
      avatarUrl: updatedUser.avatarUrl,
    );
    try {
      final targetEmail = previousUser.email.trim().isNotEmpty
          ? previousUser.email
          : (FirebaseAuth.instance.currentUser?.email ?? '');
      await DB.instance.updateAccount(name: newName, email: targetEmail);
      await _syncFirebaseProfile(name: newName);
      await refreshCurrentUserProfile();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        user = previousUser;
      });
      updateCurrentUserProfile(
        name: previousUser.name,
        avatarUrl: previousUser.avatarUrl,
      );
      showSnackbar(
        title: 'Erro',
        message: 'Não foi possível salvar o nome agora.',
        backgroundColor: Colors.red.shade200,
        icon: Icons.error_outline,
      );
      return;
    }

    changeName.value = !changeName.value;
    mergedChange.markChanged();

    showSnackbar(
      title: 'Atualização de nome',
      message: 'Seu nome de usuário foi atualizado',
      backgroundColor: Colors.green.shade200,
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await DB.instance.clearLocalData();
    clearCurrentUserProfile();
    if (!mounted) return;

    showSnackbar(
      title: 'Conta desconectada',
      message: 'Sua conta foi desconectada!',
      backgroundColor: Colors.orange.shade200,
      icon: Icons.check_circle,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginScreen()),
    );
  }

  Future<void> _openPlans() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AssinaturaScreen(),
      ),
    );
    await _loadUser();
  }

  Color _planCardColor(String plan) {
    final normalized = PlanRules.normalize(plan);
    if (normalized == PlanRules.premium) return const Color(0xFFE8FFF4);
    if (normalized == PlanRules.basico) return const Color(0xFFEAF4FF);
    return const Color(0xFFFFF3E8);
  }

  Color _planBorderColor(String plan) {
    final normalized = PlanRules.normalize(plan);
    if (normalized == PlanRules.premium) return const Color(0xFF34D399);
    if (normalized == PlanRules.basico) return const Color(0xFF60A5FA);
    return const Color(0xFFF59E0B);
  }

  Widget _buildPlanSummaryCard() {
    final currentPlan = PlanRules.normalize(user?.typeAccount);
    final title = 'Plano ${PlanRules.displayName(currentPlan)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _planCardColor(currentPlan),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _planBorderColor(currentPlan),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _openPlans,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Gerenciar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: CustomAppBar(),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F8FF), Color(0xFFEAF1FF)],
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Divider(height: 2),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: ValueListenableBuilder<CurrentUserProfile>(
                        valueListenable: currentUserProfileNotifier,
                        builder: (context, profile, _) {
                          final localAvatar = user?.avatarUrl.trim();
                          final effectiveAvatar =
                              (localAvatar != null && localAvatar.isNotEmpty)
                                  ? localAvatar
                                  : profile.avatarUrl;
                          return Stack(
                            children: [
                              ProfileAvatar(
                                key: const Key('settings_profile_avatar'),
                                avatarUrl: effectiveAvatar,
                                radius: 50,
                                revision: profile.revision,
                                backgroundColor: Colors.white,
                                iconColor: Colors.grey,
                                iconSize: 40,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: InkWell(
                                  key: const Key('settings_edit_photo_button'),
                                  onTap: _editarFoto,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Colors.indigo,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit,
                                        color: Colors.white, size: 18),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<CurrentUserProfile>(
                      valueListenable: currentUserProfileNotifier,
                      builder: (context, profile, _) {
                        final localName = user?.name.trim();
                        final displayedName = (localName != null &&
                                localName.isNotEmpty)
                            ? localName
                            : (profile.name.trim().isEmpty ? '' : profile.name);

                        return ListTile(
                          title: const Text('Usuário'),
                          subtitle: _isEditingName
                              ? TextFormField(
                                  key: const Key('settings_name_field'),
                                  controller: _nameController,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Campo obrigatório';
                                    }
                                    return null;
                                  },
                                )
                              : Text(
                                  displayedName,
                                  key: const Key('settings_name_value'),
                                ),
                          trailing: IconButton(
                            key: const Key('settings_edit_name_button'),
                            icon:
                                Icon(_isEditingName ? Icons.save : Icons.edit),
                            onPressed: _toggleEditarNome,
                          ),
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('E-mail'),
                      subtitle: Text(user?.email ?? ''),
                    ),
                    _buildPlanSummaryCard(),
                    const Divider(),
                    ListTile(
                      title: const Text('Receber notificações'),
                      trailing: Switch(
                        key: const Key('settings_notifications_switch'),
                        value: _notificacoesAtivas,
                        onChanged: (value) {
                          _salvarNotificacoesAtivas(value);
                        },
                      ),
                    ),
                    if (_notificacoesAtivas)
                      ListTile(
                        title: const Text('Notificar antes da atividade'),
                        subtitle: Text(
                          _minutosAntes == 0
                              ? 'Sem notificação'
                              : '$_minutosAntes minutos antes',
                        ),
                        trailing: SizedBox(
                          width: 80,
                          child: TextFormField(
                            key: const Key('settings_minutes_before_field'),
                            controller: _minutosAntesController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 8),
                              hintText: '0 = sem',
                            ),
                            onFieldSubmitted: (value) {
                              final v = int.tryParse(value);
                              if (v != null && v >= 0) {
                                _salvarMinutosAntes(v);
                              }
                            },
                            onTapOutside: (_) =>
                                FocusScope.of(context).unfocus(),
                          ),
                        ),
                      ),
                    if (_notificacoesAtivas)
                      ListTile(
                        title: const Text('Diagnostico de notificacoes'),
                        subtitle: Text(
                          _pendingNotificationsCount >= 0
                              ? 'Pendentes no sistema: $_pendingNotificationsCount'
                              : 'Não foi possível ler notificações pendentes',
                        ),
                        trailing: _isResyncingNotifications
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.sync),
                                onPressed: _resyncNotifications,
                                tooltip: 'Re-sincronizar',
                              ),
                      ),
                    const Divider(),
                    ListTile(
                      title: const Text('Sair'),
                      leading: const Icon(Icons.logout, color: Colors.red),
                      onTap: _signOut,
                    ),
                    ListTile(
                      title: const Text('Excluir conta'),
                      leading:
                          const Icon(Icons.delete_forever, color: Colors.red),
                      onTap: () => deleteAccount(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
