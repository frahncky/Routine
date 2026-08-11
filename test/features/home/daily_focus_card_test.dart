import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/features/home/widgets/daily_focus_card.dart';

Atividade _activity({
  required int id,
  required String title,
  required String status,
}) {
  return Atividade(
    id: id,
    titulo: title,
    descricao: '',
    data: DateTime.now(),
    horaInicio: const TimeOfDay(hour: 8, minute: 0),
    horaFim: const TimeOfDay(hour: 9, minute: 0),
    status: status,
    participantes: const [],
  );
}

void main() {
  testWidgets('shows daily progress and completes the focused activity',
      (tester) async {
    Atividade? completedActivity;
    final activities = [
      _activity(
        id: 1,
        title: 'Alongamento',
        status: AtividadeStatus.concluida,
      ),
      _activity(
        id: 2,
        title: 'Caminhada',
        status: AtividadeStatus.pendente,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyFocusCard(
            atividades: activities,
            selectedDate: DateTime.now(),
            onOpenActivity: (_) {},
            onCompleteActivity: (activity) async {
              completedActivity = activity;
            },
          ),
        ),
      ),
    );

    expect(find.text('Hoje'), findsOneWidget);
    expect(find.text('1 de 2'), findsOneWidget);
    expect(find.text('Caminhada'), findsOneWidget);

    await tester.tap(find.byTooltip('Marcar como concluída'));
    await tester.pumpAndSettle();

    expect(completedActivity?.id, 2);
  });

  testWidgets('celebrates when every activity is complete', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyFocusCard(
            atividades: [
              _activity(
                id: 1,
                title: 'Leitura',
                status: AtividadeStatus.concluida,
              ),
            ],
            selectedDate: DateTime.now(),
            onOpenActivity: (_) {},
            onCompleteActivity: (_) async {},
          ),
        ),
      ),
    );

    expect(find.text('1 de 1'), findsOneWidget);
    expect(find.text('Tudo concluído por aqui.'), findsOneWidget);
  });
}
