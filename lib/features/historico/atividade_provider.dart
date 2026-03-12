import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/helper/database_helper.dart';

class AtividadesProvider with ChangeNotifier {
  List<Atividade> _atividades = [];

  List<Atividade> get atividades => _atividades;

  Future<void> carregarAtividades({
    required int year,
    required int month,
    required int day,
  }) async {
    final activities = await DB.instance.getAllActivities(
      year: year,
      month: month,
      day: day,
      status: [AtividadeStatus.cancelada, AtividadeStatus.concluida],
    );
    _atividades = activities.map((map) => Atividade.fromMap(map)).toList();
    notifyListeners();
  }

  Future<void> atualizar() async {
    // Carrega tudo de novo baseado na lÃ³gica que quiser
    notifyListeners();
  }
}

