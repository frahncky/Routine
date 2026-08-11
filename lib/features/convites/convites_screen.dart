import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:routine/features/convites/convite_atividade.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/widgets/app_background.dart';
import 'package:routine/widgets/empty_state_card.dart';
import 'package:routine/widgets/gradient_primary_button.dart';
import 'package:routine/widgets/show_snackbar.dart';

class ConvitesScreen extends ConsumerStatefulWidget {
  const ConvitesScreen({super.key});

  @override
  ConsumerState<ConvitesScreen> createState() => _ConvitesScreenState();
}

class _ConvitesScreenState extends ConsumerState<ConvitesScreen> {
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
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Convite',
        message: 'Não foi possível aceitar o convite.',
        variant: SnackbarVariant.error,
      );
      return;
    }

    if (!mounted) return;
    showSnackbar(
      context: context,
      title: 'Convite aceito',
      message: 'A atividade foi adicionada na sua agenda.',
      variant: SnackbarVariant.success,
    );
    ref.read(appChangeProvider.notifier).state++;
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
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Convite',
        message: 'Não foi possível recusar o convite.',
        variant: SnackbarVariant.error,
      );
      return;
    }

    if (!mounted) return;
    showSnackbar(
      context: context,
      title: 'Convite recusado',
      message: 'O convite foi recusado.',
      variant: SnackbarVariant.warning,
      icon: Icons.info_outline,
    );
    await _loadInvites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Convites')),
      body: AppBackground(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _invites.isEmpty
                ? const Center(
                    child: EmptyStateCard(
                      icon: Icons.mail_outline,
                      title: 'Sem convites pendentes.',
                    ),
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
                        final initHour = invite
                                .activityPayload['initHour']
                                ?.toString() ??
                            '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  invite.activityTitle,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
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
                                      child: GradientPrimaryButton(
                                        onPressed: isProcessing
                                            ? null
                                            : () => _acceptInvite(invite),
                                        label: 'Aceitar',
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
      ),
    );
  }
}
