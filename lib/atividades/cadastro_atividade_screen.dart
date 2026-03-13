import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/assinatura/assinatura_screen.dart';
import 'package:routine/features/assinatura/widgets/plan_locked_card.dart';
import 'package:routine/main.dart';

class CadastroAtividadeScreen extends StatefulWidget {
  final Atividade? atividade;

  const CadastroAtividadeScreen({super.key, this.atividade});

  @override
  State<CadastroAtividadeScreen> createState() =>
      _CadastroAtividadeScreenState();
}

class _CadastroAtividadeScreenState extends State<CadastroAtividadeScreen> {
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

  // Novos campos para repetição semanal
  List<bool> _diasSelecionados =
      List.filled(7, false); // [Seg, Ter, Qua, Qui, Sex, Sab, Dom]
  bool _repetirSemanalmente = false;
  String _currentPlan = PlanRules.gratis;

  bool get _isPersonalOnly => PlanRules.isPersonalAgendaOnly(_currentPlan);

  @override
  void initState() {
    super.initState();
    planChangeNotifier.addListener(_onPlanChanged);
    _preencherCamposEdicao();
    _loadCurrentPlan();
  }

  void _onPlanChanged() {
    _loadCurrentPlan();
  }

  void _preencherCamposEdicao() {
    final atividadeParaEditar = widget.atividade;
    if (atividadeParaEditar != null) {
      _tituloController.text = atividadeParaEditar.titulo;
      _descricaoController.text = atividadeParaEditar.descricao;
      _dataSelecionada = atividadeParaEditar.data;
      _horaInicioSelecionada = atividadeParaEditar.horaInicio;
      _horaFimSelecionada = atividadeParaEditar.horaFim;
      _statusConcluida =
          AtividadeStatus.normalize(atividadeParaEditar.status) ==
              AtividadeStatus.concluida;
      _participantes = atividadeParaEditar.participantes;
      _repetirSemanalmente = atividadeParaEditar.repetirSemanalmente;
      // Preenche os dias selecionados
      _diasSelecionados = List.generate(
          7, (i) => atividadeParaEditar.diasDaSemana.contains(i + 1));

      _dataController.text =
          DateFormat('dd/MM/yyyy').format(atividadeParaEditar.data);
      Future.delayed(Duration.zero, () {
        if (mounted) {
          _horaInicioController.text =
              atividadeParaEditar.horaInicio.format(context);
          _horaFimController.text = atividadeParaEditar.horaFim.format(context);
        }
      });
    }
  }

  Future<void> _loadCurrentPlan() async {
    final userMap = await DB.instance.getUser();
    final plan = PlanRules.normalize(userMap?['typeAccount']?.toString());
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
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recurso Premium'),
        content: Text(
          'O plano ${PlanRules.displayName(_currentPlan)} permite apenas agenda pessoal. Para adicionar participantes, ative o Premium.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'plans'),
            child: const Text('Ver planos'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'plans') {
      await _openPlans();
    }
  }

  @override
  void dispose() {
    planChangeNotifier.removeListener(_onPlanChanged);
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('A hora de fim não pode ser antes da hora de início!')),
      );
    }
  }

  bool _hasParticipantEmail(String email) {
    final normalized = email.trim().toLowerCase();
    return _participantes.any(
      (x) => x.email.trim().toLowerCase() == normalized,
    );
  }

  String _displayNameFromEmail(String email) {
    final localPart = email.split('@').first.trim();
    if (localPart.isEmpty) return email;
    final cleaned = localPart.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (cleaned.isEmpty) return email;
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Participante _normalizeParticipant(Participante participante) {
    final normalizedStatus = ParticipanteStatus.normalize(participante.status);
    return participante.copyWith(
      email: participante.email.trim().toLowerCase(),
      status: normalizedStatus,
      atrasoMinutos: normalizedStatus == ParticipanteStatus.atrasado
          ? participante.atrasoMinutos
          : null,
    );
  }

  Future<void> _adicionarParticipante() async {
    if (_isPersonalOnly) {
      await _showUpgradeDialogForParticipants();
      return;
    }

    final currentEmail =
        (await DB.instance.getEmailFromDB() ?? '').trim().toLowerCase();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    final todosParticipantes = (await DB.instance.getAllContacts())
        .map((e) => Participante.fromMap(e))
        .toList();
    List<Participante> participantesFiltrados = List.from(todosParticipantes);
    final filtroController = TextEditingController();
    final emailController = TextEditingController();
    String? modalError;

    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            final viewInsets = MediaQuery.of(context).viewInsets;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: EdgeInsets.only(bottom: viewInsets.bottom),
              child: FractionallySizedBox(
                heightFactor: 0.82,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: filtroController,
                        decoration: const InputDecoration(
                          labelText: 'Buscar por nome ou e-mail',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onTapOutside: (_) => FocusScope.of(context).unfocus(),
                        onChanged: (value) {
                          setModalState(() {
                            participantesFiltrados = todosParticipantes
                                .where((p) =>
                                    p.nome
                                        .toLowerCase()
                                        .contains(value.toLowerCase()) ||
                                    p.email
                                        .toLowerCase()
                                        .contains(value.toLowerCase()))
                                .toList();
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'Convidar por e-mail',
                                hintText: 'exemplo@dominio.com',
                                prefixIcon: Icon(Icons.alternate_email),
                              ),
                              onTapOutside: (_) =>
                                  FocusScope.of(context).unfocus(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () {
                              final inviteEmail =
                                  emailController.text.trim().toLowerCase();
                              if (!emailRegex.hasMatch(inviteEmail)) {
                                setModalState(() {
                                  modalError = 'Informe um e-mail valido.';
                                });
                                return;
                              }
                              if (inviteEmail == currentEmail) {
                                setModalState(() {
                                  modalError =
                                      'Voce nao pode convidar seu proprio e-mail.';
                                });
                                return;
                              }
                              if (_hasParticipantEmail(inviteEmail)) {
                                setModalState(() {
                                  modalError =
                                      'Este participante ja foi adicionado.';
                                });
                                return;
                              }

                              Participante? participantFromContacts;
                              for (final item in todosParticipantes) {
                                if (item.email.trim().toLowerCase() ==
                                    inviteEmail) {
                                  participantFromContacts = item;
                                  break;
                                }
                              }

                              final newParticipant = participantFromContacts !=
                                      null
                                  ? _normalizeParticipant(
                                      participantFromContacts)
                                  : Participante(
                                      nome: _displayNameFromEmail(inviteEmail),
                                      email: inviteEmail,
                                      status: ParticipanteStatus.pendente,
                                    );

                              FocusScope.of(context).unfocus();
                              if (!mounted) return;
                              setState(
                                  () => _participantes.add(newParticipant));
                              Navigator.pop(context);
                            },
                            child: const Text('Adicionar'),
                          ),
                        ],
                      ),
                    ),
                    if (modalError != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            modalError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: participantesFiltrados.isEmpty
                          ? const Center(
                              child: Text('Nenhum contato encontrado.'),
                            )
                          : ListView.builder(
                              itemCount: participantesFiltrados.length,
                              itemBuilder: (context, index) {
                                final participante =
                                    participantesFiltrados[index];
                                return ListTile(
                                  title: Text(participante.nome),
                                  subtitle: Text(participante.email),
                                  onTap: () {
                                    final normalizedParticipant =
                                        _normalizeParticipant(participante);
                                    if (_hasParticipantEmail(
                                        normalizedParticipant.email)) {
                                      Navigator.pop(context);
                                      return;
                                    }
                                    FocusScope.of(context).unfocus();
                                    if (!mounted) return;
                                    setState(() {
                                      _participantes.add(normalizedParticipant);
                                    });
                                    Navigator.pop(context);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } finally {
      filtroController.dispose();
      emailController.dispose();
    }
  }

  Future<void> _salvarAtividade() async {
    try {
      // Validação dos campos obrigatórios
      if (_tituloController.text.isEmpty ||
          _dataSelecionada == null ||
          _horaInicioSelecionada == null ||
          _horaFimSelecionada == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preencha todos os campos!')),
        );
        return;
      }

      // Criação da atividade
      final diasSelecionados = _diasSelecionados
          .asMap()
          .entries
          .where((entry) => entry.value)
          .map((entry) => entry.key + 1)
          .toList();

      if (_repetirSemanalmente && diasSelecionados.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione ao menos um dia da semana.')),
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
      );

      // Salvar no banco de dados
      final db = DB.instance;
      Atividade atividadePersistida = novaAtividade;
      if (widget.atividade == null) {
        final insertedId = await db.insertActivity(novaAtividade);
        atividadePersistida = novaAtividade.copyWith(id: insertedId);
      } else {
        await db.updateActivity(novaAtividade);
      }

      await db.sendActivityInvites(atividadePersistida);

      // Exibir mensagem de sucesso
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atividade salva com sucesso!')),
      );

      // Fechar a aba
      Navigator.of(context).pop();
    } catch (e) {
      // Exibir mensagem de erro
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar a atividade.')),
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
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
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
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.cancel, color: Colors.black),
            label:
                const Text('Cancelar', style: TextStyle(color: Colors.black)),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade200),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _salvarAtividade,
            icon: const Icon(Icons.save, color: Colors.black),
            label: Text(
              isEdit ? 'Atualizar' : 'Salvar',
              style: const TextStyle(color: Colors.black),
            ),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade200),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.atividade != null;

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
                    _customInputDecoration('Título', Icons.title, Colors.blue),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descricaoController,
                decoration: _customInputDecoration(
                    'Descrição', Icons.description, Colors.green),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _dataController,
                readOnly: true,
                decoration: _customInputDecoration(
                    'Data', Icons.date_range, Colors.orange),
                onTap: _selecionarData,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _horaInicioController,
                readOnly: true,
                decoration: _customInputDecoration(
                    'Hora Início', Icons.access_time, Colors.purple),
                onTap: _selecionarHoraInicio,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _horaFimController,
                readOnly: true,
                decoration: _customInputDecoration(
                    'Hora Fim', Icons.access_time_outlined, Colors.red),
                onTap: _selecionarHoraFim,
              ),
              const SizedBox(height: 16),
              // NOVO: Seletor de dias da semana e repetição
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
                    const dias = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
                    const nomes = [
                      'Seg',
                      'Ter',
                      'Qua',
                      'Qui',
                      'Sex',
                      'Sab',
                      'Dom'
                    ];
                    return FilterChip(
                      label: Text(dias[index]),
                      selected: _diasSelecionados[index],
                      onSelected: (bool selected) {
                        setState(() {
                          _diasSelecionados[index] = selected;
                        });
                      },
                      tooltip: nomes[index],
                    );
                  }),
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
                ElevatedButton.icon(
                  onPressed: _adicionarParticipante,
                  icon: const Icon(Icons.person_add, color: Colors.black),
                  label: const Text('Adicionar Participante',
                      style: TextStyle(color: Colors.black)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade200),
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
