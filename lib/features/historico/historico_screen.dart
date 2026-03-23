import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/atividades/atividade_card.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/historico/calendario_historico.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart';
import 'package:routine/widgets/custom_appbar.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  DateTime _selectedDate = DateTime.now();
  List<Atividade> _atividades = [];
  List<String> _availableYears = [];
  bool _isLoading = true;
  bool _modoAgrupado = false;
  String _currentPlan = PlanRules.gratis;

  bool get _canUseCollaborativeFeatures =>
      PlanRules.hasFullAccess(_currentPlan);

  int _compareTimeOfDay(TimeOfDay a, TimeOfDay b) {
    final hourCompare = a.hour.compareTo(b.hour);
    if (hourCompare != 0) return hourCompare;
    return a.minute.compareTo(b.minute);
  }

  int _compareActivitiesByDateAndTime(Atividade a, Atividade b) {
    final dateA = DateTime(a.data.year, a.data.month, a.data.day);
    final dateB = DateTime(b.data.year, b.data.month, b.data.day);
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
    if (rawFields is Map) {
      return Map<String, dynamic>.from(rawFields);
    }
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
    final date = DateTime(
      atividade.data.year,
      atividade.data.month,
      atividade.data.day,
    );
    return '${atividade.id}-${date.millisecondsSinceEpoch}';
  }

  Future<List<Atividade>> _loadHistoricalEditedOccurrences({
    DateTime? onlyDay,
  }) async {
    final exceptions = onlyDay == null
        ? await DB.instance.getAllActivityExceptions()
        : await DB.instance.getActivityExceptionsForDay(onlyDay);
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
        cache[activityId] =
            baseMap == null ? null : Atividade.fromMap(baseMap);
      }
      final base = cache[activityId];
      if (base == null) continue;

      DateTime date = DateTime(base.data.year, base.data.month, base.data.day);
      final rawDate = exception['data'];
      if (rawDate is int) {
        final resolved = DateTime.fromMillisecondsSinceEpoch(rawDate);
        date = DateTime(resolved.year, resolved.month, resolved.day);
      } else if (rawDate is String) {
        final millis = int.tryParse(rawDate);
        if (millis != null) {
          final resolved = DateTime.fromMillisecondsSinceEpoch(millis);
          date = DateTime(resolved.year, resolved.month, resolved.day);
        }
      } else if (onlyDay != null) {
        date = DateTime(onlyDay.year, onlyDay.month, onlyDay.day);
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

    final result = merged.values.toList()
      ..sort(_compareActivitiesByDateAndTime);
    return result;
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
    return ordered.map((y) => y.toString()).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    mergedChange.addListener(_onMergedChange);
    planChangeNotifier.addListener(_onPlanChanged);
  }

  @override
  void dispose() {
    mergedChange.removeListener(_onMergedChange);
    planChangeNotifier.removeListener(_onPlanChanged);
    super.dispose();
  }

  void _onMergedChange() {
    _loadData();
  }

  void _onPlanChanged() {
    _loadData();
  }

  Future<void> _loadData({DateTime? date}) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final filtroData = date ?? _selectedDate;
      final userMap = await DB.instance.getUser();
      final currentPlan =
          PlanRules.normalize(userMap?['typeAccount']?.toString());
      final List<Map<String, dynamic>> activities;
      if (_modoAgrupado) {
        activities = await DB.instance.getActivitiesByStatus(
          status: [AtividadeStatus.cancelada, AtividadeStatus.concluida],
        );
      } else {
        activities = await DB.instance.getAllActivities(
          year: filtroData.year,
          month: filtroData.month,
          day: filtroData.day,
          status: [AtividadeStatus.cancelada, AtividadeStatus.concluida],
        );
      }

      final baseAtividades = activities.map(Atividade.fromMap).toList();
      final editedOccurrences = await _loadHistoricalEditedOccurrences(
        onlyDay: _modoAgrupado ? null : filtroData,
      );
      final listaAtividades = _mergeHistoricalActivities(
        baseAtividades,
        editedOccurrences,
      );
      final years = _mergeAvailableYears(
        dbYears: await DB.instance.getAllActivityYears(),
        atividades: listaAtividades,
      );

      if (!mounted) return;
      setState(() {
        _atividades = listaAtividades;
        _availableYears = years;
        _currentPlan = currentPlan;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar dados')),
      );
    }
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _isLoading = true;
    });
    await _loadData(date: date);
  }

  Map<int, Map<int, Map<int, List<Atividade>>>> _agruparPorAnoMesDia(
    List<Atividade> atividades,
  ) {
    final agrupado = <int, Map<int, Map<int, List<Atividade>>>>{};
    for (final a in atividades) {
      final ano = a.data.year;
      final mes = a.data.month;
      final dia = a.data.day;
      agrupado.putIfAbsent(ano, () => {});
      agrupado[ano]!.putIfAbsent(mes, () => {});
      agrupado[ano]![mes]!.putIfAbsent(dia, () => []);
      agrupado[ano]![mes]![dia]!.add(a);
    }
    return agrupado;
  }

  @override
  Widget build(BuildContext context) {
    final listBottomPadding = MediaQuery.paddingOf(context).bottom + 96.0;

    final atividadesDoDia = _atividades.where((a) {
      final activityDate = DateTime(a.data.year, a.data.month, a.data.day);
      return activityDate.year == _selectedDate.year &&
          activityDate.month == _selectedDate.month &&
          activityDate.day == _selectedDate.day;
    }).toList();

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
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _modoAgrupado ? 'Visão agrupada' : 'Visão por dia',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Switch(
                      value: _modoAgrupado,
                      onChanged: (v) async {
                        setState(() {
                          _modoAgrupado = v;
                        });
                        await _loadData();
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (!_modoAgrupado)
              CalendarHeaderHistory(
                selectedDate: _selectedDate,
                onDateSelected: _onDateSelected,
                atividades: atividadesDoDia,
                availableYears: _availableYears,
              ),
            if (!_modoAgrupado) const SizedBox(height: 12),
            if (!_modoAgrupado) const Divider(height: 2),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _modoAgrupado
                      ? _buildAgrupado(bottomPadding: listBottomPadding)
                      : atividadesDoDia.isEmpty
                          ? Center(
                              child: Text(
                                'Sem atividades para este dia',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                0,
                                8,
                                0,
                                listBottomPadding,
                              ),
                              itemCount: atividadesDoDia.length,
                              itemBuilder: (_, i) {
                                final ativ = atividadesDoDia[i];
                                return AtividadeCard(
                                  atividade: ativ,
                                  onEditar: null,
                                  onToggleConcluida: () =>
                                      _loadData(date: _selectedDate),
                                  onCancelar: (_) =>
                                      _loadData(date: _selectedDate),
                                  onExcluir: () =>
                                      _loadData(date: _selectedDate),
                                  historico: true,
                                  showParticipants:
                                      _canUseCollaborativeFeatures,
                                  onReutilizar: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text('Reutilizar: ${ativ.titulo}'),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgrupado({required double bottomPadding}) {
    final agrupado = _agruparPorAnoMesDia(_atividades);
    if (agrupado.isEmpty) {
      return const Center(child: Text('Sem atividades no histórico'));
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(0, 8, 0, bottomPadding),
      children: agrupado.entries.map((anoEntry) {
        final ano = anoEntry.key;
        final meses = anoEntry.value;
        return ExpansionTile(
          title: Text('$ano'),
          children: meses.entries.map((mesEntry) {
            final mes = mesEntry.key;
            final dias = mesEntry.value;
            return ExpansionTile(
              title: Text('Mês: $mes'),
              children: dias.entries.map((diaEntry) {
                final dia = diaEntry.key;
                final atividadesDia = diaEntry.value;
                return ExpansionTile(
                  title: Text('Dia: $dia'),
                  children: atividadesDia
                      .map(
                        (ativ) => AtividadeCard(
                          atividade: ativ,
                          historico: true,
                          onToggleConcluida: _loadData,
                          onCancelar: (_) => _loadData(),
                          onExcluir: _loadData,
                          onEditar: null,
                          showParticipants: _canUseCollaborativeFeatures,
                          onReutilizar: () {},
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}
