import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/atividades/atividade_card.dart';
import 'package:routine/atividades/cadastro_atividade_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _carregarAtividades();
  }

  Future<void> _carregarAtividades() async {
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
    mergedChange.value = true;
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
      mergedChange.value = true;
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
    mergedChange.value = true;
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
        mergedChange.value = true;
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
        mergedChange.value = true;
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
      mergedChange.value = true;
    }
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
                mergedChange.value = true;
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
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

