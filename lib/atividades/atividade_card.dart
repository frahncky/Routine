import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart';

class AtividadeCard extends StatefulWidget {
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
  final VoidCallback? onToggleConcluida;
  final VoidCallback? onReutilizar;
  final bool historico;
  final VoidCallback? onCancelar;
  final bool showParticipants;

  @override
  State<AtividadeCard> createState() => _AtividadeCardState();
}

class _AtividadeCardState extends State<AtividadeCard>
    with AutomaticKeepAliveClientMixin {
  bool _expandido = false;
  late String _status;
  late Color _statusColor;
  late IconData _statusIcon;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _updateStatus();
  }

  void _updateStatus() {
    _status = _determinarStatus(widget.atividade);
    _statusColor = _corPorStatus(_status);
    _statusIcon = _iconePorStatus(_status);
  }

  static String _determinarStatus(Atividade atividade) {
    final normalized = AtividadeStatus.normalize(atividade.status);
    if (normalized == AtividadeStatus.cancelada)
      return AtividadeStatus.cancelada;
    if (normalized == AtividadeStatus.concluida)
      return AtividadeStatus.concluida;

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

  static Color _corPorStatus(String status) {
    switch (status) {
      case AtividadeStatus.concluida:
        return const Color(0xFF16A34A);
      case AtividadeStatus.andamento:
        return const Color(0xFF2563EB);
      case AtividadeStatus.atrasada:
        return const Color(0xFFDC2626);
      case AtividadeStatus.cancelada:
        return const Color(0xFFD97706);
      default:
        return const Color(0xFF64748B);
    }
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
    switch (status) {
      case 'Aceito':
        return Icons.check;
      case 'Recusado':
        return Icons.close;
      default:
        return Icons.hourglass_empty;
    }
  }

  Future<void> _marcarComoConcluida() async {
    final newStatus = AtividadeStatus.normalize(widget.atividade.status) ==
            AtividadeStatus.concluida
        ? AtividadeStatus.pendente
        : AtividadeStatus.concluida;
    await DB.instance
        .updateActivity(widget.atividade.copyWith(status: newStatus));
    widget.onToggleConcluida?.call();
    if (!mounted) return;
    setState(() {
      _updateStatus();
      changeHome.value = !changeHome.value;
    });
  }

  Future<void> _cancelarAtividade() async {
    final newStatus = AtividadeStatus.normalize(widget.atividade.status) ==
            AtividadeStatus.cancelada
        ? AtividadeStatus.pendente
        : AtividadeStatus.cancelada;
    await DB.instance
        .updateActivity(widget.atividade.copyWith(status: newStatus));
    widget.onCancelar?.call();
    if (!mounted) return;
    setState(() {
      _updateStatus();
      changeHome.value = !changeHome.value;
    });
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
    final t = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.35),
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
                  color: _statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon, color: _statusColor, size: 18),
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
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabel(t),
                        style: TextStyle(
                          color: _statusColor,
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
              Chip(
                avatar:
                    Icon(Icons.calendar_today, size: 16, color: scheme.primary),
                label: Text(_dateFormat.format(widget.atividade.data)),
              ),
              Chip(
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(
                  '${widget.atividade.horaInicio.format(context)} - ${widget.atividade.horaFim.format(context)}',
                ),
              ),
              if (!widget.historico)
                ActionChip(
                  avatar: Icon(
                    _status == AtividadeStatus.concluida
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: const Color(0xFF16A34A),
                    size: 18,
                  ),
                  label: Text(t.marcarComoConcluida),
                  onPressed: _marcarComoConcluida,
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
                return CircleAvatar(
                  radius: 16,
                  backgroundImage:
                      p.fotoUrl != null ? NetworkImage(p.fotoUrl!) : null,
                  child: p.fotoUrl == null ? Text(p.nome[0]) : null,
                );
              }).toList(),
            ),
          ],
          if (_expandido) ...[
            const Divider(height: 18),
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
                const Text('Sem participantes.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.atividade.participantes.map((p) {
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundImage:
                            p.fotoUrl != null ? NetworkImage(p.fotoUrl!) : null,
                        child: p.fotoUrl == null ? Text(p.nome[0]) : null,
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(p.nome),
                          const SizedBox(width: 4),
                          Icon(_iconeStatusParticipante(p.status), size: 16),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.onEditar != null)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: widget.onEditar,
                    tooltip: t.editar,
                  ),
                if (widget.onExcluir != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Color(0xFFDC2626)),
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

    return Dismissible(
      key: Key(widget.atividade.id.toString()),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirmar exclusao'),
              content: const Text(
                  'Voce tem certeza de que deseja excluir esta atividade?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Excluir'),
                ),
              ],
            ),
          );
          if (confirmed ?? false) {
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
        color: const Color(0xFFD97706),
        child: const Icon(Icons.cancel, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: const Color(0xFFDC2626),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: cardContent,
    );
  }
}
