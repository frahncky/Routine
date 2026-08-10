import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:routine/features/assinatura/assinatura_screen.dart';
import 'package:routine/features/assinatura/plan_access.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:image_picker/image_picker.dart';
import 'package:routine/features/configuracoes/delete_account.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/login/login_screen.dart';
import 'package:routine/login/user.dart';
import 'package:routine/notifications/notifications.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/services/auth_wrapper.dart';
import 'package:routine/testing/e2e_hooks.dart';
import 'package:routine/widgets/custom_appbar.dart';
import 'package:routine/widgets/profile_avatar.dart';
import 'package:routine/widgets/show_snackbar.dart';

class ConfiguracoesScreen extends ConsumerStatefulWidget {
  const ConfiguracoesScreen({super.key});

  @override
  ConsumerState<ConfiguracoesScreen> createState() =>
      _ConfiguracoesScreenState();
}

class _ConfiguracoesScreenState extends ConsumerState<ConfiguracoesScreen>
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
  DateTime? _lastBackupAt;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  bool get _isAccountConnected =>
      FirebaseAuth.instance.currentUser != null &&
      (user?.email.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _minutosAntesController.text = _minutosAntes.toString();
    _loadUser();
    _loadMinutosAntes();
    _loadNotificacoesAtivas();
    _refreshPendingNotificationsCount();
    _loadLastBackupAt();
  }

  Future<void> _loadLastBackupAt() async {
    final raw = await DB.instance.getConfig('last_backup_at');
    final millis = int.tryParse(raw ?? '');
    if (!mounted) return;
    setState(() {
      _lastBackupAt =
          millis != null ? DateTime.fromMillisecondsSinceEpoch(millis) : null;
    });
  }

  Future<void> _doBackupNow() async {
    setState(() => _isBackingUp = true);
    try {
      await DB.instance.backupAllToCloud();
      await _loadLastBackupAt();
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Backup concluído',
        message: 'Seus dados foram enviados para a nuvem.',
        variant: SnackbarVariant.success,
        icon: Icons.cloud_done_outlined,
      );
    } catch (_) {
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Falha no backup',
        message: 'Não foi possível enviar os dados agora. Tente novamente.',
        variant: SnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _doRestoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: const Text(
          'Isso pode sobrescrever atividades e contatos deste dispositivo com os dados salvos na nuvem. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isRestoring = true);
    try {
      await DB.instance.restoreCloudBackup();
      if (!mounted) return;
      ref.read(appChangeProvider.notifier).state++;
      showSnackbar(
        context: context,
        title: 'Restauração concluída',
        message: 'Seus dados foram restaurados da nuvem.',
        variant: SnackbarVariant.success,
        icon: Icons.cloud_download_outlined,
      );
    } catch (_) {
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Falha na restauração',
        message: 'Não foi possível restaurar os dados agora. Tente novamente.',
        variant: SnackbarVariant.error,
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minutosAntesController.dispose();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final userMap = await DB.instance.getUser();
    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    if (!mounted) return;
    final loadedUser =
        isSignedIn && userMap != null ? LocalUser.fromMap(userMap) : null;
    setState(() {
      user = loadedUser;
      _nameController.text = user?.name ?? '';
    });
    if (loadedUser != null) {
      ref.read(userProfileProvider.notifier).updateProfile(
        name: loadedUser.name,
        avatarUrl: loadedUser.avatarUrl,
      );
      return;
    }
    await ref.read(userProfileProvider.notifier).refresh();
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
      context: context,
      title: 'Configuração salva',
      message: 'Tempo de notificação atualizado!',
      variant: SnackbarVariant.success,
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
    ref.read(notificationsActiveProvider.notifier).state = value;
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
    try {
      await syncAllActivityNotifications();
      await _refreshPendingNotificationsCount();
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Notificações',
        message: 'Agendamento atualizado.',
        variant: SnackbarVariant.info,
        icon: Icons.notifications_active,
      );
    } catch (e) {
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Erro',
        message: 'Não foi possível atualizar o diagnóstico agora.',
        variant: SnackbarVariant.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isResyncingNotifications = false);
      }
    }
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
        context: context,
        title: 'Conta necessária',
        message: 'Entre para editar seu perfil.',
        variant: SnackbarVariant.warning,
        icon: Icons.lock_outline,
      );
      await _openLogin();
      return;
    }

    String? imagePath;
    final override = profileImagePickerOverride;
    if (override != null) {
      imagePath = await override();
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
    ref.read(userProfileProvider.notifier).updateProfile(
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
      await ref.read(userProfileProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        user = previousUser;
      });
      ref.read(userProfileProvider.notifier).updateProfile(
        name: previousUser.name,
        avatarUrl: previousUser.avatarUrl,
      );
      showSnackbar(
        context: context,
        title: 'Erro',
        message: 'Não foi possível salvar a foto agora.',
        variant: SnackbarVariant.error,
      );
      return;
    }

    ref.read(appChangeProvider.notifier).state++;

    if (!mounted) return;
    showSnackbar(
      context: context,
      title: 'Foto atualizada',
      message: 'Sua foto de perfil foi atualizada com sucesso!',
      variant: SnackbarVariant.success,
    );
  }

  Future<void> _toggleEditarNome() async {
    if (user == null) {
      await _openLogin();
      return;
    }
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

    ref.read(userProfileProvider.notifier).updateProfile(
      name: updatedUser.name,
      avatarUrl: updatedUser.avatarUrl,
    );
    try {
      final targetEmail = previousUser.email.trim().isNotEmpty
          ? previousUser.email
          : (FirebaseAuth.instance.currentUser?.email ?? '');
      await DB.instance.updateAccount(name: newName, email: targetEmail);
      await _syncFirebaseProfile(name: newName);
      await ref.read(userProfileProvider.notifier).refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        user = previousUser;
      });
      ref.read(userProfileProvider.notifier).updateProfile(
        name: previousUser.name,
        avatarUrl: previousUser.avatarUrl,
      );
      showSnackbar(
        context: context,
        title: 'Erro',
        message: 'Não foi possível salvar o nome agora.',
        variant: SnackbarVariant.error,
      );
      return;
    }

    ref.read(appChangeProvider.notifier).state++;

    if (!mounted) return;
    showSnackbar(
      context: context,
      title: 'Atualização de nome',
      message: 'Seu nome de usuário foi atualizado',
      variant: SnackbarVariant.success,
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await DB.instance.clearLocalData();
    ref.read(userProfileProvider.notifier).clear();
    if (!mounted) return;

    showSnackbar(
      context: context,
      title: 'Conta desconectada',
      message: 'Sua conta foi desconectada!',
      variant: SnackbarVariant.warning,
      icon: Icons.check_circle,
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapper()),
      (_) => false,
    );
  }

  Future<void> _openLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
    if (!mounted) return;
    await _loadUser();
  }

  Future<void> _openPlans() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AssinaturaScreen(),
      ),
    );
  }

  Color _planCardColor(String plan) {
    final normalized = PlanRules.normalize(plan);
    if (normalized == PlanRules.colaborativo) return const Color(0xFFE8FFF4);
    if (normalized == PlanRules.avancado) return const Color(0xFFF0FFF4);
    if (normalized == PlanRules.basico) return const Color(0xFFEAF4FF);
    return const Color(0xFFFFF3E8);
  }

  Color _planBorderColor(String plan) {
    final normalized = PlanRules.normalize(plan);
    if (normalized == PlanRules.colaborativo) return const Color(0xFF34D399);
    if (normalized == PlanRules.avancado) return const Color(0xFF4ADE80);
    if (normalized == PlanRules.basico) return const Color(0xFF60A5FA);
    return const Color(0xFFF59E0B);
  }

  Widget _buildPlanSummaryCard(String currentPlan) {
    final title = 'Plano ${PlanRules.displayName(currentPlan)}';
    final hasCloudBackup = PlanRules.hasCloudBackup(currentPlan);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          if (hasCloudBackup) ...[
            const SizedBox(height: 12),
            Text(
              _lastBackupAt != null
                  ? 'Último backup: ${_lastBackupAt!.day.toString().padLeft(2, '0')}/${_lastBackupAt!.month.toString().padLeft(2, '0')}/${_lastBackupAt!.year} ${_lastBackupAt!.hour.toString().padLeft(2, '0')}:${_lastBackupAt!.minute.toString().padLeft(2, '0')}'
                  : 'Nenhum backup enviado ainda',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBackingUp ? null : _doBackupNow,
                    icon: _isBackingUp
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Fazer backup agora'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isRestoring ? null : _doRestoreBackup,
                    icon: _isRestoring
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download_outlined, size: 18),
                    label: const Text('Restaurar backup'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<int>(appChangeProvider, (_, __) => _loadUser());

    final profile = ref.watch(userProfileProvider);
    final localAvatar = user?.avatarUrl.trim();
    final effectiveAvatar =
        (localAvatar != null && localAvatar.isNotEmpty)
            ? localAvatar
            : profile.avatarUrl;
    final localName = user?.name.trim();
    final displayedName = (localName != null && localName.isNotEmpty)
        ? localName
        : (profile.name.trim().isEmpty ? '' : profile.name);

    final currentPlan = PlanAccess.effectivePlan(
      isSignedIn: _isAccountConnected,
      storedPlan: user?.typeAccount,
    );

    return Scaffold(
      appBar: const CustomAppBar(),
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
                      child: Stack(
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
                      ),
                    ),
                    const SizedBox(height: 20),
                    ListTile(
                      title: const Text('Perfil'),
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
                        icon: Icon(_isAccountConnected
                            ? (_isEditingName ? Icons.save : Icons.edit)
                            : Icons.login),
                        onPressed: _toggleEditarNome,
                      ),
                    ),
                    ListTile(
                      title: const Text('E-mail'),
                      subtitle: Text(
                        _isAccountConnected ? user!.email : 'Não conectado',
                      ),
                    ),
                    if (!_isAccountConnected)
                      ListTile(
                        title: const Text('Entrar ou criar conta'),
                        subtitle: const Text(
                          'Necessário apenas para compras e recursos premium.',
                        ),
                        leading: const Icon(Icons.login),
                        onTap: _openLogin,
                      ),
                    _buildPlanSummaryCard(currentPlan),
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
                        title: const Text('Diagnóstico de notificações'),
                        subtitle: Text(
                          _pendingNotificationsCount >= 0
                              ? 'Pendentes no sistema: $_pendingNotificationsCount'
                              : 'Não foi possível ler notificações pendentes',
                        ),
                        trailing: _isResyncingNotifications
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : IconButton(
                                icon: const Icon(Icons.sync),
                                onPressed: _resyncNotifications,
                                tooltip: 'Re-sincronizar',
                              ),
                      ),
                    const Divider(),
                    if (_isAccountConnected)
                      ListTile(
                        title: const Text('Sair'),
                        leading: const Icon(Icons.logout, color: Colors.red),
                        onTap: _signOut,
                      ),
                    if (_isAccountConnected)
                      ListTile(
                        title: const Text('Excluir conta'),
                        leading:
                            const Icon(Icons.delete_forever, color: Colors.red),
                        onTap: () => deleteAccount(context, ref),
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
