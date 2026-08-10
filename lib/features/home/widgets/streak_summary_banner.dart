import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/repositories/streak_repository.dart';
import 'package:routine/theme/app_semantic_colors.dart';

/// Resumo de sequências de hábito ativas entre as atividades recorrentes
/// visíveis no dia selecionado da Home.
class StreakSummaryBanner extends StatefulWidget {
  const StreakSummaryBanner({super.key, required this.atividades});

  final List<Atividade> atividades;

  @override
  State<StreakSummaryBanner> createState() => _StreakSummaryBannerState();
}

class _StreakSummaryBannerState extends State<StreakSummaryBanner> {
  final _repository = StreakRepository();
  int _activeCount = 0;
  int _bestOverall = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant StreakSummaryBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    final recorrentes =
        widget.atividades.where((a) => a.repetirSemanalmente).toList();
    if (recorrentes.isEmpty) {
      if (!mounted) return;
      setState(() {
        _activeCount = 0;
        _bestOverall = 0;
        _loading = false;
      });
      return;
    }

    final streaks =
        await Future.wait(recorrentes.map(_repository.streakForActivity));
    if (!mounted) return;
    setState(() {
      _activeCount = streaks.where((s) => s.current > 0).length;
      _bestOverall = streaks.fold<int>(
          0, (acc, s) => s.best > acc ? s.best : acc);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _activeCount == 0) return const SizedBox.shrink();
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: semantic.warningContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.local_fire_department, color: semantic.warning, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$_activeCount hábito${_activeCount == 1 ? '' : 's'} em sequência'
              '${_bestOverall > 0 ? ' • recorde: $_bestOverall dias' : ''}',
              style: TextStyle(
                color: semantic.onWarningContainer,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
