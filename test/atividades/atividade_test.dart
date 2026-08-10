import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine/atividades/atividade.dart';

void main() {
  Atividade makeAtividade({List<int> reminderMinutes = const []}) {
    return Atividade(
      id: 1,
      titulo: 'Academia',
      descricao: '',
      data: DateTime(2026, 1, 10),
      horaInicio: const TimeOfDay(hour: 9, minute: 0),
      horaFim: const TimeOfDay(hour: 10, minute: 0),
      status: AtividadeStatus.pendente,
      participantes: const [],
      reminderMinutes: reminderMinutes,
    );
  }

  group('Atividade.reminderMinutes', () {
    test('defaults to empty (usa o padrão global)', () {
      final atividade = makeAtividade();
      expect(atividade.reminderMinutes, isEmpty);
    });

    test('toMap/fromMap round-trip preserva múltiplos lembretes', () {
      final atividade = makeAtividade(reminderMinutes: [10, 60, 1440]);
      final map = atividade.toMap();
      expect(map['reminder_minutes'], '10,60,1440');

      final restored = Atividade.fromMap({...map, 'id': 1});
      expect(restored.reminderMinutes, [10, 60, 1440]);
    });

    test('fromMap trata coluna nula/vazia como lista vazia', () {
      final map = makeAtividade().toMap()
        ..['id'] = 1
        ..remove('reminder_minutes');
      expect(Atividade.fromMap(map).reminderMinutes, isEmpty);

      final mapVazio = {...map, 'reminder_minutes': ''};
      expect(Atividade.fromMap(mapVazio).reminderMinutes, isEmpty);
    });

    test('copyWith troca só os lembretes quando pedido', () {
      final original = makeAtividade(reminderMinutes: [10]);
      final atualizada = original.copyWith(reminderMinutes: [30, 60]);
      expect(atualizada.reminderMinutes, [30, 60]);
      expect(atualizada.titulo, original.titulo);

      final semMudanca = original.copyWith(titulo: 'Outro nome');
      expect(semMudanca.reminderMinutes, [10]);
    });
  });
}
