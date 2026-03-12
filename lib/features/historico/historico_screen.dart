import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/atividades/atividade_card.dart';
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

  @override
  void initState() {
    super.initState();
    _loadData();
    mergedChange.addListener(_onMergedChange);
  }

  @override
  void dispose() {
    mergedChange.removeListener(_onMergedChange);
    super.dispose();
  }

  void _onMergedChange() {
    if (mergedChange.value) {
      _loadData();
      mergedChange.reset();
    }
  }

  Future<void> _loadData({DateTime? date}) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final filtroData = date ?? _selectedDate;
      final List<Map<String, dynamic>> activities;
      if (_modoAgrupado) {
        activities = await DB.instance.getActivitiesByStatus(
          status: ['Cancelada', 'Concluida', 'Concluída'],
        );
      } else {
        activities = await DB.instance.getAllActivities(
          year: filtroData.year,
          month: filtroData.month,
          day: filtroData.day,
          status: ['Cancelada', 'Concluida', 'Concluída'],
        );
      }

      final listaAtividades =
          activities.map((map) => Atividade.fromMap(map)).toList();
      final years = await DB.instance.getAllActivityYears();

      if (!mounted) return;

      setState(() {
        _atividades = listaAtividades;
        _availableYears = years;
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
    final atividadesDoDia = _atividades.where((a) {
      final activityDate = DateTime(a.data.year, a.data.month, a.data.day);
      return activityDate.year == _selectedDate.year &&
          activityDate.month == _selectedDate.month &&
          activityDate.day == _selectedDate.day;
    }).toList();

    return Scaffold(
      appBar: CustomAppBar(),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(_modoAgrupado ? 'Agrupado' : 'Por Dia'),
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
          if (!_modoAgrupado)
            CalendarHeaderHistory(
              selectedDate: _selectedDate,
              onDateSelected: (date) => _onDateSelected(date),
              atividades: atividadesDoDia,
              availableYears: _availableYears,
            ),
          if (!_modoAgrupado) const SizedBox(height: 12),
          if (!_modoAgrupado) const Divider(height: 2),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _modoAgrupado
                    ? _buildAgrupado()
                    : atividadesDoDia.isEmpty
                        ? const Center(child: Text('Sem atividades para este dia'))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: atividadesDoDia.length,
                            itemBuilder: (_, i) {
                              final ativ = atividadesDoDia[i];
                              return AtividadeCard(
                                atividade: ativ,
                                onEditar: null,
                                onToggleConcluida: () => _loadData(date: _selectedDate),
                                onCancelar: () => _loadData(date: _selectedDate),
                                onExcluir: () => _loadData(date: _selectedDate),
                                historico: true,
                                onReutilizar: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Reutilizar: ${ativ.titulo}')),
                                  );
                                },
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgrupado() {
    final agrupado = _agruparPorAnoMesDia(_atividades);
    if (agrupado.isEmpty) {
      return const Center(child: Text('Sem atividades no historico'));
    }
    return ListView(
      children: agrupado.entries.map((anoEntry) {
        final ano = anoEntry.key;
        final meses = anoEntry.value;
        return ExpansionTile(
          title: Text('$ano'),
          children: meses.entries.map((mesEntry) {
            final mes = mesEntry.key;
            final dias = mesEntry.value;
            return ExpansionTile(
              title: Text('Mes: $mes'),
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
                          onToggleConcluida: () => _loadData(),
                          onCancelar: () => _loadData(),
                          onExcluir: () => _loadData(),
                          onEditar: null,
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

