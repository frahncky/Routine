import 'dart:async';

import 'package:flutter/material.dart';
import 'package:routine/features/assinatura/assinatura_screen.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/configuracoes/configuracoes_screen.dart';
import 'package:routine/features/contacts/contacts_screen.dart';
import 'package:routine/features/historico/historico_screen.dart';
import 'package:routine/features/home/home_screen.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/l10n/app_localizations.dart';
import 'package:routine/main.dart';
import 'package:routine/widgets/CurvedBottomNavBar.dart';

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _currentIndex = 0;
  String _currentPlan = PlanRules.gratis;

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
    planChangeNotifier.addListener(_onPlanChanged);
    unawaited(_refreshProfileSafely());
    _loadPlan();
  }

  @override
  void dispose() {
    planChangeNotifier.removeListener(_onPlanChanged);
    super.dispose();
  }

  void _onPlanChanged() {
    _loadPlan();
  }

  Future<void> _refreshProfileSafely() async {
    try {
      await refreshCurrentUserProfile();
    } catch (e) {
      debugPrint('Falha ao sincronizar perfil na MainTabs: $e');
    }
  }

  Future<void> _loadPlan() async {
    final userMap = await DB.instance.getUser();
    if (!mounted) return;
    setState(() {
      _currentPlan = PlanRules.normalize(userMap?['typeAccount']?.toString());
    });
  }

  Future<void> _showContactsPlanSheet() async {
    final isPt = Localizations.localeOf(context).languageCode == 'pt';
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPt
                      ? 'Contatos colaborativos no Premium'
                      : 'Collaborative contacts on Premium',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  isPt
                      ? 'Seu plano ${PlanRules.displayName(_currentPlan)} permite agenda pessoal. Para usar contatos e participantes compartilhados, ative o Premium.'
                      : 'Your ${PlanRules.displayName(_currentPlan)} plan allows personal agenda only. Upgrade to Premium to use shared contacts and participants.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, 'continue'),
                        child: Text(
                          isPt ? 'Abrir mesmo assim' : 'Open anyway',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, 'plans'),
                        child: Text(isPt ? 'Ver planos' : 'View plans'),
                      ),
                    ),
                  ],
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
      _isPersonalOnly ? 'Premium' : (isPt ? 'Contatos' : 'Contacts'),
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
      ),
    );
  }
}
