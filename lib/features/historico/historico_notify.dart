import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/helper/database_helper.dart';


class HistoricoAtividadesNotifier extends ChangeNotifier {
  List<Atividade> _atividadesDoDia = [];
  List<String> _availableYears = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  List<Atividade> get atividadesDoDia => _atividadesDoDia;
  List<String> get availableYears => _availableYears;
  bool get isLoading => _isLoading;
  DateTime get selectedDate => _selectedDate;

  Future<void> loadData({DateTime? date}) async {
    _isLoading = true;
    notifyListeners();
    final filtroData = date ?? _selectedDate;
    try {
      final activities = await DB.instance.getAllActivities(
        year: filtroData.year,
        month: filtroData.month,
        day: filtroData.day,
        status: ['Cancelada', 'Concluida', 'Concluída'],
      );
      _atividadesDoDia = activities.map((map) => Atividade.fromMap(map)).toList();
      _availableYears = await DB.instance.getAllActivityYears();
    } catch (e) {
      _atividadesDoDia = [];
      // LÃ³gica de tratamento de erro
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void onDateSelected(DateTime date) {
    _selectedDate = date;
    loadData(date: date);
  }

  // MÃ©todo para recarregar os dados (chamado pelo mergedChange)
  Future<void> refreshData() async {
    await loadData(date: _selectedDate);
  }
}
