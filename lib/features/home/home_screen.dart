import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/atividades/atividade_card.dart';
import 'package:routine/atividades/cadastro_atividade_screen.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart';
import 'package:routine/widgets/calendar_header.dart';
import 'package:routine/widgets/custom_appbar.dart';
import 'package:routine/widgets/show_snackbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _selectedDate = DateTime.now();
  final List<Atividade> _atividades = [];
  List<Map<String, dynamic>> _excecoes = [];
  String _currentPlan = PlanRules.gratis;

  bool get _canUseCollaborativeFeatures => PlanRules.hasFullAccess(_currentPlan);

  @override
  void initState() {
    super.initState();
    planChangeNotifier.addListener(_onPlanChanged);
    _carregarAtividades();
  }

  @override
  void dispose() {
    planChangeNotifier.removeListener(_onPlanChanged);
    super.dispose();
  }

  void _onPlanChanged() {
    _carregarAtividades();
  }

  Future<void> _carregarAtividades() async {
    final userMap = await DB.instance.getUser();
    final atividades = await DB.instance.getActivitiesForDateIncludingRecurring(
      date: _selectedDate,
      status: [
        AtividadeStatus.cancelada,
        AtividadeStatus.concluida,
        'Ativa',
        AtividadeStatus.pendente,
      ],
    );
    final excecoes = await DB.instance.getActivityExceptionsForDay(_selectedDate);

    final listaAtividades =
        atividades.map((map) => Atividade.fromMap(map)).toList();

    if (!mounted) return;
    setState(() {
      _atividades
        ..clear()
        ..addAll(listaAtividades);
      _excecoes = excecoes;
      _currentPlan = PlanRules.normalize(userMap?['typeAccount']?.toString());
    });
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _carregarAtividades();
  }

  Future<void> _onToggleConcluida(Atividade ativ) async {
    ativ.status = AtividadeStatus.normalize(ativ.status) == AtividadeStatus.concluida
        ? AtividadeStatus.pendente
        : AtividadeStatus.concluida;
    await DB.instance.updateActivity(ativ);
    final index = _atividades.indexWhere((a) => a.id == ativ.id);
    if (index != -1 && mounted) {
      setState(() {
        _atividades[index] = ativ;
      });
    }
    mergedChange.markChanged();
  }

  Future<void> _onEditar(Atividade ativ) async {
    final atualizada = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CadastroAtividadeScreen(atividade: ativ),
      ),
    ) as Atividade?;

    await _carregarAtividades();

    if (atualizada != null) {
      final index = _atividades.indexWhere((a) => a.id == atualizada.id);
      if (index != -1 && mounted) {
        setState(() {
          _atividades[index] = atualizada;
        });
      }
      mergedChange.markChanged();
    }
  }

  Future<void> _onAtividadeCancelada(Atividade atividadeCancelada) async {
    final index = _atividades.indexWhere((a) => a.id == atividadeCancelada.id);
    if (index != -1 && mounted) {
      setState(() {
        _atividades[index] =
            atividadeCancelada.copyWith(status: atividadeCancelada.status);
      });
    }
    await DB.instance.updateActivity(atividadeCancelada);
    await _carregarAtividades();
    mergedChange.markChanged();
  }

  Future<void> _onExcluir(Atividade ativ) async {
    if (ativ.repetirSemanalmente) {
      final escolha = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir atividade'),
          content: const Text('Deseja excluir apenas este dia ou todas as ocorrencias?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, 'dia'),
              child: const Text('Somente este dia'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'todas'),
              child: const Text('Todas'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
      if (escolha == 'dia') {
        await DB.instance.addActivityException(
          atividadeId: ativ.id,
          data: _selectedDate,
          tipo: 'excluida',
        );
        await _carregarAtividades();
        showSnackbar(
          title: 'Exclusao de atividade',
          message: 'Ocorrencia do dia excluida!',
          backgroundColor: Colors.red.shade300,
          icon: Icons.check_circle,
        );
        mergedChange.markChanged();
        return;
      } else if (escolha == 'todas') {
        final sucesso = await DB.instance.deleteActivity(ativ.id);
        if (sucesso) {
          if (mounted) {
            setState(() {
              _atividades.removeWhere((a) => a.id == ativ.id);
            });
          }
          showSnackbar(
            title: 'Exclusao de atividade',
            message: 'Atividade excluida com sucesso!',
            backgroundColor: Colors.red.shade300,
            icon: Icons.check_circle,
          );
        } else {
          showSnackbar(
            title: 'Exclusao de atividade',
            message: 'Atividade nao foi excluida!',
            backgroundColor: Colors.red.shade300,
            icon: Icons.check_circle,
          );
        }
        mergedChange.markChanged();
        return;
      } else {
        return;
      }
    } else {
      final sucesso = await DB.instance.deleteActivity(ativ.id);
      if (sucesso) {
        if (mounted) {
          setState(() {
            _atividades.removeWhere((a) => a.id == ativ.id);
          });
        }
        showSnackbar(
          title: 'Exclusao de atividade',
          message: 'Atividade excluida com sucesso!',
          backgroundColor: Colors.red.shade300,
          icon: Icons.check_circle,
        );
      } else {
        showSnackbar(
          title: 'Exclusao de atividade',
          message: 'Atividade nao foi excluida!',
          backgroundColor: Colors.red.shade300,
          icon: Icons.check_circle,
        );
      }
      mergedChange.markChanged();
    }
  }

  Widget _buildAdBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFE7C2), Color(0xFFFFD39A)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: const [
          Icon(Icons.campaign_outlined),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Publicidade: use o plano Basico ou Premium para remover anuncios.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final diaSemana = _selectedDate.weekday;

    final atividadesDoDia = _atividades.where((a) {
      final exc = _excecoes.firstWhere(
        (e) => e['atividade_id'] == a.id && e['tipo'] == 'excluida',
        orElse: () => <String, dynamic>{},
      );
      if (exc.isNotEmpty) return false;
      if (a.repetirSemanalmente && a.diasDaSemana.contains(diaSemana)) {
        return true;
      }
      return a.data.year == _selectedDate.year &&
          a.data.month == _selectedDate.month &&
          a.data.day == _selectedDate.day;
    }).toList();

    return Scaffold(
      appBar: CustomAppBar(),
      body: Column(
        children: [
          CalendarHeader(
            selectedDate: _selectedDate,
            onDateSelected: _onDateSelected,
            onAdd: () async {
              final nova = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CadastroAtividadeScreen()),
              ) as Atividade?;
              await _carregarAtividades();
              if (nova != null) {
                mergedChange.markChanged();
              }
            },
            atividades: _atividades,
          ),
          const SizedBox(height: 12),
          const Divider(height: 2),
          Expanded(
            child: atividadesDoDia.isEmpty
                ? const Center(child: Text(' Sem Atividades'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: atividadesDoDia.length,
                    itemBuilder: (_, i) {
                      final ativ = atividadesDoDia[i];
                      return AtividadeCard(
                        atividade: ativ,
                        onToggleConcluida: () => _onToggleConcluida(ativ),
                        onEditar: () => _onEditar(ativ),
                        onExcluir: () => _onExcluir(ativ),
                        onCancelar: () => _onAtividadeCancelada(ativ),
                        showParticipants: _canUseCollaborativeFeatures,
                      );
                    },
                  ),
          ),
          if (PlanRules.hasAds(_currentPlan)) _buildAdBanner(),
        ],
      ),
    );
  }
}

