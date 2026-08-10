import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/features/assinatura/plan_access.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/assinatura/assinatura_screen.dart';
import 'package:routine/features/assinatura/widgets/plan_locked_card.dart';
import 'package:routine/notifications/notifications.dart';
import 'package:routine/participant_selection_sheet.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/theme/app_semantic_colors.dart';
import 'package:routine/widgets/confirm_dialog.dart';
import 'package:routine/widgets/show_snackbar.dart';

class CadastroAtividadeScreen extends ConsumerStatefulWidget {
  final Atividade? atividade;

  /// Atividade usada como modelo pra pré-preencher um cadastro NOVO (botão
  /// "Reutilizar" do Histórico) — diferente de [atividade], que indica modo
  /// de edição. Os dois nunca devem ser passados juntos.
  final Atividade? duplicarDe;

  const CadastroAtividadeScreen({super.key, this.atividade, this.duplicarDe})
      : assert(
          atividade == null || duplicarDe == null,
          'Não é possível editar e duplicar ao mesmo tempo',
        );

  @override
  ConsumerState<CadastroAtividadeScreen> createState() =>
      _CadastroAtividadeScreenState();
}

class _CadastroAtividadeScreenState
    extends ConsumerState<CadastroAtividadeScreen> {
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _dataController = TextEditingController();
  final TextEditingController _horaInicioController = TextEditingController();
  final TextEditingController _horaFimController = TextEditingController();

  DateTime? _dataSelecionada;
  TimeOfDay? _horaInicioSelecionada;
  TimeOfDay? _horaFimSelecionada;
  bool _statusConcluida = false;
  List<Participante> _participantes = [];

  List<bool> _diasSelecionados = List.filled(7, false);
  bool _repetirSemanalmente = false;
  List<int> _lembretesSelecionados = [];
  String _currentPlan = PlanRules.gratuito;

  static const List<MapEntry<int, String>> _opcoesLembrete = [
    MapEntry(10, '10 min antes'),
    MapEntry(30, '30 min antes'),
    MapEntry(60, '1 hora antes'),
    MapEntry(1440, '1 dia antes'),
  ];

  bool get _isPersonalOnly => PlanRules.isPersonalAgendaOnly(_currentPlan);

  @override
  void initState() {
    super.initState();
    _preencherCamposEdicao();
    _loadCurrentPlan();
  }

  void _preencherCamposEdicao() {
    final atividadeParaEditar = widget.atividade;
    final template = atividadeParaEditar ?? widget.duplicarDe;
    if (template == null) return;

    _tituloController.text = template.titulo;
    _descricaoController.text = template.descricao;
    _repetirSemanalmente = template.repetirSemanalmente;
    _diasSelecionados =
        List.generate(7, (i) => template.diasDaSemana.contains(i + 1));
    _lembretesSelecionados = List.of(template.reminderMinutes);

    if (atividadeParaEditar != null) {
      // Modo edição: mantém data/hora/status/participantes originais.
      _dataSelecionada = atividadeParaEditar.data;
      _horaInicioSelecionada = atividadeParaEditar.horaInicio;
      _horaFimSelecionada = atividadeParaEditar.horaFim;
      _statusConcluida =
          AtividadeStatus.normalize(atividadeParaEditar.status) ==
              AtividadeStatus.concluida;
      _participantes = List.of(atividadeParaEditar.participantes);
    } else {
      // Modo duplicar: parte de hoje, status/participantes resetam (evita
      // reconvite acidental de participantes de uma atividade antiga).
      _dataSelecionada = DateTime.now();
      _horaInicioSelecionada = template.horaInicio;
      _horaFimSelecionada = template.horaFim;
      _statusConcluida = false;
      _participantes = [];
    }

    _dataController.text = DateFormat('dd/MM/yyyy').format(_dataSelecionada!);
    Future.delayed(Duration.zero, () {
      if (mounted) {
        _horaInicioController.text = _horaInicioSelecionada!.format(context);
        _horaFimController.text = _horaFimSelecionada!.format(context);
      }
    });
  }

  Future<void> _loadCurrentPlan() async {
    final userMap = await DB.instance.getUser();
    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    final plan = PlanAccess.effectivePlan(
      isSignedIn: isSignedIn,
      storedPlan: userMap?['typeAccount']?.toString(),
    );
    final personalOnly = PlanRules.isPersonalAgendaOnly(plan);
    if (!mounted) return;
    setState(() {
      _currentPlan = plan;
      if (personalOnly) {
        _participantes = [];
      }
    });
  }

  Future<void> _openPlans() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AssinaturaScreen()),
    );
    await _loadCurrentPlan();
  }

  Future<void> _showUpgradeDialogForParticipants() async {
    final action = await showActionDialog<String>(
      context,
      title: 'Recurso Colaborativo',
      message:
          'O plano ${PlanRules.displayName(_currentPlan)} permite apenas agenda pessoal. Para adicionar participantes, ative o Colaborativo.',
      actions: const [
        DialogAction(label: 'Ver planos', value: 'plans'),
      ],
    );
    if (!mounted) return;
    if (action == 'plans') {
      await _openPlans();
    }
  }

  Future<void> _showUpgradeDialogForActivityLimit(int limit) async {
    final action = await showActionDialog<String>(
      context,
      title: 'Limite de atividades atingido',
      message:
          'O plano ${PlanRules.displayName(_currentPlan)} permite até $limit atividades. Para cadastrar mais, mude de plano.',
      actions: const [
        DialogAction(label: 'Ver planos', value: 'plans'),
      ],
    );
    if (!mounted) return;
    if (action == 'plans') {
      await _openPlans();
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _dataController.dispose();
    _horaInicioController.dispose();
    _horaFimController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData() async {
    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: _dataSelecionada ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (data != null) {
      setState(() {
        _dataSelecionada = data;
        _dataController.text = DateFormat('dd/MM/yyyy').format(data);
      });
    }
  }

  Future<void> _selecionarHoraInicio() async {
    final TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: _horaInicioSelecionada ?? TimeOfDay.now(),
    );
    if (hora != null) {
      setState(() {
        _horaInicioSelecionada = hora;
        _horaInicioController.text = hora.format(context);
      });
    }
  }

  Future<void> _selecionarHoraFim() async {
    final TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: _horaFimSelecionada ?? TimeOfDay.now(),
    );
    if (!mounted) return;
    if (hora != null &&
        (_horaInicioSelecionada == null ||
            hora.hour > _horaInicioSelecionada!.hour ||
            (hora.hour == _horaInicioSelecionada!.hour &&
                hora.minute >= _horaInicioSelecionada!.minute))) {
      setState(() {
        _horaFimSelecionada = hora;
        _horaFimController.text = hora.format(context);
      });
    } else if (hora != null) {
      showSnackbar(
        context: context,
        title: 'Horário inválido',
        message: 'A hora de fim não pode ser antes da hora de início!',
        variant: SnackbarVariant.warning,
      );
    }
  }

  Future<void> _adicionarParticipante() async {
    if (_isPersonalOnly) {
      await _showUpgradeDialogForParticipants();
      return;
    }
    final currentEmail =
        (await DB.instance.getEmailFromDB() ?? '').trim().toLowerCase();
    final existingEmails =
        _participantes.map((p) => p.email.trim().toLowerCase()).toSet();
    if (!mounted) return;

    final selectedParticipants = await ParticipantSelectionSheet.show(
      context: context,
      currentEmail: currentEmail,
      existingEmails: existingEmails,
    );

    if (!mounted ||
        selectedParticipants == null ||
        selectedParticipants.isEmpty) {
      return;
    }

    setState(() {
      _participantes.addAll(selectedParticipants);
    });
  }

  Future<void> _salvarAtividade() async {
    try {
      if (_tituloController.text.isEmpty ||
          _dataSelecionada == null ||
          _horaInicioSelecionada == null ||
          _horaFimSelecionada == null) {
        showSnackbar(
          context: context,
          title: 'Campos obrigatórios',
          message: 'Preencha todos os campos!',
          variant: SnackbarVariant.warning,
        );
        return;
      }

      final diasSelecionados = _diasSelecionados
          .asMap()
          .entries
          .where((entry) => entry.value)
          .map((entry) => entry.key + 1)
          .toList();

      if (_repetirSemanalmente && diasSelecionados.isEmpty) {
        showSnackbar(
          context: context,
          title: 'Campos obrigatórios',
          message: 'Selecione ao menos um dia da semana.',
          variant: SnackbarVariant.warning,
        );
        return;
      }

      final novaAtividade = Atividade(
        id: widget.atividade?.id ?? 0,
        titulo: _tituloController.text,
        descricao: _descricaoController.text,
        data: _dataSelecionada!,
        horaInicio: _horaInicioSelecionada!,
        horaFim: _horaFimSelecionada!,
        status: _statusConcluida
            ? AtividadeStatus.concluida
            : AtividadeStatus.pendente,
        participantes: _isPersonalOnly ? [] : _participantes,
        repetirSemanalmente: _repetirSemanalmente,
        diasDaSemana: diasSelecionados,
        reminderMinutes: _lembretesSelecionados,
      );

      final db = DB.instance;
      Atividade atividadePersistida = novaAtividade;
      if (widget.atividade == null) {
        final limit = PlanRules.activityLimit(_currentPlan);
        if (!PlanRules.hasUnlimitedActivities(_currentPlan) &&
            (await db.countActivities()) >= limit) {
          if (!mounted) return;
          await _showUpgradeDialogForActivityLimit(limit);
          return;
        }
        final insertedId = await db.insertActivity(novaAtividade);
        atividadePersistida = novaAtividade.copyWith(id: insertedId);
      } else {
        await db.updateActivity(novaAtividade);
      }

      await db.sendActivityInvites(atividadePersistida);
      await syncAllActivityNotifications();
      if (!mounted) return;

      showSnackbar(
        context: context,
        title: 'Atividade',
        message: 'Atividade salva com sucesso!',
        variant: SnackbarVariant.success,
      );

      Navigator.of(context).pop(atividadePersistida);
    } catch (e) {
      if (!mounted) {
        debugPrint('Erro ao salvar atividade: $e');
        return;
      }
      showSnackbar(
        context: context,
        title: 'Atividade',
        message: 'Erro ao salvar a atividade.',
        variant: SnackbarVariant.error,
      );
      debugPrint('Erro ao salvar atividade: $e');
    }
  }

  InputDecoration _customInputDecoration(
      String label, IconData icon, Color iconColor) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: iconColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildParticipantesList() {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    return _participantes.isEmpty
        ? const Text('Nenhum participante adicionado.')
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _participantes.length,
            itemBuilder: (context, index) {
              final participante = _participantes[index];
              return ListTile(
                title: Text(participante.nome),
                subtitle: Text(participante.email),
                trailing: IconButton(
                  icon: Icon(Icons.remove_circle, color: semantic.danger),
                  onPressed: () {
                    setState(() {
                      _participantes.removeAt(index);
                    });
                  },
                ),
              );
            },
          );
  }

  Widget _buildActionButtons() {
    final isEdit = widget.atividade != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            label: const Text('Cancelar'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _salvarAtividade,
            icon: const Icon(Icons.save),
            label: Text(isEdit ? 'Atualizar' : 'Salvar'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(appChangeProvider, (_, __) => _loadCurrentPlan());
    final isEdit = widget.atividade != null;
    final iconColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar Atividade' : 'Cadastrar Atividade'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _tituloController,
                decoration:
                    _customInputDecoration('Título', Icons.title, iconColor),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descricaoController,
                decoration: _customInputDecoration(
                    'Descrição', Icons.description, iconColor),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dataController,
                readOnly: true,
                decoration: _customInputDecoration(
                    'Data', Icons.date_range, iconColor),
                onTap: _selecionarData,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _horaInicioController,
                readOnly: true,
                decoration: _customInputDecoration(
                    'Hora Início', Icons.access_time, iconColor),
                onTap: _selecionarHoraInicio,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _horaFimController,
                readOnly: true,
                decoration: _customInputDecoration(
                    'Hora Fim', Icons.access_time_outlined, iconColor),
                onTap: _selecionarHoraFim,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Repetir semanalmente'),
                  Switch(
                    value: _repetirSemanalmente,
                    onChanged: (value) {
                      setState(() {
                        _repetirSemanalmente = value;
                        if (!value) {
                          _diasSelecionados = List.filled(7, false);
                        }
                      });
                    },
                  ),
                ],
              ),
              if (_repetirSemanalmente)
                Wrap(
                  spacing: 8,
                  children: List.generate(7, (index) {
                    const dias = [
                      'Seg',
                      'Ter',
                      'Qua',
                      'Qui',
                      'Sex',
                      'Sáb',
                      'Dom',
                    ];
                    return FilterChip(
                      label: Text(dias[index]),
                      selected: _diasSelecionados[index],
                      onSelected: (bool selected) {
                        setState(() {
                          _diasSelecionados[index] = selected;
                        });
                      },
                    );
                  }),
                ),
              const SizedBox(height: 16),
              Text(
                'Lembrar antes',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _lembretesSelecionados.isEmpty
                    ? 'Nenhum selecionado: usa o padrão definido em Configurações.'
                    : 'Substitui o lembrete padrão só nesta atividade.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _opcoesLembrete.map((opcao) {
                  final selecionado =
                      _lembretesSelecionados.contains(opcao.key);
                  return FilterChip(
                    label: Text(opcao.value),
                    selected: selecionado,
                    onSelected: (selected) {
                      setState(() {
                        _lembretesSelecionados = selected
                            ? ([..._lembretesSelecionados, opcao.key]..sort())
                            : _lembretesSelecionados
                                .where((m) => m != opcao.key)
                                .toList();
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              if (_isPersonalOnly)
                PlanLockedCard(
                  centered: false,
                  title: 'Agenda pessoal ativa',
                  message:
                      'Plano ${PlanRules.displayName(_currentPlan)} com agenda pessoal ativa. Participantes estão disponíveis no Premium.',
                  onAction: _openPlans,
                  actionLabel: 'Ver planos',
                )
              else ...[
                Text('Participantes:',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                _buildParticipantesList(),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _adicionarParticipante,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Adicionar Participante'),
                ),
              ],
              const SizedBox(height: 16),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
