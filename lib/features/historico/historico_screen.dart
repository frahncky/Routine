import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/atividades/atividade_card.dart';
import 'package:routine/atividades/cadastro_atividade_screen.dart';
import 'package:routine/features/assinatura/plan_access.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/widgets/app_background.dart';
import 'package:routine/widgets/calendar_header.dart';
import 'package:routine/widgets/custom_appbar.dart';
import 'package:routine/widgets/empty_state_card.dart';

class HistoricoScreen extends ConsumerStatefulWidget {
  const HistoricoScreen({super.key});

  @override
  ConsumerState<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends ConsumerState<HistoricoScreen> {
  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  List<Atividade> _atividades = [];
  List<Atividade> _progressActivities = [];
  List<String> _availableYears = [];
  bool _isLoading = true;
  bool _modoAgrupado = false;
  String? _loadError;
  String _currentPlan = PlanRules.gratuito;
  int _loadGeneration = 0;

  bool get _canUseCollaborativeFeatures =>
      PlanRules.hasFullAccess(_currentPlan);

  int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final hourCompare = a.hour.compareTo(b.hour);
    if (hourCompare != 0) return hourCompare;
    return a.minute.compareTo(b.minute);
  }

  int _compareActivitiesByDateAndTime(Atividade a, Atividade b) {
    final dateA = DateUtils.dateOnly(a.data);
    final dateB = DateUtils.dateOnly(b.data);
    final dateCompare = dateA.compareTo(dateB);
    if (dateCompare != 0) return dateCompare;

    final startCompare = _compareTimeOfDay(a.horaInicio, b.horaInicio);
    if (startCompare != 0) return startCompare;

    final endCompare = _compareTimeOfDay(a.horaFim, b.horaFim);
    if (endCompare != 0) return endCompare;

    return a.titulo.toLowerCase().compareTo(b.titulo.toLowerCase());
  }

  Map<String, dynamic>? _parseEditedFields(dynamic rawFields) {
    if (rawFields == null) return null;
    if (rawFields is Map<String, dynamic>) return rawFields;
    if (rawFields is Map) return Map<String, dynamic>.from(rawFields);
    if (rawFields is! String || rawFields.isEmpty) return null;

    try {
      final decoded = jsonDecode(rawFields);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}

    return null;
  }

  String? _extractHistoricalStatus(Map<String, dynamic> exception) {
    final type = exception['tipo']?.toString().toLowerCase();
    if (type != 'editada') return null;

    final editedFields = _parseEditedFields(exception['campos_editados']);
    final editedStatus = editedFields?['status']?.toString();
    if (editedStatus == null || editedStatus.trim().isEmpty) return null;

    final normalized = AtividadeStatus.normalize(editedStatus);
    if (normalized == AtividadeStatus.concluida ||
        normalized == AtividadeStatus.cancelada) {
      return normalized;
    }
    return null;
  }

  String _historicoKey(Atividade atividade) {
    final date = DateUtils.dateOnly(atividade.data);
    return '${atividade.id}-${date.millisecondsSinceEpoch}';
  }

  Future<List<Atividade>> _loadHistoricalEditedOccurrences() async {
    final exceptions = await DB.instance.getAllActivityExceptions();
    if (exceptions.isEmpty) return [];

    final cache = <int, Atividade?>{};
    final occurrences = <Atividade>[];

    for (final exception in exceptions) {
      final status = _extractHistoricalStatus(exception);
      if (status == null) continue;

      final rawActivityId = exception['atividade_id'];
      final activityId = rawActivityId is int
          ? rawActivityId
          : int.tryParse(rawActivityId?.toString() ?? '');
      if (activityId == null) continue;

      if (!cache.containsKey(activityId)) {
        final baseMap = await DB.instance.getActivityById(activityId);
        cache[activityId] = baseMap == null ? null : Atividade.fromMap(baseMap);
      }
      final base = cache[activityId];
      if (base == null) continue;

      var date = DateUtils.dateOnly(base.data);
      final rawDate = exception['data'];
      final millis =
          rawDate is int ? rawDate : int.tryParse(rawDate?.toString() ?? '');
      if (millis != null) {
        date = DateUtils.dateOnly(DateTime.fromMillisecondsSinceEpoch(millis));
      }

      occurrences.add(base.copyWith(data: date, status: status));
    }

    return occurrences;
  }

  List<Atividade> _mergeHistoricalActivities(
    List<Atividade> base,
    List<Atividade> editedOccurrences,
  ) {
    final merged = <String, Atividade>{};
    for (final atividade in base) {
      merged[_historicoKey(atividade)] = atividade;
    }
    for (final atividade in editedOccurrences) {
      merged[_historicoKey(atividade)] = atividade;
    }

    return merged.values.toList()..sort(_compareActivitiesByDateAndTime);
  }

  List<String> _mergeAvailableYears({
    required List<String> dbYears,
    required List<Atividade> atividades,
  }) {
    final years = <int>{};
    for (final year in dbYears) {
      final parsed = int.tryParse(year);
      if (parsed != null) years.add(parsed);
    }
    for (final atividade in atividades) {
      years.add(atividade.data.year);
    }

    final ordered = years.toList()..sort();
    return ordered.map((year) => year.toString()).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  List<Atividade> _activitiesForDay(
    Iterable<Atividade> source,
    DateTime day,
  ) {
    return source
        .where((atividade) => _isSameDay(atividade.data, day))
        .toList();
  }

  void _syncVisibleActivities() {
    _atividades = _modoAgrupado
        ? List<Atividade>.of(_progressActivities)
        : _activitiesForDay(_progressActivities, _selectedDate);
  }

  Future<void> _reutilizarAtividade(Atividade atividade) async {
    final nova = await Navigator.push<Atividade>(
      context,
      MaterialPageRoute(
        builder: (_) => CadastroAtividadeScreen(duplicarDe: atividade),
      ),
    );
    if (nova != null) {
      await _loadData();
      ref.read(appChangeProvider.notifier).state++;
    }
  }

  Future<void> _loadData() async {
    final generation = ++_loadGeneration;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        DB.instance.getUser(),
        DB.instance.getActivitiesByStatus(
          status: [AtividadeStatus.cancelada, AtividadeStatus.concluida],
        ),
        _loadHistoricalEditedOccurrences(),
        DB.instance.getAllActivityYears(),
      ]);

      final userMap = results[0] as Map<String, dynamic>?;
      final activityMaps = results[1] as List<Map<String, dynamic>>;
      final editedOccurrences = results[2] as List<Atividade>;
      final dbYears = results[3] as List<String>;
      final baseActivities = activityMaps.map(Atividade.fromMap).toList();
      final progressActivities = _mergeHistoricalActivities(
        baseActivities,
        editedOccurrences,
      );
      final years = _mergeAvailableYears(
        dbYears: dbYears,
        atividades: progressActivities,
      );
      final currentPlan = PlanAccess.effectivePlan(
        isSignedIn: FirebaseAuth.instance.currentUser != null,
        storedPlan: userMap?['typeAccount']?.toString(),
      );

      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _progressActivities = progressActivities;
        _availableYears = years;
        _currentPlan = currentPlan;
        _syncVisibleActivities();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Não foi possível atualizar seus dados de progresso.';
      });
    }
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(date);
      _syncVisibleActivities();
    });
  }

  void _selectDayFromProgress(DateTime date) {
    setState(() {
      _selectedDate = DateUtils.dateOnly(date);
      _modoAgrupado = false;
      _syncVisibleActivities();
    });
  }

  void _changeMode(bool grouped) {
    if (_modoAgrupado == grouped) return;
    setState(() {
      _modoAgrupado = grouped;
      _syncVisibleActivities();
    });
  }

  void _shiftSelectedWeek(int weekOffset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: 7 * weekOffset));
      _syncVisibleActivities();
    });
  }

  DateTime _weekStartFor(DateTime date) {
    final day = DateUtils.dateOnly(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  List<Atividade> _activitiesForWeek(DateTime date) {
    final start = _weekStartFor(date);
    final end = start.add(const Duration(days: 7));
    return _progressActivities.where((atividade) {
      final activityDate = DateUtils.dateOnly(atividade.data);
      return !activityDate.isBefore(start) && activityDate.isBefore(end);
    }).toList();
  }

  int _completedCount(Iterable<Atividade> atividades) {
    return atividades
        .where(
          (atividade) =>
              AtividadeStatus.normalize(atividade.status) ==
              AtividadeStatus.concluida,
        )
        .length;
  }

  int _bestCompletionStreak(Iterable<Atividade> atividades) {
    final completedDays = atividades
        .where(
          (atividade) =>
              AtividadeStatus.normalize(atividade.status) ==
              AtividadeStatus.concluida,
        )
        .map(
          (atividade) => DateTime.utc(
            atividade.data.year,
            atividade.data.month,
            atividade.data.day,
          ),
        )
        .toSet()
        .toList()
      ..sort();
    if (completedDays.isEmpty) return 0;

    var best = 1;
    var current = 1;
    for (var index = 1; index < completedDays.length; index++) {
      if (completedDays[index].difference(completedDays[index - 1]).inDays ==
          1) {
        current++;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  String _periodLabel() {
    if (_modoAgrupado) return 'Todo o histórico';
    final start = _weekStartFor(_selectedDate);
    final end = start.add(const Duration(days: 6));
    const months = [
      'jan.',
      'fev.',
      'mar.',
      'abr.',
      'mai.',
      'jun.',
      'jul.',
      'ago.',
      'set.',
      'out.',
      'nov.',
      'dez.',
    ];

    if (start.year != end.year) {
      return '${start.day} ${months[start.month - 1]} ${start.year} – '
          '${end.day} ${months[end.month - 1]} ${end.year}';
    }
    if (start.month != end.month) {
      return '${start.day} ${months[start.month - 1]} – '
          '${end.day} ${months[end.month - 1]} ${end.year}';
    }
    return '${start.day}–${end.day} ${months[end.month - 1]} ${end.year}';
  }

  String _actionableMessage({required int completed, required int total}) {
    if (total == 0) {
      return 'Ainda não há resultados nesta semana. Comece por uma atividade pequena.';
    }
    final rate = completed / total;
    if (completed == total) {
      return 'Semana perfeita até aqui. Mantenha o ritmo sem aumentar a carga.';
    }
    if (rate >= 0.75) {
      return 'Bom ritmo. Repita amanhã o que já funcionou nesta semana.';
    }
    if (rate >= 0.5) {
      return 'Você está no caminho. Priorize uma atividade essencial por vez.';
    }
    return 'A carga pode estar alta. Considere simplificar a próxima rotina.';
  }

  Map<int, Map<int, Map<int, List<Atividade>>>> _agruparPorAnoMesDia(
    List<Atividade> atividades,
  ) {
    final agrupado = <int, Map<int, Map<int, List<Atividade>>>>{};
    for (final atividade in atividades) {
      final ano = atividade.data.year;
      final mes = atividade.data.month;
      final dia = atividade.data.day;
      agrupado.putIfAbsent(ano, () => {});
      agrupado[ano]!.putIfAbsent(mes, () => {});
      agrupado[ano]![mes]!.putIfAbsent(dia, () => []);
      agrupado[ano]![mes]![dia]!.add(atividade);
    }
    return agrupado;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(appChangeProvider, (_, __) => _loadData());
    final navigationClearance = MediaQuery.paddingOf(context).bottom + 76.0;
    const listBottomPadding = 24.0;
    final hasInitialError =
        _loadError != null && _progressActivities.isEmpty && !_isLoading;
    final isInitialLoading = _isLoading && _progressActivities.isEmpty;

    return Scaffold(
      appBar: CustomAppBar(
        sectionTitle: Localizations.localeOf(context).languageCode == 'pt'
            ? 'Progresso'
            : 'Progress',
      ),
      body: AppBackground(
        child: Padding(
          padding: EdgeInsets.only(bottom: navigationClearance),
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  sliver: SliverToBoxAdapter(child: _buildPageHeader()),
                ),
                if (isInitialLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ProgressLoadingState(),
                  )
                else if (hasInitialError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ProgressErrorState(onRetry: _loadData),
                  )
                else ...[
                  if (_isLoading)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(minHeight: 2),
                    ),
                  if (_loadError != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      sliver: SliverToBoxAdapter(
                        child: _buildInlineError(),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    sliver: SliverToBoxAdapter(child: _buildProgressSummary()),
                  ),
                  if (!_modoAgrupado) ...[
                    SliverToBoxAdapter(
                      child: CalendarHeader(
                        selectedDate: _selectedDate,
                        onDateSelected: _onDateSelected,
                        atividades: _progressActivities,
                        showMonthYearPicker: true,
                        availableYears: _availableYears,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    sliver: SliverToBoxAdapter(child: _buildSectionHeader()),
                  ),
                  if (_atividades.isEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 20,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: EmptyStateCard(
                          icon: _modoAgrupado
                              ? Icons.insights_outlined
                              : Icons.event_available_outlined,
                          title: _modoAgrupado
                              ? 'Seu progresso aparecerá aqui'
                              : 'Sem resultados neste dia',
                        ),
                      ),
                    )
                  else if (_modoAgrupado)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverList.list(
                        children: _buildGroupedSections(),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: _atividades.length,
                      itemBuilder: (_, index) =>
                          _buildActivityCard(_atividades[index]),
                    ),
                  SliverToBoxAdapter(
                      child: SizedBox(height: listBottomPadding)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment<bool>(
            value: false,
            icon: Icon(Icons.today_outlined),
            label: Text('Por dia'),
          ),
          ButtonSegment<bool>(
            value: true,
            icon: Icon(Icons.view_agenda_outlined),
            label: Text('Agrupado'),
          ),
        ],
        selected: {_modoAgrupado},
        showSelectedIcon: false,
        expandedInsets: EdgeInsets.zero,
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.primaryContainer
                : scheme.surface.withValues(alpha: 0.78);
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant;
          }),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: scheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          textStyle: WidgetStatePropertyAll(
            theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        onSelectionChanged: (selection) {
          _changeMode(selection.first);
        },
      ),
    );
  }

  Widget _buildInlineError() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.sync_problem_outlined, color: scheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _loadError!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
            TextButton(
              onPressed: _loadData,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSummary() {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final weeklyActivities = _activitiesForWeek(_selectedDate);
    final periodActivities =
        _modoAgrupado ? _progressActivities : weeklyActivities;
    final completed = _completedCount(periodActivities);
    final total = periodActivities.length;
    final rate = total == 0 ? null : completed / total;
    final bestStreak = _bestCompletionStreak(_progressActivities);
    final useStackedMetrics = MediaQuery.textScalerOf(context).scale(14) > 18;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _modoAgrupado ? 'Visão geral' : 'Resumo da semana',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _periodLabel(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 280 || useStackedMetrics) {
                return Column(
                  children: [
                    _buildMetricTile(
                      icon: Icons.donut_large,
                      value: rate == null ? '—' : '${(rate * 100).round()}%',
                      label: 'Conclusão',
                      progress: rate,
                      horizontal: true,
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    _buildMetricTile(
                      icon: Icons.task_alt,
                      value: '$completed de $total',
                      label: 'Concluídas',
                      horizontal: true,
                    ),
                    Divider(height: 1, color: scheme.outlineVariant),
                    _buildMetricTile(
                      icon: Icons.local_fire_department_outlined,
                      value: '$bestStreak ${bestStreak == 1 ? 'dia' : 'dias'}',
                      label: 'Melhor sequência',
                      horizontal: true,
                    ),
                  ],
                );
              }

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.donut_large,
                        value: rate == null ? '—' : '${(rate * 100).round()}%',
                        label: 'Conclusão',
                        progress: rate,
                      ),
                    ),
                    VerticalDivider(
                      width: 12,
                      thickness: 1,
                      color: scheme.outlineVariant,
                    ),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.task_alt,
                        value: '$completed de $total',
                        label: 'Concluídas',
                      ),
                    ),
                    VerticalDivider(
                      width: 12,
                      thickness: 1,
                      color: scheme.outlineVariant,
                    ),
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.local_fire_department_outlined,
                        value:
                            '$bestStreak ${bestStreak == 1 ? 'dia' : 'dias'}',
                        label: 'Melhor sequência',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 17,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  _actionableMessage(
                    completed: _completedCount(weeklyActivities),
                    total: weeklyActivities.length,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          Divider(
            height: 24,
            color: scheme.outlineVariant.withValues(alpha: 0.75),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ritmo semanal',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Semana anterior',
                style: IconButton.styleFrom(
                  backgroundColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                  foregroundColor: scheme.onSurfaceVariant,
                ),
                onPressed: () => _shiftSelectedWeek(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Próxima semana',
                style: IconButton.styleFrom(
                  backgroundColor:
                      scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                  foregroundColor: scheme.onSurfaceVariant,
                ),
                onPressed: () => _shiftSelectedWeek(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildWeeklyHeatmap(weeklyActivities),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String value,
    required String label,
    double? progress,
    bool horizontal = false,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final iconVisual = Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: progress == null
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (progress != null)
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 2.5,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
            ),
          Icon(icon, size: 17, color: scheme.primary),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Padding(
          padding: horizontal
              ? const EdgeInsets.symmetric(vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: horizontal
              ? Row(
                  children: [
                    iconVisual,
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            value,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconVisual,
                    const SizedBox(height: 5),
                    Text(
                      value,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 28),
                      child: Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildWeeklyHeatmap(List<Atividade> weeklyActivities) {
    final start = _weekStartFor(_selectedDate);
    final dates = List.generate(7, (index) => start.add(Duration(days: index)));
    final localizations = MaterialLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        const minimumDayWidth = 48.0;
        final contentWidth = constraints.maxWidth < minimumDayWidth * 7
            ? minimumDayWidth * 7
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: contentWidth,
            child: Row(
              children: dates.map((date) {
                final activities = _activitiesForDay(weeklyActivities, date);
                final completed = _completedCount(activities);
                final total = activities.length;
                final rate = total == 0 ? null : completed / total;
                return Expanded(
                  child: _buildHeatmapDay(
                    date: date,
                    dayLabel: localizations.narrowWeekdays[date.weekday % 7],
                    completed: completed,
                    total: total,
                    rate: rate,
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeatmapDay({
    required DateTime date,
    required String dayLabel,
    required int completed,
    required int total,
    required double? rate,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = _isSameDay(date, _selectedDate);
    final Color fillColor;
    final Color foregroundColor;
    if (rate == null) {
      fillColor = scheme.surfaceContainerHighest.withValues(alpha: 0.52);
      foregroundColor = scheme.onSurfaceVariant;
    } else if (rate >= 0.75) {
      fillColor = scheme.primary;
      foregroundColor = scheme.onPrimary;
    } else if (rate >= 0.5) {
      fillColor = scheme.primaryContainer;
      foregroundColor = scheme.onPrimaryContainer;
    } else if (rate > 0) {
      fillColor = scheme.tertiaryContainer;
      foregroundColor = scheme.onTertiaryContainer;
    } else {
      fillColor = scheme.errorContainer;
      foregroundColor = scheme.onErrorContainer;
    }

    final semanticsResult =
        total == 0 ? 'sem resultados' : '$completed de $total concluídas';
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$dayLabel, dia ${date.day}, $semanticsResult',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectDayFromProgress(date),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Text(
                  dayLabel.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: fillColor,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: isSelected ? scheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '${date.day}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foregroundColor,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  total == 0 ? '—' : '$completed/$total',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    final theme = Theme.of(context);
    final label = _modoAgrupado
        ? 'Linha do tempo'
        : MaterialLocalizations.of(context).formatMediumDate(_selectedDate);
    return Row(
      children: [
        Expanded(
          child: Text(label, style: theme.textTheme.titleMedium),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_atividades.length}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityCard(Atividade atividade) {
    return AtividadeCard(
      atividade: atividade,
      onEditar: null,
      onToggleConcluida: _loadData,
      onCancelar: (_) => _loadData(),
      onExcluir: _loadData,
      historico: true,
      showParticipants: _canUseCollaborativeFeatures,
      onReutilizar: () => _reutilizarAtividade(atividade),
    );
  }

  String _outcomeSummary(Iterable<Atividade> atividades) {
    final list = atividades.toList();
    final completed = _completedCount(list);
    if (list.isEmpty) return 'Sem resultados';
    final rate = (completed / list.length * 100).round();
    return '$completed de ${list.length} concluídas • $rate%';
  }

  List<Widget> _buildGroupedSections() {
    final grouped = _agruparPorAnoMesDia(_atividades);
    final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    final localizations = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return [
      for (var yearIndex = 0; yearIndex < years.length; yearIndex++) ...[
        Builder(
          builder: (context) {
            final year = years[yearIndex];
            final months = grouped[year]!;
            final yearActivities = months.values
                .expand((days) => days.values)
                .expand((activities) => activities)
                .toList();
            final monthKeys = months.keys.toList()
              ..sort((a, b) => b.compareTo(a));
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: scheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: PageStorageKey<String>('progress-year-$year'),
                initiallyExpanded: yearIndex == 0,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text('$year'),
                subtitle: Text(_outcomeSummary(yearActivities)),
                children: [
                  for (final month in monthKeys)
                    Builder(
                      builder: (context) {
                        final days = months[month]!;
                        final monthActivities = days.values
                            .expand((activities) => activities)
                            .toList();
                        final dayKeys = days.keys.toList()
                          ..sort((a, b) => b.compareTo(a));
                        return ExpansionTile(
                          key: PageStorageKey<String>(
                            'progress-month-$year-$month',
                          ),
                          title: Text(
                            localizations.formatMonthYear(
                              DateTime(year, month),
                            ),
                          ),
                          subtitle: Text(_outcomeSummary(monthActivities)),
                          children: [
                            for (final day in dayKeys)
                              Builder(
                                builder: (context) {
                                  final activities = days[day]!
                                    ..sort(_compareActivitiesByDateAndTime);
                                  final date = DateTime(year, month, day);
                                  return ExpansionTile(
                                    key: PageStorageKey<String>(
                                      'progress-day-$year-$month-$day',
                                    ),
                                    title: Text(
                                      localizations.formatMediumDate(date),
                                    ),
                                    subtitle: Text(
                                      _outcomeSummary(activities),
                                    ),
                                    children: activities
                                        .map(_buildActivityCard)
                                        .toList(),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ],
    ];
  }
}

class _ProgressLoadingState extends StatelessWidget {
  const _ProgressLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Preparando seu progresso…',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressErrorState extends StatelessWidget {
  const _ProgressErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: scheme.error),
            const SizedBox(height: 14),
            Text(
              'Não foi possível carregar seu progresso',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Tente novamente para recuperar o histórico e as métricas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
