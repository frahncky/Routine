import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';

/// Resumo operacional do dia: progresso e próxima ação em um único bloco.
class DailyFocusCard extends StatefulWidget {
  const DailyFocusCard({
    super.key,
    required this.atividades,
    required this.selectedDate,
    required this.onOpenActivity,
    required this.onCompleteActivity,
  });

  final List<Atividade> atividades;
  final DateTime selectedDate;
  final ValueChanged<Atividade> onOpenActivity;
  final Future<void> Function(Atividade) onCompleteActivity;

  @override
  State<DailyFocusCard> createState() => _DailyFocusCardState();
}

class _DailyFocusCardState extends State<DailyFocusCard> {
  int? _completingActivityId;

  bool _isToday(DateTime date) => DateUtils.isSameDay(date, DateTime.now());

  int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;

  Atividade? _focusActivity(List<Atividade> pending) {
    if (pending.isEmpty) return null;
    if (!_isToday(widget.selectedDate)) return pending.first;

    final now = TimeOfDay.now();
    final currentMinutes = _minutes(now);
    for (final atividade in pending) {
      final start = _minutes(atividade.horaInicio);
      final end = _minutes(atividade.horaFim);
      if (currentMinutes >= start && currentMinutes <= end) return atividade;
    }
    for (final atividade in pending) {
      if (_minutes(atividade.horaInicio) > currentMinutes) return atividade;
    }
    return pending.first;
  }

  String _focusLabel(Atividade atividade) {
    if (!_isToday(widget.selectedDate)) return 'A seguir';
    final now = _minutes(TimeOfDay.now());
    final start = _minutes(atividade.horaInicio);
    final end = _minutes(atividade.horaFim);
    if (now >= start && now <= end) return 'Agora';
    if (now < start) return 'Próxima';
    return 'Pendente';
  }

  String _dayLabel() {
    if (_isToday(widget.selectedDate)) return 'Hoje';
    final formatted = DateFormat("EEE, d 'de' MMM", 'pt_BR')
        .format(widget.selectedDate)
        .replaceAll('.', '');
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  Future<void> _complete(Atividade atividade) async {
    if (_completingActivityId != null) return;
    setState(() => _completingActivityId = atividade.id);
    try {
      await widget.onCompleteActivity(atividade);
    } finally {
      if (mounted) setState(() => _completingActivityId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final relevant = widget.atividades.where((atividade) {
      return AtividadeStatus.normalize(atividade.status) !=
          AtividadeStatus.cancelada;
    }).toList();
    if (relevant.isEmpty) return const SizedBox.shrink();

    final completed = relevant.where((atividade) {
      return AtividadeStatus.normalize(atividade.status) ==
          AtividadeStatus.concluida;
    }).length;
    final pending = relevant.where((atividade) {
      return AtividadeStatus.normalize(atividade.status) !=
          AtividadeStatus.concluida;
    }).toList();
    final focus = _focusActivity(pending);
    final progress = completed / relevant.length;

    return Semantics(
      container: true,
      label:
          '${_dayLabel()}. $completed de ${relevant.length} atividades concluídas.',
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              Color.alphaBlend(
                scheme.secondary.withValues(alpha: 0.28),
                scheme.primary,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 21,
                    color: scheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FOCO DO DIA',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimary.withValues(alpha: 0.72),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.1,
                            ),
                      ),
                      Text(
                        _dayLabel(),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.onPrimary.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$completed de ${relevant.length}',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: scheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: scheme.onPrimary.withValues(alpha: 0.16),
                color: scheme.onPrimary,
                semanticsLabel: 'Progresso das atividades do dia',
                semanticsValue: '${(progress * 100).round()}',
              ),
            ),
            const SizedBox(height: 10),
            if (focus == null)
              Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: scheme.onPrimary.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: scheme.onPrimary.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.task_alt_rounded,
                        size: 21,
                        color: scheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Tudo concluído por aqui.',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Material(
                color: scheme.onPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => widget.onOpenActivity(focus),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 64),
                    padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.onPrimary.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _focusLabel(focus),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                focus.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: scheme.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                '${focus.horaInicio.format(context)} – ${focus.horaFim.format(context)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: scheme.onPrimary
                                          .withValues(alpha: 0.72),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          label: 'Concluir ${focus.titulo}',
                          child: IconButton(
                            tooltip: 'Marcar como concluída',
                            onPressed: _completingActivityId == focus.id
                                ? null
                                : () => _complete(focus),
                            style: IconButton.styleFrom(
                              backgroundColor: scheme.onPrimary,
                              foregroundColor: scheme.primary,
                              disabledBackgroundColor:
                                  scheme.onPrimary.withValues(alpha: 0.48),
                              minimumSize: const Size.square(48),
                            ),
                            icon: _completingActivityId == focus.id
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.check_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
