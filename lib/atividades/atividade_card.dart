import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart';

class AtividadeCard extends StatefulWidget {
  final Atividade atividade;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;
  final VoidCallback? onToggleConcluida;
  final VoidCallback? onReutilizar;
  final bool historico;
  final VoidCallback? onCancelar;
  final bool showParticipants;

  const AtividadeCard({
    Key? key,
    required this.atividade,
    this.onEditar,
    this.onExcluir,
    this.onToggleConcluida,
    this.onReutilizar,
    this.historico = false,
    this.onCancelar,
    this.showParticipants = true,
  }) : super(key: key);

  @override
  State<AtividadeCard> createState() => _AtividadeCardState();
}

class _AtividadeCardState extends State<AtividadeCard>
    with AutomaticKeepAliveClientMixin {
  bool _expandido = false;
  late String _status;
  late Color _cardColor;
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
    _cardColor = _corPorCard(_status);
    _statusColor = _corPorStatus(_status);
    _statusIcon = _iconePorStatus(_status);
  }

  static String _determinarStatus(Atividade atividade) {
    if (AtividadeStatus.normalize(atividade.status) == AtividadeStatus.cancelada) {
      return AtividadeStatus.cancelada;
    }
    if (AtividadeStatus.normalize(atividade.status) == AtividadeStatus.concluida) {
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
    } else if (agora.hour > fim.hour ||
        (agora.hour == fim.hour && agora.minute > fim.minute)) {
      return AtividadeStatus.atrasada;
    } else {
      return AtividadeStatus.andamento;
    }
  }

  static Color _corPorCard(String status) {
    switch (status) {
      case AtividadeStatus.concluida:
        return Colors.green.withValues(alpha: 0.15);
      case AtividadeStatus.andamento:
        return Colors.blue.withValues(alpha: 0.15);
      case AtividadeStatus.atrasada:
        return Colors.red.withValues(alpha: 0.15);
      case AtividadeStatus.cancelada:
        return Colors.yellow.withValues(alpha: 0.15);
      default:
        return Colors.grey.withValues(alpha: 0.05);
    }
  }

  static Color _corPorStatus(String status) {
    switch (status) {
      case AtividadeStatus.concluida:
        return Colors.green.withValues(alpha: 0.8);
      case AtividadeStatus.andamento:
        return Colors.blue.withValues(alpha: 0.8);
      case AtividadeStatus.atrasada:
        return Colors.red.withValues(alpha: 0.8);
      case AtividadeStatus.cancelada:
        return Colors.yellow[700]!;
      default:
        return Colors.black87;
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
    final newStatus =
        AtividadeStatus.normalize(widget.atividade.status) == AtividadeStatus.concluida
            ? AtividadeStatus.pendente
            : AtividadeStatus.concluida;
    await DB.instance
        .updateActivity(widget.atividade.copyWith(status: newStatus));
    widget.onToggleConcluida?.call();
    if (mounted) {
      setState(() {
        _updateStatus();
        changeHome.value = !changeHome.value;
      });
    }
  }

  Future<void> _cancelarAtividade() async {
    final newStatus =
        AtividadeStatus.normalize(widget.atividade.status) == AtividadeStatus.cancelada
            ? AtividadeStatus.pendente
            : AtividadeStatus.cancelada;
    await DB.instance
        .updateActivity(widget.atividade.copyWith(status: newStatus));
    widget.onCancelar?.call();
    if (mounted) {
      setState(() {
        _updateStatus();
        changeHome.value = !changeHome.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = AppLocalizations.of(context)!;

    final cardContent = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(2, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_statusIcon, color: _statusColor),
            title: Text(
              widget.atividade.titulo,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: _status == AtividadeStatus.cancelada
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
            trailing: IconButton(
              icon: Icon(_expandido ? Icons.expand_less : Icons.expand_more),
              onPressed: () => setState(() => _expandido = !_expandido),
            ),
            onTap: () => setState(() => _expandido = !_expandido),
          ),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
              const SizedBox(width: 4),
              Text(_dateFormat.format(widget.atividade.data)),
              const SizedBox(width: 12),
              const Icon(Icons.schedule, size: 18, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                  '${widget.atividade.horaInicio.format(context)} - ${widget.atividade.horaFim.format(context)}'),
              IconButton(
                icon: Icon(
                  _status == AtividadeStatus.concluida
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  color: Colors.green,
                ),
                onPressed:
                    widget.historico == false ? _marcarComoConcluida : null,
                tooltip: t.marcarComoConcluida,
              ),
            ],
          ),
          if (widget.showParticipants &&
              widget.atividade.participantes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
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
            const Divider(),
            const SizedBox(height: 8),
            if (widget.atividade.descricao.trim().isNotEmpty) ...[
              Text('${t.descricao}:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(widget.atividade.descricao),
              const SizedBox(height: 12),
            ],
            if (widget.showParticipants) ...[
              Text('${t.participantes}:',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (widget.atividade.participantes.isEmpty)
                const Text('Sem participantes.')
              else
                Wrap(
                  spacing: 8,
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
                      backgroundColor: Colors.grey[200],
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
                    icon: const Icon(Icons.edit, color: Colors.black),
                    onPressed: widget.onEditar,
                    tooltip: t.editar,
                  ),
                if (widget.onExcluir != null)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: widget.onExcluir,
                    tooltip: t.excluir,
                  ),
              ],
            ),
          ]
        ],
      ),
    );

    if (widget.historico) return cardContent;

    return Dismissible(
      key: Key(widget.atividade.id.toString()),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Confirmar exclusÃ£o'),
              content: const Text(
                  'VocÃª tem certeza de que deseja excluir esta atividade?'),
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
        } else if (direction == DismissDirection.startToEnd) {
          _cancelarAtividade();
          return false;
        }
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        color: Colors.yellow,
        child: const Icon(Icons.cancel, color: Colors.white),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: cardContent,
    );
  }
}


