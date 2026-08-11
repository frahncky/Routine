import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:routine/features/assinatura/assinatura_screen.dart';
import 'package:routine/features/assinatura/plan_access.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/assinatura/widgets/plan_locked_card.dart';
import 'package:routine/features/configuracoes/configuracoes_screen.dart';
import 'package:routine/features/contacts/contacts_screen.dart';
import 'package:routine/features/historico/historico_screen.dart';
import 'package:routine/features/home/home_screen.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/l10n/app_localizations.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/widgets/curved_bottom_nav_bar.dart';

class MainTabs extends ConsumerStatefulWidget {
  const MainTabs({super.key});

  @override
  ConsumerState<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends ConsumerState<MainTabs> {
  int _currentIndex = 0;
  String _currentPlan = PlanRules.gratuito;
  int _pendingInvitesCount = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    HistoricoScreen(),
    ContactsScreen(),
    ConfiguracoesScreen(),
  ];

  bool get _isPersonalOnly => PlanRules.isPersonalAgendaOnly(_currentPlan);

  List<IconData> get _icons => [
        Icons.home,
        Icons.history,
        _isPersonalOnly ? Icons.lock_outline : Icons.view_agenda,
        Icons.settings,
      ];

  @override
  void initState() {
    super.initState();
    unawaited(_refreshProfileSafely());
    _loadPlan();
    unawaited(_loadNotificationsPreference());
    unawaited(_loadPendingInvitesCount());
  }

  Future<void> _refreshProfileSafely() async {
    try {
      await ref.read(userProfileProvider.notifier).refresh();
    } catch (e) {
      debugPrint('Falha ao sincronizar perfil na MainTabs: $e');
    }
  }

  Future<void> _loadNotificationsPreference() async {
    final value = await DB.instance.getConfig('notificacoesAtivas');
    if (!mounted) return;
    ref.read(notificationsActiveProvider.notifier).state = value != 'false';
  }

  Future<void> _loadPlan() async {
    final userMap = await DB.instance.getUser();
    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    if (!mounted) return;
    setState(() {
      _currentPlan = PlanAccess.effectivePlan(
        isSignedIn: isSignedIn,
        storedPlan: userMap?['typeAccount']?.toString(),
      );
    });
  }

  Future<void> _loadPendingInvitesCount() async {
    try {
      final invites = await DB.instance.getPendingActivityInvites();
      if (!mounted) return;
      setState(() => _pendingInvitesCount = invites.length);
    } catch (e) {
      debugPrint('Falha ao carregar convites pendentes na MainTabs: $e');
    }
  }

  Future<void> _showContactsPlanSheet() async {
    final isPt = Localizations.localeOf(context).languageCode == 'pt';
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PlanLockedCard(
                  centered: false,
                  title: isPt
                      ? 'Contatos colaborativos no plano Colaborativo'
                      : 'Collaborative contacts on the Collaborative plan',
                  message: isPt
                      ? 'Seu plano ${PlanRules.displayName(_currentPlan)} permite agenda pessoal. Para usar contatos e participantes compartilhados, ative o Colaborativo.'
                      : 'Your ${PlanRules.displayName(_currentPlan)} plan allows personal agenda only. Upgrade to Collaborative to use shared contacts and participants.',
                  onAction: () => Navigator.pop(context, 'plans'),
                  actionLabel: isPt ? 'Ver planos' : 'View plans',
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'continue'),
                  child: Text(isPt ? 'Abrir mesmo assim' : 'Open anyway'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (action == 'plans') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AssinaturaScreen()),
      );
      await _loadPlan();
      return;
    }
    if (action == 'continue') {
      setState(() => _currentIndex = 2);
    }
  }

  List<String> _labels(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isPt = Localizations.localeOf(context).languageCode == 'pt';
    return [
      t.home,
      t.historico,
      _isPersonalOnly ? 'Colaborativo' : (isPt ? 'Contatos' : 'Contacts'),
      t.configuracoes,
    ];
  }

  Future<void> _onItemTap(int index) async {
    if (index == 2 && _isPersonalOnly) {
      await _showContactsPlanSheet();
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Recarrega plano e contagem de convites quando qualquer mudança global ocorre.
    ref.listen<int>(appChangeProvider, (_, __) {
      _loadPlan();
      unawaited(_loadPendingInvitesCount());
    });

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: AnimatedCurvedBottomNavBar(
        icons: _icons,
        selectedIndex: _currentIndex,
        onItemTap: _onItemTap,
        labels: _labels(context),
        backgroundColor: Theme.of(context).colorScheme.onSurface,
        activeColor: Theme.of(context).colorScheme.primary,
        badgeCounts: {2: _pendingInvitesCount},
      ),
    );
  }
}
