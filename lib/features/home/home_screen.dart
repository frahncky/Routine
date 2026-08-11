import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/atividades/atividade_card.dart';
import 'package:routine/atividades/cadastro_atividade_screen.dart';
import 'package:routine/features/assinatura/plan_access.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/home/widgets/daily_focus_card.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/notifications/notifications.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/widgets/app_background.dart';
import 'package:routine/widgets/calendar_header.dart';
import 'package:routine/widgets/confirm_dialog.dart';
import 'package:routine/widgets/custom_appbar.dart';
import 'package:routine/widgets/empty_state_card.dart';
import 'package:routine/widgets/show_snackbar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  DateTime _selectedDate = DateTime.now();
  final List<Atividade> _atividades = [];
  final List<Atividade> _calendarSource = [];
  final ScrollController _agendaScrollController = ScrollController();
  final Map<int, GlobalKey> _activityCardKeys = <int, GlobalKey>{};
  List<Map<String, dynamic>> _excecoes = [];
  String _currentPlan = PlanRules.gratuito;
  Timer? _timelineTicker;
  int? _lastCenteredActivityId;
  bool _isLoading = true;
  String? _loadError;

  static const Duration _focusBeforeStartWindow = Duration(minutes: 90);

  bool get _canUseCollaborativeFeatures =>
      PlanRules.hasFullAccess(_currentPlan);

  int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final hourCompare = a.hour.compareTo(b.hour);
    if (hourCompare != 0) return hourCompare;
    return a.minute.compareTo(b.minute);
  }

  int _compareActivitiesByTime(Atividade a, Atividade b) {
    final aFinished = _isFinished(a) ? 1 : 0;
    final bFinished = _isFinished(b) ? 1 : 0;
    final finishedCompare = aFinished.compareTo(bFinished);
    if (finishedCompare != 0) return finishedCompare;

    final inicioCompare = _compareTimeOfDay(a.horaInicio, b.horaInicio);
    if (inicioCompare != 0) return inicioCompare;

    final fimCompare = _compareTimeOfDay(a.horaFim, b.horaFim);
    if (fimCompare != 0) return fimCompare;

    return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
  }

  bool _isFinished(Atividade atividade) {
    final status = AtividadeStatus.normalize(atividade.status);
    return status == AtividadeStatus.concluida ||
        status == AtividadeStatus.cancelada;
  }

  @override
  void initState() {
    super.initState();
    _startTimelineTicker();
    _carregarAtividades();
  }

  @override
  void dispose() {
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

  List<Atividade> _calendarActivitiesForSelectedWeek() {
    final weekStart =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final occurrences = <Atividade>[];

    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + offset,
      );
      for (final atividade in _calendarSource) {
        final activityDate = _onlyDate(atividade.data);
        final isOneOff = DateUtils.isSameDay(activityDate, day);
        final isRecurring = atividade.repetirSemanalmente &&
            !day.isBefore(activityDate) &&
            atividade.diasDaSemana.contains(day.weekday);
        if (isOneOff || isRecurring) {
          occurrences.add(atividade.copyWith(data: day));
        }
      }
    }
    return occurrences;
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

  Future<void> _carregarAtividades() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final userMap = await DB.instance.getUser();
      final atividades =
          await DB.instance.getActivitiesForDateIncludingRecurring(
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
      final calendarRows = await DB.instance.getActivitiesByStatus(
        status: [
          AtividadeStatus.cancelada,
          AtividadeStatus.concluida,
          AtividadeStatus.andamento,
          AtividadeStatus.atrasada,
          'Ativa',
          AtividadeStatus.pendente,
        ],
      );

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
        _calendarSource
          ..clear()
          ..addAll(calendarRows.map(Atividade.fromMap));
        _excecoes = excecoes;
        _currentPlan = PlanAccess.effectivePlan(
          isSignedIn: FirebaseAuth.instance.currentUser != null,
          storedPlan: userMap?['typeAccount']?.toString(),
        );
        _isLoading = false;
      });
      _scheduleActivityFocus(force: true);
    } catch (error, stackTrace) {
      debugPrint('Erro ao carregar atividades: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Não foi possível carregar suas atividades.';
      });
    }
  }

  Future<void> _openActivityForm() async {
    final nova = await Navigator.push<Atividade>(
      context,
      MaterialPageRoute(builder: (_) => const CadastroAtividadeScreen()),
    );
    await _carregarAtividades();
    if (nova != null) ref.read(appChangeProvider.notifier).state++;
  }

  void _scrollToActivity(Atividade atividade) {
    final targetContext = _activityCardKeys[atividade.id]?.currentContext;
    if (targetContext == null) return;
    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      alignment: 0.25,
    );
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _lastCenteredActivityId = null;
    _carregarAtividades();
  }

  Future<void> _onToggleConcluida(
    Atividade ativ, {
    bool showFeedback = true,
  }) async {
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
      ref.read(appChangeProvider.notifier).state++;
      await syncAllActivityNotifications();
      if (showFeedback && mounted) {
        _showCompletionFeedback(ativ.copyWith(status: novoStatus));
      }
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
    ref.read(appChangeProvider.notifier).state++;
    await syncAllActivityNotifications();
    if (showFeedback && mounted) {
      _showCompletionFeedback(atividadeAtualizada);
    }
  }

  void _showCompletionFeedback(Atividade atividade) {
    final completed = AtividadeStatus.normalize(atividade.status) ==
        AtividadeStatus.concluida;
    showSnackbar(
      context: context,
      title: completed ? 'Atividade concluída' : 'Conclusão desfeita',
      message: atividade.titulo,
      variant: completed ? SnackbarVariant.success : SnackbarVariant.neutral,
      actionLabel: completed ? 'DESFAZER' : null,
      onAction: completed
          ? () => _onToggleConcluida(atividade, showFeedback: false)
          : null,
    );
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
      ref.read(appChangeProvider.notifier).state++;
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
    ref.read(appChangeProvider.notifier).state++;
    await syncAllActivityNotifications();
  }

  Future<void> _onExcluir(Atividade ativ) async {
    if (ativ.repetirSemanalmente) {
      final escolha = await showActionDialog<String>(
        context,
        title: 'Excluir atividade',
        message: 'Deseja excluir apenas este dia ou todas as ocorrências?',
        actions: const [
          DialogAction(label: 'Somente este dia', value: 'dia'),
          DialogAction(label: 'Todas', value: 'todas', isDestructive: true),
        ],
      );
      if (escolha == 'dia') {
        await DB.instance.addActivityException(
          atividadeId: ativ.id,
          data: _selectedDate,
          tipo: 'excluida',
        );
        await _carregarAtividades();
        if (!mounted) return;
        showSnackbar(
          context: context,
          title: 'Exclusão de atividade',
          message: 'Ocorrência do dia excluída!',
          variant: SnackbarVariant.success,
        );
        ref.read(appChangeProvider.notifier).state++;
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
          if (!mounted) return;
          showSnackbar(
            context: context,
            title: 'Exclusão de atividade',
            message: 'Atividade excluída com sucesso!',
            variant: SnackbarVariant.success,
          );
        } else {
          if (!mounted) return;
          showSnackbar(
            context: context,
            title: 'Exclusão de atividade',
            message: 'Atividade não foi excluída!',
            variant: SnackbarVariant.error,
          );
        }
        ref.read(appChangeProvider.notifier).state++;
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
        if (!mounted) return;
        showSnackbar(
          context: context,
          title: 'Exclusão de atividade',
          message: 'Atividade excluída com sucesso!',
          variant: SnackbarVariant.success,
        );
      } else {
        if (!mounted) return;
        showSnackbar(
          context: context,
          title: 'Exclusão de atividade',
          message: 'Atividade não foi excluída!',
          variant: SnackbarVariant.error,
        );
      }
      ref.read(appChangeProvider.notifier).state++;
      await syncAllActivityNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<int>(appChangeProvider, (_, __) => _carregarAtividades());

    final listBottomPadding = MediaQuery.paddingOf(context).bottom + 96.0;

    final atividadesDoDia = _atividadesDoDiaFiltradas(
      source: _atividades,
      excecoes: _excecoes,
      selectedDate: _selectedDate,
    );
    _syncActivityCardKeys(atividadesDoDia);

    return Scaffold(
      appBar: CustomAppBar(
        sectionTitle: Localizations.localeOf(context).languageCode == 'pt'
            ? 'Início'
            : 'Home',
      ),
      body: AppBackground(
        child: Column(
          children: [
            if (atividadesDoDia.isNotEmpty)
              DailyFocusCard(
                atividades: atividadesDoDia,
                selectedDate: _selectedDate,
                onOpenActivity: _scrollToActivity,
                onCompleteActivity: _onToggleConcluida,
              ),
            CalendarHeader(
              selectedDate: _selectedDate,
              onDateSelected: _onDateSelected,
              onAdd: _openActivityForm,
              atividades: _calendarActivitiesForSelectedWeek(),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildAgendaContent(
                atividadesDoDia,
                listBottomPadding: listBottomPadding,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgendaContent(
    List<Atividade> atividadesDoDia, {
    required double listBottomPadding,
  }) {
    if (_isLoading && _atividades.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null && _atividades.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmptyStateCard(
                icon: Icons.cloud_off_outlined,
                title: 'Não foi possível carregar',
                message: _loadError,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _carregarAtividades,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (atividadesDoDia.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

      return ListView(
        padding: EdgeInsets.fromLTRB(12, 4, 12, listBottomPadding),
        children: [
          Semantics(
            container: true,
            label: isToday
                ? 'Dia livre por aqui. Nenhuma atividade para hoje.'
                : 'Dia livre por aqui. Nenhuma atividade nesta data.',
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surface,
                    Color.alphaBlend(
                      scheme.primary.withValues(alpha: 0.065),
                      scheme.surface,
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.09),
                ),
                boxShadow: [
                  BoxShadow(
                    color: scheme.shadow.withValues(alpha: 0.045),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              scheme.primary,
                              Color.alphaBlend(
                                scheme.secondary.withValues(alpha: 0.30),
                                scheme.primary,
                              ),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(17),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.16),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.event_available_rounded,
                          color: scheme.onPrimary,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isToday ? 'AGENDA DE HOJE' : 'DATA SELECIONADA',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Dia livre por aqui',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              isToday
                                  ? 'Aproveite o espaço para respirar ou planeje algo importante.'
                                  : 'Nada foi planejado para esta data.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _openActivityForm,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar atividade'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _agendaScrollController,
          padding: EdgeInsets.fromLTRB(0, 8, 0, listBottomPadding),
          itemCount: atividadesDoDia.length,
          itemBuilder: (_, i) {
            final ativ = atividadesDoDia[i];
            final cardKey =
                _activityCardKeys.putIfAbsent(ativ.id, () => GlobalKey());
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
        if (_isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }
}
