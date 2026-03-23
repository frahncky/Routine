import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/atividades/atividade_card.dart';
import 'package:routine/atividades/cadastro_atividade_screen.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart';
import 'package:routine/notifications/notifications.dart';
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
  final ScrollController _agendaScrollController = ScrollController();
  final Map<int, GlobalKey> _activityCardKeys = <int, GlobalKey>{};
  List<Map<String, dynamic>> _excecoes = [];
  String _currentPlan = PlanRules.gratis;
  Timer? _timelineTicker;
  int? _lastCenteredActivityId;

  static const Duration _focusBeforeStartWindow = Duration(minutes: 90);

  bool get _canUseCollaborativeFeatures =>
      PlanRules.hasFullAccess(_currentPlan);

  int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final hourCompare = a.hour.compareTo(b.hour);
    if (hourCompare != 0) return hourCompare;
    return a.minute.compareTo(b.minute);
  }

  int _compareActivitiesByTime(Atividade a, Atividade b) {
    final inicioCompare = _compareTimeOfDay(a.horaInicio, b.horaInicio);
    if (inicioCompare != 0) return inicioCompare;

    final fimCompare = _compareTimeOfDay(a.horaFim, b.horaFim);
    if (fimCompare != 0) return fimCompare;

    return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    planChangeNotifier.addListener(_onPlanChanged);
    mergedChange.addListener(_onMergedChange);
    _startTimelineTicker();
    _carregarAtividades();
  }

  @override
  void dispose() {
    planChangeNotifier.removeListener(_onPlanChanged);
    mergedChange.removeListener(_onMergedChange);
    _timelineTicker?.cancel();
    _agendaScrollController.dispose();
    super.dispose();
  }

  void _startTimelineTicker() {
    _timelineTicker?.cancel();
    _timelineTicker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      _scheduleActivityFocus();
    });
  }

  DateTime _combineDateAndTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  DateTime _onlyDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isSelectedDateToday() {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  List<Atividade> _atividadesDoDiaFiltradas({
    required List<Atividade> source,
    required List<Map<String, dynamic>> excecoes,
    required DateTime selectedDate,
  }) {
    Map<String, dynamic>? camposEditadosDoDia(int atividadeId) {
      Map<String, dynamic>? latest;
      var latestId = -1;

      for (final exc in excecoes) {
        if (exc['atividade_id'] != atividadeId || exc['tipo'] != 'editada') {
          continue;
        }

        final rawCampos = exc['campos_editados'];
        if (rawCampos == null) continue;

        Map<String, dynamic>? parsed;
        if (rawCampos is String && rawCampos.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawCampos);
            if (decoded is Map<String, dynamic>) {
              parsed = decoded;
            } else if (decoded is Map) {
              parsed = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }

        if (parsed == null) continue;
        final excId = (exc['id'] as int?) ?? -1;
        if (excId >= latestId) {
          latestId = excId;
          latest = parsed;
        }
      }

      return latest;
    }

    final selectedDateOnly = _onlyDate(selectedDate);
    final diaSemana = selectedDate.weekday;
    final filtradas = <Atividade>[];

    for (final atividadeBase in source) {
      final exc = excecoes.firstWhere(
        (e) => e['atividade_id'] == atividadeBase.id && e['tipo'] == 'excluida',
        orElse: () => <String, dynamic>{},
      );
      if (exc.isNotEmpty) continue;

      final dataAtividade = _onlyDate(atividadeBase.data);
      final ehRecorrenteNoDia = atividadeBase.repetirSemanalmente &&
          atividadeBase.diasDaSemana.contains(diaSemana);

      final incluir = ehRecorrenteNoDia
          ? !selectedDateOnly.isBefore(dataAtividade)
          : dataAtividade == selectedDateOnly;

      if (!incluir) continue;

      var atividade = atividadeBase;
      final camposEditados = camposEditadosDoDia(atividadeBase.id);
      final statusEditado = camposEditados?['status']?.toString();
      if (statusEditado != null && statusEditado.isNotEmpty) {
        atividade = atividade.copyWith(status: statusEditado);
      }

      filtradas.add(atividade);
    }

    filtradas.sort(_compareActivitiesByTime);
    return filtradas;
  }

  int? _focusActivityIndex(List<Atividade> atividadesDoDia) {
    if (!_isSelectedDateToday() || atividadesDoDia.isEmpty) return null;

    final now = DateTime.now();
    for (var i = 0; i < atividadesDoDia.length; i++) {
      final atividade = atividadesDoDia[i];
      final normalizedStatus = AtividadeStatus.normalize(atividade.status);
      if (normalizedStatus == AtividadeStatus.concluida ||
          normalizedStatus == AtividadeStatus.cancelada) {
        continue;
      }

      final start = _combineDateAndTime(_selectedDate, atividade.horaInicio);
      final end = _combineDateAndTime(_selectedDate, atividade.horaFim);

      final isInProgress = !now.isBefore(start) &&
          (now.isBefore(end) || now.isAtSameMomentAs(end));
      if (isInProgress) return i;

      if (now.isBefore(start)) {
        final diff = start.difference(now);
        if (diff <= _focusBeforeStartWindow) {
          return i;
        }
        return null;
      }
    }

    return null;
  }

  void _syncActivityCardKeys(List<Atividade> atividadesDoDia) {
    final visibleIds = atividadesDoDia.map((a) => a.id).toSet();
    _activityCardKeys.removeWhere((id, _) => !visibleIds.contains(id));
    for (final atividade in atividadesDoDia) {
      _activityCardKeys.putIfAbsent(atividade.id, () => GlobalKey());
    }
  }

  void _scheduleActivityFocus({bool force = false}) {
    final atividadesDoDia = _atividadesDoDiaFiltradas(
      source: _atividades,
      excecoes: _excecoes,
      selectedDate: _selectedDate,
    );
    final targetIndex = _focusActivityIndex(atividadesDoDia);
    if (targetIndex == null) return;

    final targetActivity = atividadesDoDia[targetIndex];
    if (!force && _lastCenteredActivityId == targetActivity.id) return;

    _syncActivityCardKeys(atividadesDoDia);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final targetKey = _activityCardKeys[targetActivity.id];
      final targetContext = targetKey?.currentContext;
      if (targetContext == null) return;

      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );
      _lastCenteredActivityId = targetActivity.id;
    });
  }

  void _onPlanChanged() {
    _carregarAtividades();
  }

  void _onMergedChange() {
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
    final excecoes =
        await DB.instance.getActivityExceptionsForDay(_selectedDate);

    final listaAtividades = atividades
        .map((map) => Atividade.fromMap(map))
        .toList()
      ..sort(_compareActivitiesByTime);
    final atividadesDoDiaFiltradas = _atividadesDoDiaFiltradas(
      source: listaAtividades,
      excecoes: excecoes,
      selectedDate: _selectedDate,
    );
    _syncActivityCardKeys(atividadesDoDiaFiltradas);

    if (!mounted) return;
    setState(() {
      _atividades
        ..clear()
        ..addAll(listaAtividades);
      _excecoes = excecoes;
      _currentPlan = PlanRules.normalize(userMap?['typeAccount']?.toString());
    });
    _scheduleActivityFocus(force: true);
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _lastCenteredActivityId = null;
    _carregarAtividades();
  }

  Future<void> _onToggleConcluida(Atividade ativ) async {
    final novoStatus =
        AtividadeStatus.normalize(ativ.status) == AtividadeStatus.concluida
            ? AtividadeStatus.pendente
            : AtividadeStatus.concluida;

    if (ativ.repetirSemanalmente) {
      await DB.instance.upsertActivityException(
        atividadeId: ativ.id,
        data: _selectedDate,
        tipo: 'editada',
        camposEditados: {'status': novoStatus},
      );
      await _carregarAtividades();
      mergedChange.markChanged();
      await syncAllActivityNotifications();
      return;
    }

    final atividadeAtualizada = ativ.copyWith(status: novoStatus);
    await DB.instance.updateActivity(atividadeAtualizada);
    final index = _atividades.indexWhere((a) => a.id == ativ.id);
    if (index != -1 && mounted) {
      setState(() {
        _atividades[index] = atividadeAtualizada;
      });
    }
    mergedChange.markChanged();
    await syncAllActivityNotifications();
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
        _atividades[index] = atividadeCancelada;
      });
    }
    await _carregarAtividades();
    mergedChange.markChanged();
    await syncAllActivityNotifications();
  }

  Future<void> _onExcluir(Atividade ativ) async {
    if (ativ.repetirSemanalmente) {
      final escolha = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Excluir atividade'),
          content: const Text(
              'Deseja excluir apenas este dia ou todas as ocorrências?'),
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
          title: 'Exclusão de atividade',
          message: 'Ocorrência do dia excluída!',
          backgroundColor: Colors.red.shade300,
          icon: Icons.check_circle,
        );
        mergedChange.markChanged();
        await syncAllActivityNotifications();
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
            title: 'Exclusão de atividade',
            message: 'Atividade excluída com sucesso!',
            backgroundColor: Colors.red.shade300,
            icon: Icons.check_circle,
          );
        } else {
          showSnackbar(
            title: 'Exclusão de atividade',
            message: 'Atividade não foi excluída!',
            backgroundColor: Colors.red.shade300,
            icon: Icons.check_circle,
          );
        }
        mergedChange.markChanged();
        await syncAllActivityNotifications();
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
          title: 'Exclusão de atividade',
          message: 'Atividade excluída com sucesso!',
          backgroundColor: Colors.red.shade300,
          icon: Icons.check_circle,
        );
      } else {
        showSnackbar(
          title: 'Exclusão de atividade',
          message: 'Atividade não foi excluída!',
          backgroundColor: Colors.red.shade300,
          icon: Icons.check_circle,
        );
      }
      mergedChange.markChanged();
      await syncAllActivityNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final listBottomPadding = MediaQuery.paddingOf(context).bottom + 96.0;

    final atividadesDoDia = _atividadesDoDiaFiltradas(
      source: _atividades,
      excecoes: _excecoes,
      selectedDate: _selectedDate,
    );

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
        child: Column(
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
                  ? Center(
                      child: Text(
                        'Sem atividades neste dia',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    )
                  : ListView.builder(
                      controller: _agendaScrollController,
                      padding: EdgeInsets.fromLTRB(
                        0,
                        8,
                        0,
                        listBottomPadding,
                      ),
                      itemCount: atividadesDoDia.length,
                      itemBuilder: (_, i) {
                        final ativ = atividadesDoDia[i];
                        final cardKey = _activityCardKeys.putIfAbsent(
                            ativ.id, () => GlobalKey());
                        return KeyedSubtree(
                          key: cardKey,
                          child: AtividadeCard(
                            atividade: ativ,
                            onToggleConcluida: () => _onToggleConcluida(ativ),
                            onEditar: () => _onEditar(ativ),
                            onExcluir: () => _onExcluir(ativ),
                            onCancelar: _onAtividadeCancelada,
                            showParticipants: _canUseCollaborativeFeatures,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
