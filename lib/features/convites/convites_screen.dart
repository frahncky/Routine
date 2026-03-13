import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:routine/features/convites/convite_atividade.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart';
import 'package:routine/widgets/show_snackbar.dart';

class ConvitesScreen extends StatefulWidget {
  const ConvitesScreen({super.key});

  @override
  State<ConvitesScreen> createState() => _ConvitesScreenState();
}

class _ConvitesScreenState extends State<ConvitesScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy');
  final Set<String> _processingInvites = <String>{};

  bool _loading = true;
  List<ConviteAtividade> _invites = [];

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    final invites = await DB.instance.getPendingActivityInvites();
    if (!mounted) return;
    setState(() {
      _invites = invites;
      _loading = false;
    });
  }

  Future<void> _acceptInvite(ConviteAtividade invite) async {
    if (_processingInvites.contains(invite.id)) return;
    setState(() => _processingInvites.add(invite.id));

    final success = await DB.instance.acceptActivityInvite(invite);
    if (mounted) {
      setState(() => _processingInvites.remove(invite.id));
    }

    if (!success) {
      showSnackbar(
        title: 'Convite',
        message: 'Não foi possível aceitar o convite.',
        backgroundColor: Colors.red.shade300,
        icon: Icons.error_outline,
      );
      return;
    }

    showSnackbar(
      title: 'Convite aceito',
      message: 'A atividade foi adicionada na sua agenda.',
      backgroundColor: Colors.green.shade300,
      icon: Icons.check_circle,
    );
    mergedChange.markChanged();
    await _loadInvites();
  }

  Future<void> _declineInvite(ConviteAtividade invite) async {
    if (_processingInvites.contains(invite.id)) return;
    setState(() => _processingInvites.add(invite.id));

    final success = await DB.instance.declineActivityInvite(invite);
    if (mounted) {
      setState(() => _processingInvites.remove(invite.id));
    }

    if (!success) {
      showSnackbar(
        title: 'Convite',
        message: 'Não foi possível recusar o convite.',
        backgroundColor: Colors.red.shade300,
        icon: Icons.error_outline,
      );
      return;
    }

    showSnackbar(
      title: 'Convite recusado',
      message: 'O convite foi recusado.',
      backgroundColor: Colors.orange.shade300,
      icon: Icons.info_outline,
    );
    await _loadInvites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Convites')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invites.isEmpty
              ? const Center(
                  child: Text('Sem convites pendentes.'),
                )
              : RefreshIndicator(
                  onRefresh: _loadInvites,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                    itemCount: _invites.length,
                    itemBuilder: (context, index) {
                      final invite = _invites[index];
                      final isProcessing =
                          _processingInvites.contains(invite.id);
                      final initHour =
                          invite.activityPayload['initHour']?.toString() ?? '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                invite.activityTitle,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text('De: ${invite.ownerName}'),
                              Text(invite.ownerEmail),
                              const SizedBox(height: 6),
                              Text(
                                initHour.isEmpty
                                    ? _dateFormat.format(invite.activityDate)
                                    : '${_dateFormat.format(invite.activityDate)} às $initHour',
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: isProcessing
                                          ? null
                                          : () => _declineInvite(invite),
                                      child: const Text('Recusar'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: isProcessing
                                          ? null
                                          : () => _acceptInvite(invite),
                                      child: const Text('Aceitar'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
