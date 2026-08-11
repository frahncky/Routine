import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:routine/features/assinatura/assinatura_screen.dart';
import 'package:routine/features/assinatura/plan_access.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/assinatura/plan_visuals.dart';
import 'package:image_picker/image_picker.dart';
import 'package:routine/features/configuracoes/delete_account.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/login/login_screen.dart';
import 'package:routine/login/user.dart';
import 'package:routine/notifications/notifications.dart';
import 'package:routine/notifications/push_notifications.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/services/auth_wrapper.dart';
import 'package:routine/testing/e2e_hooks.dart';
import 'package:routine/theme/app_semantic_colors.dart';
import 'package:routine/widgets/app_background.dart';
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
    await unregisterPushTokenForCurrentUser();
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

  Widget _backupActionButton({
    required bool loading,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
  }) {
    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildSectionLabel(String label) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildAccountCard({
    required String displayedName,
    required String? effectiveAvatar,
    required int avatarRevision,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accountName =
        displayedName.trim().isEmpty ? 'Visitante' : displayedName.trim();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  key: const Key('settings_profile_avatar'),
                  avatarUrl: effectiveAvatar,
                  radius: 27,
                  revision: avatarRevision,
                  backgroundColor: colors.primaryContainer,
                  iconColor: colors.primary,
                  iconSize: 26,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _isEditingName
                      ? TextFormField(
                          key: const Key('settings_name_field'),
                          controller: _nameController,
                          autofocus: true,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            labelText: 'Nome',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Campo obrigatório';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _salvarNome(),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              accountName,
                              key: const Key('settings_name_value'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _isAccountConnected
                                  ? user!.email
                                  : 'Conta não conectada',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const Key('settings_edit_photo_button'),
                  tooltip: 'Editar foto do perfil',
                  onPressed: _editarFoto,
                  style: IconButton.styleFrom(
                    backgroundColor: colors.surfaceContainerLow,
                    foregroundColor: colors.primary,
                  ),
                  icon: const Icon(Icons.photo_camera_outlined, size: 20),
                ),
                IconButton(
                  key: const Key('settings_edit_name_button'),
                  tooltip: _isAccountConnected
                      ? (_isEditingName ? 'Salvar nome' : 'Editar nome')
                      : 'Entrar na conta',
                  style: IconButton.styleFrom(
                    foregroundColor: colors.primary,
                  ),
                  icon: Icon(
                    _isAccountConnected
                        ? (_isEditingName ? Icons.check : Icons.edit_outlined)
                        : Icons.login,
                    size: 21,
                  ),
                  onPressed: _toggleEditarNome,
                ),
              ],
            ),
            if (!_isAccountConnected) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 14),
              Text(
                'Necessário apenas para compras e recursos premium.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _openLogin,
                  icon: const Icon(Icons.login),
                  label: const Text('Entrar ou criar conta'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSummaryCard(String currentPlan) {
    final title = 'Plano ${PlanRules.displayName(currentPlan)}';
    final hasCloudBackup = PlanRules.hasCloudBackup(currentPlan);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final accent = PlanVisuals.borderFor(currentPlan);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outlineVariant,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final planIdentity = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.workspace_premium_outlined,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Seu plano atual',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final manageButton = TextButton.icon(
                onPressed: _openPlans,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Gerenciar'),
              );

              if (constraints.maxWidth < 310) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    planIdentity,
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: manageButton,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: planIdentity),
                  const SizedBox(width: 8),
                  manageButton,
                ],
              );
            },
          ),
          if (hasCloudBackup) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  size: 18,
                  color: colors.secondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastBackupAt != null
                        ? 'Último backup: ${_lastBackupAt!.day.toString().padLeft(2, '0')}/${_lastBackupAt!.month.toString().padLeft(2, '0')}/${_lastBackupAt!.year} ${_lastBackupAt!.hour.toString().padLeft(2, '0')}:${_lastBackupAt!.minute.toString().padLeft(2, '0')}'
                        : 'Nenhum backup enviado ainda',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final backupButton = _backupActionButton(
                  loading: _isBackingUp,
                  onPressed: _doBackupNow,
                  icon: Icons.cloud_upload_outlined,
                  label: 'Fazer backup agora',
                );
                final restoreButton = _backupActionButton(
                  loading: _isRestoring,
                  onPressed: _doRestoreBackup,
                  icon: Icons.cloud_download_outlined,
                  label: 'Restaurar backup',
                );
                if (constraints.maxWidth < 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      backupButton,
                      const SizedBox(height: 8),
                      restoreButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: backupButton),
                    const SizedBox(width: 8),
                    Expanded(child: restoreButton),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationsCard() {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Receber notificações',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _notificacoesAtivas
                            ? 'Lembretes estão ativos'
                            : 'Lembretes estão pausados',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  key: const Key('settings_notifications_switch'),
                  value: _notificacoesAtivas,
                  onChanged: _salvarNotificacoesAtivas,
                ),
              ],
            ),
          ),
          if (_notificacoesAtivas) ...[
            Divider(height: 1, color: colors.outlineVariant),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notificar antes da atividade',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _minutosAntes == 0
                              ? 'Sem antecedência'
                              : '$_minutosAntes minutos antes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 68,
                    child: TextFormField(
                      key: const Key('settings_minutes_before_field'),
                      controller: _minutosAntesController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        semanticCounterText: 'Minutos de antecedência',
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                      ),
                      onFieldSubmitted: (value) {
                        final v = int.tryParse(value);
                        if (v != null && v >= 0) {
                          _salvarMinutosAntes(v);
                        }
                      },
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'min',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.outlineVariant),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: const EdgeInsets.only(bottom: 6),
                leading: Icon(
                  Icons.tune_rounded,
                  color: colors.onSurfaceVariant,
                ),
                title: const Text('Opções avançadas'),
                textColor: colors.onSurface,
                iconColor: colors.primary,
                collapsedTextColor: colors.onSurface,
                collapsedIconColor: colors.onSurfaceVariant,
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(56, 0, 12, 4),
                    title: const Text('Diagnóstico de notificações'),
                    subtitle: Text(
                      _pendingNotificationsCount >= 0
                          ? 'Pendentes no sistema: $_pendingNotificationsCount'
                          : 'Não foi possível ler notificações pendentes',
                    ),
                    trailing: _isResyncingNotifications
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.sync),
                            onPressed: _resyncNotifications,
                            tooltip: 'Re-sincronizar',
                          ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountActionsCard() {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.logout, color: colors.onSurfaceVariant),
            title: const Text('Sair'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _signOut,
          ),
          Divider(
            height: 1,
            indent: 56,
            color: colors.outlineVariant,
          ),
          ListTile(
            leading: Icon(
              Icons.delete_forever_outlined,
              color: context.semantic.danger,
            ),
            title: Text(
              'Excluir conta',
              style: TextStyle(color: context.semantic.danger),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: context.semantic.danger,
            ),
            onTap: () => deleteAccount(context, ref),
          ),
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
    final effectiveAvatar = (localAvatar != null && localAvatar.isNotEmpty)
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
      appBar: CustomAppBar(
        sectionTitle: Localizations.localeOf(context).languageCode == 'pt'
            ? 'Configurações'
            : 'Settings',
      ),
      body: AppBackground(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              18,
              16,
              MediaQuery.paddingOf(context).bottom + 112,
            ),
            children: [
              _buildSectionLabel('Conta'),
              const SizedBox(height: 8),
              _buildAccountCard(
                displayedName: displayedName,
                effectiveAvatar: effectiveAvatar,
                avatarRevision: profile.revision,
              ),
              const SizedBox(height: 20),
              _buildSectionLabel('Plano e dados'),
              const SizedBox(height: 8),
              _buildPlanSummaryCard(currentPlan),
              const SizedBox(height: 20),
              _buildSectionLabel('Lembretes'),
              const SizedBox(height: 8),
              _buildNotificationsCard(),
              if (_isAccountConnected) ...[
                const SizedBox(height: 20),
                _buildSectionLabel('Segurança'),
                const SizedBox(height: 8),
                _buildAccountActionsCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
