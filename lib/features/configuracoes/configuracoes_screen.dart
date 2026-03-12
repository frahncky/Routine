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
import 'package:routine/widgets/custom_appbar.dart';
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
  bool _isEditingName = false;

  int _minutosAntes = 10;
  bool _notificacoesAtivas = true;

  @override
  void initState() {
    super.initState();
    planChangeNotifier.addListener(_onPlanChanged);
    _loadUser();
    _loadMinutosAntes();
    _loadNotificacoesAtivas();
  }

  @override
  void dispose() {
    planChangeNotifier.removeListener(_onPlanChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onPlanChanged() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final userMap = await DB.instance.getUser();
    if (!mounted) return;
    setState(() {
      user = userMap != null ? LocalUser.fromMap(userMap) : null;
      _nameController.text = user?.name ?? '';
    });
  }

  Future<void> _loadMinutosAntes() async {
    final minutos = await DB.instance.getConfig('minutosAntesNotificacao');
    if (!mounted) return;
    setState(() {
      _minutosAntes = minutos != null ? int.tryParse(minutos) ?? 10 : 10;
    });
  }

  Future<void> _salvarMinutosAntes(int value) async {
    await DB.instance.setConfig('minutosAntesNotificacao', value.toString());
    if (!mounted) return;
    setState(() {
      _minutosAntes = value;
    });
    showSnackbar(
      title: 'Configuracao salva',
      message: 'Tempo de notificacao atualizado!',
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
    if (!mounted) return;
    setState(() {
      _notificacoesAtivas = value;
    });
    notificacoesAtivasNotifier.value = value;
  }

  Future<void> _editarFoto() async {
    if (user == null) {
      showSnackbar(
        title: 'Erro',
        message: 'Usuario nao encontrado!',
        backgroundColor: Colors.red.shade200,
        icon: Icons.error_outline,
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final imagePath = pickedFile.path;
    await DB.instance.updateAccount(email: user!.email, avatarUrl: imagePath);

    changeAvatar.value = !changeAvatar.value;

    await _loadUser();
    if (!mounted) return;

    showSnackbar(
      title: 'Foto atualizada',
      message: 'Sua foto de perfil foi atualizada com sucesso!',
      backgroundColor: Colors.green.shade200,
      icon: Icons.check_circle_outline,
    );
  }

  void _toggleEditarNome() {
    if (_isEditingName) {
      _salvarNome();
      return;
    }
    setState(() => _isEditingName = true);
  }

  Future<void> _salvarNome() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (user == null) return;

    final newName = _nameController.text.trim();
    await DB.instance.updateAccount(name: newName, email: user!.email);
    if (!mounted) return;

    setState(() {
      user = user!.copyWith(name: newName);
      _isEditingName = false;
    });

    showSnackbar(
      title: 'Atualizacao de nome',
      message: 'Seu nome de usuario foi atualizado',
      backgroundColor: Colors.green.shade200,
      icon: Icons.check_circle_outline,
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    await DB.instance.clearLocalData();
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

  Widget _buildPlanBenefit(bool enabled, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            enabled ? Icons.check_circle : Icons.remove_circle_outline,
            color: enabled ? Colors.green.shade600 : Colors.grey.shade600,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }

  Widget _buildPlanSummaryCard() {
    final currentPlan = PlanRules.normalize(user?.typeAccount);
    final hasAds = PlanRules.hasAds(currentPlan);
    final personalOnly = PlanRules.isPersonalAgendaOnly(currentPlan);
    final title = 'Plano ${PlanRules.displayName(currentPlan)} ativo';

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
              const Icon(Icons.workspace_premium_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPlanBenefit(!hasAds, 'Sem propagandas'),
          _buildPlanBenefit(!personalOnly, 'Agenda colaborativa'),
          _buildPlanBenefit(!personalOnly, 'Contatos e participantes'),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _openPlans,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Gerenciar planos'),
            ),
          ),
        ],
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final avatarProvider = _resolveAvatar(user?.avatarUrl);

    return Scaffold(
      appBar: CustomAppBar(),
      body: Form(
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
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: avatarProvider,
                          child: avatarProvider == null
                              ? const Icon(Icons.person,
                                  size: 40, color: Colors.grey)
                              : null,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
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
                    title: const Text('Usuario'),
                    subtitle: _isEditingName
                        ? TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Campo obrigatorio';
                              }
                              return null;
                            },
                          )
                        : Text(user?.name ?? ''),
                    trailing: IconButton(
                      icon: Icon(_isEditingName ? Icons.save : Icons.edit),
                      onPressed: _toggleEditarNome,
                    ),
                  ),
                  ListTile(
                    title: const Text('E-mail'),
                    subtitle: Text(user?.email ?? ''),
                  ),
                  _buildPlanSummaryCard(),
                  const Divider(),
                  ListTile(
                    title: const Text('Receber notificacoes'),
                    trailing: Switch(
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
                            ? 'Sem notificacao'
                            : '$_minutosAntes minutos antes',
                      ),
                      trailing: SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: _minutosAntes.toString(),
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
                        ),
                      ),
                    ),
                  const Divider(),
                  ListTile(
                    title: const Text('Sair'),
                    leading: const Icon(Icons.logout, color: Colors.red),
                    onTap: _signOut,
                  ),
                  ListTile(
                    title: const Text('Deletar Conta'),
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
    );
  }
}
