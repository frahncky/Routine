import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routine/l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/atividades/atividade_status_colors.dart';
import 'package:routine/atividades/streak_calculator.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/repositories/streak_repository.dart';
import 'package:routine/theme/app_semantic_colors.dart';
import 'package:routine/widgets/confirm_dialog.dart';
import 'package:routine/widgets/empty_state_card.dart';
import 'package:routine/widgets/show_snackbar.dart';

class AtividadeCard extends ConsumerStatefulWidget {
  const AtividadeCard({
    super.key,
    required this.atividade,
    this.onEditar,
    this.onExcluir,
    this.onToggleConcluida,
    this.onReutilizar,
    this.historico = false,
    this.onCancelar,
    this.showParticipants = true,
  });

  final Atividade atividade;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;
  final Future<void> Function()? onToggleConcluida;
  final VoidCallback? onReutilizar;
  final bool historico;
  final ValueChanged<Atividade>? onCancelar;
  final bool showParticipants;

  @override
  ConsumerState<AtividadeCard> createState() => _AtividadeCardState();
}

class _AtividadeCardState extends ConsumerState<AtividadeCard>
    with AutomaticKeepAliveClientMixin {
  bool _expandido = false;
  late String _status;
  late IconData _statusIcon;
  String? _localStatusOverride;
  final _dateFormat = DateFormat('dd/MM/yyyy');
  String? _currentUserEmail;
  bool _updatingMyPresence = false;
  final _streakRepository = StreakRepository();
  HabitStreak? _streak;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _updateStatus();
    _loadCurrentUserEmail();
    _loadStreak();
  }

  @override
  void didUpdateWidget(covariant AtividadeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atividade.status != widget.atividade.status) {
      _localStatusOverride = null;
    }
    _updateStatus();
    if (widget.atividade.repetirSemanalmente) _loadStreak();
  }

  Future<void> _loadStreak() async {
    if (!widget.atividade.repetirSemanalmente) return;
    final streak = await _streakRepository.streakForActivity(widget.atividade);
    if (!mounted) return;
    setState(() => _streak = streak);
  }

  Future<void> _loadCurrentUserEmail() async {
    final email =
        (await DB.instance.getEmailFromDB() ?? '').trim().toLowerCase();
    if (!mounted) return;
    setState(() {
      _currentUserEmail = email;
    });
  }

  void _updateStatus() {
    _status = _determinarStatus(widget.atividade, override: _localStatusOverride);
    _statusIcon = _iconePorStatus(_status);
  }

  static String _determinarStatus(Atividade atividade, {String? override}) {
    final normalized = AtividadeStatus.normalize(override ?? atividade.status);
    if (normalized == AtividadeStatus.cancelada) {
      return AtividadeStatus.cancelada;
    }
    if (normalized == AtividadeStatus.concluida) {
      return AtividadeStatus.concluida;
    }

    final agora = TimeOfDay.now();
    final hoje = DateTime.now();
    final mesmaData = atividade.data.year == hoje.year &&
        atividade.data.month == hoje.month &&
        atividade.data.day == hoje.day;
    if (!mesmaData) return AtividadeStatus.pendente;

    final inicio = atividade.horaInicio;
    final fim = atividade.horaFim;
    if (agora.hour < inicio.hour ||
        (agora.hour == inicio.hour && agora.minute < inicio.minute)) {
      return AtividadeStatus.pendente;
    }
    if (agora.hour > fim.hour ||
        (agora.hour == fim.hour && agora.minute > fim.minute)) {
      return AtividadeStatus.atrasada;
    }
    return AtividadeStatus.andamento;
  }

  static IconData _iconePorStatus(String status) {
    switch (status) {
      case AtividadeStatus.concluida:
        return Icons.check_circle;
      case AtividadeStatus.andamento:
        return Icons.timelapse;
      case AtividadeStatus.atrasada:
        return Icons.error;
      case AtividadeStatus.cancelada:
        return Icons.cancel;
      default:
        return Icons.hourglass_bottom;
    }
  }

  IconData _iconeStatusParticipante(String status) {
    switch (ParticipanteStatus.normalize(status)) {
      case ParticipanteStatus.aceito:
        return Icons.check;
      case ParticipanteStatus.recusado:
        return Icons.close;
      case ParticipanteStatus.atrasado:
        return Icons.schedule;
      default:
        return Icons.hourglass_empty;
    }
  }

  Color _corStatusParticipante(String status) {
    return Theme.of(context).extension<AppSemanticColors>()!.forParticipanteStatus(status);
  }

  String _statusParticipanteLabel(Participante participante) {
    final normalized = ParticipanteStatus.normalize(participante.status);
    switch (normalized) {
      case ParticipanteStatus.aceito:
        return 'Confirmado';
      case ParticipanteStatus.recusado:
        return 'Cancelou';
      case ParticipanteStatus.atrasado:
        final minutes = participante.atrasoMinutos ?? 0;
        return minutes > 0 ? 'Atraso de $minutes min' : 'Atrasado';
      default:
        return 'Pendente';
    }
  }

  Participante? _meAsParticipant() {
    final email = _currentUserEmail;
    if (email == null || email.isEmpty) return null;
    for (final participant in widget.atividade.participantes) {
      if (participant.email.trim().toLowerCase() == email) {
        return participant;
      }
    }
    return null;
  }

  Widget _buildParticipantAvatar(
    Participante participante, {
    double radius = 16,
  }) {
    final trimmedName = participante.nome.trim();
    final initial = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();
    final normalized = ParticipanteStatus.normalize(participante.status);
    final color = _corStatusParticipante(normalized);
    final icon = _iconeStatusParticipante(normalized);

    Widget badge;
    if (normalized == ParticipanteStatus.atrasado &&
        (participante.atrasoMinutos ?? 0) > 0) {
      final minutes = participante.atrasoMinutos!;
      final label = minutes > 99 ? '99+' : '+$minutes';
      badge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
      );
    } else {
      badge = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.2),
        ),
        child: Icon(icon, color: Colors.white, size: 12),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundImage: participante.fotoUrl != null
              ? NetworkImage(participante.fotoUrl!)
              : null,
          child: participante.fotoUrl == null ? Text(initial) : null,
        ),
        Positioned(
          right: -3,
          bottom: -2,
          child: badge,
        ),
      ],
    );
  }

  Future<int?> _askDelayMinutes() async {
    final controller = TextEditingController();
    String? errorMessage;

    final result = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Informar atraso'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Minutos de atraso',
                    hintText: 'Ex: 15',
                  ),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final minutes = int.tryParse(controller.text.trim());
                if (minutes == null || minutes <= 0) {
                  setDialogState(
                    () => errorMessage = 'Informe um valor maior que zero.',
                  );
                  return;
                }
                Navigator.of(context).pop(minutes);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    return result;
  }

  Future<void> _refreshParticipantsFromDatabase() async {
    final updatedMap = await DB.instance.getActivityById(widget.atividade.id);
    if (!mounted) return;
    if (updatedMap == null) {
      setState(() => _updatingMyPresence = false);
      return;
    }

    final updatedActivity = Atividade.fromMap(updatedMap);
    setState(() {
      widget.atividade.participantes
        ..clear()
        ..addAll(updatedActivity.participantes);
      _updatingMyPresence = false;
    });
    ref.read(appChangeProvider.notifier).state++;
  }

  Future<void> _updateMyParticipationStatus({
    required String status,
    int? delayMinutes,
  }) async {
    final email = _currentUserEmail;
    if (email == null || email.isEmpty) return;
    if (_updatingMyPresence) return;

    setState(() => _updatingMyPresence = true);
    final success = await DB.instance.updateParticipantPresence(
      activityId: widget.atividade.id,
      participantEmail: email,
      status: status,
      delayMinutes: delayMinutes,
    );

    if (!success) {
      if (!mounted) return;
      setState(() => _updatingMyPresence = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível atualizar sua participação.'),
        ),
      );
      return;
    }

    await _refreshParticipantsFromDatabase();
  }

  Future<void> _openMyParticipationSheet() async {
    if (_updatingMyPresence) return;
    final me = _meAsParticipant();
    if (me == null) return;

    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final selectedAction = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.check_circle, color: semantic.success),
              title: const Text('Vou participar'),
              onTap: () => Navigator.of(context).pop(ParticipanteStatus.aceito),
            ),
            ListTile(
              leading: Icon(Icons.cancel, color: semantic.danger),
              title: const Text('Cancelar participação'),
              onTap: () =>
                  Navigator.of(context).pop(ParticipanteStatus.recusado),
            ),
            ListTile(
              leading: Icon(Icons.schedule, color: semantic.warning),
              title: const Text('Vou atrasar'),
              onTap: () =>
                  Navigator.of(context).pop(ParticipanteStatus.atrasado),
            ),
          ],
        ),
      ),
    );

    if (!mounted || selectedAction == null) return;
    if (selectedAction == ParticipanteStatus.atrasado) {
      final delayMinutes = await _askDelayMinutes();
      if (delayMinutes == null) return;
      await _updateMyParticipationStatus(
        status: ParticipanteStatus.atrasado,
        delayMinutes: delayMinutes,
      );
      return;
    }

    await _updateMyParticipationStatus(status: selectedAction);
  }

  Future<void> _marcarComoConcluida() async {
    if (widget.onToggleConcluida != null) {
      await widget.onToggleConcluida!.call();
      if (!mounted) return;
      setState(_updateStatus);
      await _loadStreak();
      return;
    }

    final newStatus = AtividadeStatus.normalize(widget.atividade.status) ==
            AtividadeStatus.concluida
        ? AtividadeStatus.pendente
        : AtividadeStatus.concluida;
    await DB.instance
        .updateActivity(widget.atividade.copyWith(status: newStatus));
    if (!mounted) return;
    setState(() {
      _localStatusOverride = newStatus;
      _updateStatus();
    });
    await _loadStreak();
  }

  Future<void> _cancelarAtividade() async {
    final newStatus = AtividadeStatus.normalize(widget.atividade.status) ==
            AtividadeStatus.cancelada
        ? AtividadeStatus.pendente
        : AtividadeStatus.cancelada;
    final atividadeAtualizada = widget.atividade.copyWith(status: newStatus);
    await DB.instance.updateActivity(atividadeAtualizada);
    widget.onCancelar?.call(atividadeAtualizada);
    if (!mounted) return;
    setState(() {
      _localStatusOverride = newStatus;
      _updateStatus();
    });
  }

  DateTime _nextOccurrenceDateForCalendar() {
    final atividade = widget.atividade;
    if (!atividade.repetirSemanalmente || atividade.diasDaSemana.isEmpty) {
      return atividade.data;
    }
    final now = DateTime.now();
    for (var i = 0; i < 7; i++) {
      final candidate = DateTime(now.year, now.month, now.day + i);
      if (atividade.diasDaSemana.contains(candidate.weekday)) {
        return candidate;
      }
    }
    return atividade.data;
  }

  // Exportação pontual (cópia estática) — não é sincronização contínua.
  // Atividades recorrentes exportam só a próxima ocorrência; mapear pra
  // RRULE do calendário do sistema ficou fora de escopo.
  Future<void> _addToSystemCalendar() async {
    final atividade = widget.atividade;
    final date = _nextOccurrenceDateForCalendar();
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      atividade.horaInicio.hour,
      atividade.horaInicio.minute,
    );
    var end = DateTime(
      date.year,
      date.month,
      date.day,
      atividade.horaFim.hour,
      atividade.horaFim.minute,
    );
    if (!end.isAfter(start)) {
      end = start.add(const Duration(hours: 1));
    }

    final added = await Add2Calendar.addEvent2Cal(Event(
      title: atividade.titulo,
      description:
          atividade.descricao.trim().isEmpty ? null : atividade.descricao,
      startDate: start,
      endDate: end,
    ));
    if (!mounted) return;
    showSnackbar(
      context: context,
      title: 'Calendário',
      message: added
          ? 'Evento adicionado ao calendário do aparelho. Edições no Routine não atualizam essa cópia automaticamente.'
          : 'Não foi possível adicionar ao calendário.',
      variant: added ? SnackbarVariant.success : SnackbarVariant.error,
    );
  }

  String _statusLabel(AppLocalizations t) {
    switch (_status) {
      case AtividadeStatus.concluida:
        return t.concluida;
      case AtividadeStatus.andamento:
        return t.emAndamento;
      case AtividadeStatus.atrasada:
        return t.atrasada;
      case AtividadeStatus.cancelada:
        return 'Cancelada';
      default:
        return t.pendente;
    }
  }

  Widget _buildCardContent(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    final statusColor = semantic.forAtividadeStatus(_status);
    final myParticipant = _meAsParticipant();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
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
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon, color: statusColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.atividade.titulo,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            decoration: _status == AtividadeStatus.cancelada
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabel(t),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _expandido
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
                onPressed: () => setState(() => _expandido = !_expandido),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (widget.historico)
                Chip(
                  avatar: Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: scheme.primary,
                  ),
                  label: Text(_dateFormat.format(widget.atividade.data)),
                ),
              Chip(
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(
                  '${widget.atividade.horaInicio.format(context)} - ${widget.atividade.horaFim.format(context)}',
                ),
              ),
              if (!widget.historico && (_streak?.current ?? 0) > 0)
                Chip(
                  avatar: Icon(
                    Icons.local_fire_department,
                    size: 16,
                    color: scheme.tertiary,
                  ),
                  backgroundColor: scheme.tertiary.withValues(alpha: 0.14),
                  label: Text('${_streak!.current} dias seguidos'),
                ),
              if (!widget.historico)
                ActionChip(
                  avatar: Icon(
                    _status == AtividadeStatus.concluida
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: semantic.success,
                    size: 18,
                  ),
                  label: Text(t.marcarComoConcluida),
                  onPressed: _marcarComoConcluida,
                ),
              if (!widget.historico &&
                  widget.showParticipants &&
                  myParticipant != null)
                ActionChip(
                  avatar: Icon(
                    _iconeStatusParticipante(myParticipant.status),
                    color: _corStatusParticipante(myParticipant.status),
                    size: 18,
                  ),
                  label: Text(
                    _updatingMyPresence
                        ? 'Atualizando...'
                        : _statusParticipanteLabel(myParticipant),
                  ),
                  onPressed:
                      _updatingMyPresence ? null : _openMyParticipationSheet,
                ),
            ],
          ),
          if (widget.showParticipants &&
              widget.atividade.participantes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: widget.atividade.participantes.map((p) {
                return _buildParticipantAvatar(p, radius: 16);
              }).toList(),
            ),
          ],
          if (_expandido) ...[
            const Divider(height: 18),
            if (!widget.historico && (_streak?.best ?? 0) > 0) ...[
              Text(
                'Recorde de sequência: ${_streak!.best} dias',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.atividade.descricao.trim().isNotEmpty) ...[
              Text(
                '${t.descricao}:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(widget.atividade.descricao),
              const SizedBox(height: 12),
            ],
            if (widget.showParticipants) ...[
              Text(
                '${t.participantes}:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              if (widget.atividade.participantes.isEmpty)
                const EmptyStateCard(
                  compact: true,
                  icon: Icons.people_outline,
                  title: 'Sem participantes.',
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.atividade.participantes.map((p) {
                    return Chip(
                      avatar: _buildParticipantAvatar(p, radius: 14),
                      label: Text('${p.nome} - ${_statusParticipanteLabel(p)}'),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.event_available_outlined),
                  onPressed: _addToSystemCalendar,
                  tooltip: 'Adicionar ao calendário',
                ),
                if (widget.onReutilizar != null)
                  IconButton(
                    icon: const Icon(Icons.repeat),
                    onPressed: widget.onReutilizar,
                    tooltip: 'Reutilizar',
                  ),
                if (widget.onEditar != null)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: widget.onEditar,
                    tooltip: t.editar,
                  ),
                if (widget.onExcluir != null)
                  IconButton(
                    icon: Icon(Icons.delete, color: semantic.danger),
                    onPressed: widget.onExcluir,
                    tooltip: t.excluir,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cardContent = _buildCardContent(context);
    if (widget.historico) return cardContent;

    final semantic = Theme.of(context).extension<AppSemanticColors>()!;

    return Dismissible(
      key: Key(widget.atividade.id.toString()),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          final confirmed = await confirmDialog(
            context,
            title: 'Confirmar exclusão',
            message: 'Você tem certeza de que deseja excluir esta atividade?',
            confirmLabel: 'Excluir',
            destructive: true,
          );
          if (confirmed) {
            widget.onExcluir?.call();
            return true;
          }
          return false;
        }

        if (direction == DismissDirection.startToEnd) {
          await _cancelarAtividade();
          return false;
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: semantic.warning,
        child: const Icon(Icons.cancel, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: semantic.danger,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: cardContent,
    );
  }
}
