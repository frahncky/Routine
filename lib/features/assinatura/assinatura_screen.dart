import 'package:flutter/material.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/helper/database_helper.dart';
import 'package:routine/main.dart';
import 'package:routine/widgets/show_snackbar.dart';

class AssinaturaScreen extends StatefulWidget {
  const AssinaturaScreen({super.key});

  @override
  State<AssinaturaScreen> createState() => _AssinaturaScreenState();
}

class _AssinaturaScreenState extends State<AssinaturaScreen> {
  String _currentPlan = PlanRules.gratis;
  String? _email;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadUserPlan();
  }

  Future<void> _loadUserPlan() async {
    final userMap = await DB.instance.getUser();
    if (!mounted) return;
    setState(() {
      _email = userMap?['email']?.toString();
      _currentPlan = PlanRules.normalize(userMap?['typeAccount']?.toString());
      _loading = false;
    });
  }

  Future<bool> _confirmDowngradeFromPremium(String targetPlan) async {
    final targetName = PlanRules.displayName(targetPlan);
    int contactsCount = 0;
    int activitiesCount = 0;
    try {
      final impact = await DB.instance.getDowngradeImpactSummary();
      contactsCount = impact['contacts'] ?? 0;
      activitiesCount = impact['activities'] ?? 0;
    } catch (_) {}

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirmar mudança de plano'),
          content: Text(
            'Ao migrar para $targetName, $contactsCount contato(s) e participantes de $activitiesCount atividade(s) serão limpos no dispositivo. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );
    return shouldProceed ?? false;
  }

  Future<void> _changePlan(String plan) async {
    if (_email == null || _email!.isEmpty) {
      showSnackbar(
        title: 'Plano',
        message: 'Faça login para alterar o plano.',
        backgroundColor: Colors.orange.shade300,
        icon: Icons.info_outline,
      );
      return;
    }

    final normalized = PlanRules.normalize(plan);
    if (normalized == _currentPlan) return;
    final downgradedFromPremium = PlanRules.hasFullAccess(_currentPlan) &&
        PlanRules.isPersonalAgendaOnly(normalized);
    if (downgradedFromPremium) {
      final confirmed = await _confirmDowngradeFromPremium(normalized);
      if (!confirmed) return;
    }
    if (!mounted) return;

    setState(() => _updating = true);
    try {
      await DB.instance.updateAccount(email: _email!, typeAccount: normalized);
      if (!mounted) return;
      setState(() {
        _currentPlan = normalized;
      });
      planChangeNotifier.value++;
      showSnackbar(
        title: 'Plano atualizado',
        message: downgradedFromPremium
            ? 'Você migrou para o plano ${PlanRules.displayName(normalized)}. Dados colaborativos foram limpos.'
            : 'Você migrou para o plano ${PlanRules.displayName(normalized)}.',
        backgroundColor: Colors.green.shade300,
        icon: Icons.check_circle,
      );
    } catch (e) {
      if (!mounted) return;
      showSnackbar(
        title: 'Falha ao atualizar plano',
        message: 'Não foi possível concluir a alteração. Tente novamente.',
        backgroundColor: Colors.red.shade300,
        icon: Icons.error_outline,
      );
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Widget _feature(bool enabled, String text) {
    return Row(
      children: [
        Icon(
          enabled ? Icons.check_circle : Icons.remove_circle_outline,
          color: enabled ? Colors.green.shade600 : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  Widget _planCard({
    required String id,
    required String title,
    required String subtitle,
    required String badge,
    required List<Widget> features,
    required List<Color> gradient,
  }) {
    final isCurrent = _currentPlan == id;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.last.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: isCurrent ? Colors.black : Colors.white.withValues(alpha: 0.6),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle),
          const SizedBox(height: 12),
          ...features,
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _updating ? null : () => _changePlan(id),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? Colors.black87 : Colors.white,
                foregroundColor: isCurrent ? Colors.white : Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isCurrent ? 'Plano atual' : 'Selecionar plano'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFC), Color(0xFFEDEFF6)],
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Escolha como usar o Routine',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _planCard(
                    id: PlanRules.gratis,
                    title: 'Grátis',
                    subtitle: 'Entrada rápida para começar seu planejamento.',
                    badge: 'R\$ 0',
                    gradient: const [Color(0xFFFFF4D6), Color(0xFFFED7AA)],
                    features: [
                      _feature(true, 'Agenda pessoal'),
                      _feature(true, 'Com propaganda'),
                      _feature(false, 'Agenda colaborativa'),
                    ],
                  ),
                  _planCard(
                    id: PlanRules.basico,
                    title: 'Básico',
                    subtitle: 'Sem anúncios e foco total no seu uso pessoal.',
                    badge: 'R\$ 9,90/mês',
                    gradient: const [Color(0xFFDFF7FF), Color(0xFFBDE3F9)],
                    features: [
                      _feature(true, 'Agenda pessoal'),
                      _feature(true, 'Até 20 atividades'),
                      _feature(true, 'Sem propaganda'),
                      _feature(false, 'Agenda colaborativa'),
                    ],
                  ),
                  _planCard(
                    id: PlanRules.plus,
                    title: 'Plus',
                    subtitle:
                        'Mais espaço para sua agenda pessoal sem anúncios.',
                    badge: 'R\$ 14,90/mês',
                    gradient: const [Color(0xFFE7FCEB), Color(0xFFCFF5D8)],
                    features: [
                      _feature(true, 'Agenda pessoal'),
                      _feature(true, 'Até 60 atividades'),
                      _feature(true, 'Sem propaganda'),
                      _feature(false, 'Agenda colaborativa'),
                    ],
                  ),
                  _planCard(
                    id: PlanRules.premium,
                    title: 'Premium',
                    subtitle: 'Ampla funcionalidade para uso completo do app.',
                    badge: 'R\$ 24,90/mês',
                    gradient: const [Color(0xFFE7E8FF), Color(0xFFC7CEFF)],
                    features: [
                      _feature(true, 'Sem propaganda'),
                      _feature(true, 'Atividades ilimitadas'),
                      _feature(true, 'Agenda colaborativa'),
                      _feature(true, 'Participantes e contatos'),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
