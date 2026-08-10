import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:routine/features/assinatura/plan_access.dart';
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/features/assinatura/subscription_service.dart';
import 'package:routine/login/login_screen.dart';
import 'package:routine/providers/app_providers.dart';
import 'package:routine/repositories/account_repository.dart';
import 'package:routine/theme/app_semantic_colors.dart';
import 'package:routine/widgets/show_snackbar.dart';

class AssinaturaScreen extends ConsumerStatefulWidget {
  const AssinaturaScreen({super.key});

  @override
  ConsumerState<AssinaturaScreen> createState() => _AssinaturaScreenState();
}

class _AssinaturaScreenState extends ConsumerState<AssinaturaScreen> {
  String _currentPlan = PlanRules.gratuito;
  String? _email;
  bool _loading = true;
  bool _updating = false;
  final AccountRepository _accountRepository = AccountRepository();
  late final SubscriptionService _subscriptionService;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  bool get _hasAccount =>
      (FirebaseAuth.instance.currentUser?.uid.isNotEmpty ?? false) &&
      (_email?.trim().isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    _subscriptionService = SubscriptionService();
    _purchaseSubscription =
        _subscriptionService.purchaseStream.listen(_handlePurchases);
    _loadUserPlan();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserPlan() async {
    final userMap = await _accountRepository.getUser();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final firebaseEmail = firebaseUser?.email;
    final isSignedIn = firebaseUser != null;
    if (!mounted) return;
    setState(() {
      final localEmail = userMap?['email']?.toString().trim();
      _email = isSignedIn
          ? (localEmail != null && localEmail.isNotEmpty
              ? localEmail
              : firebaseEmail?.trim())
          : null;
      _currentPlan = PlanAccess.effectivePlan(
        isSignedIn: isSignedIn,
        storedPlan: userMap?['typeAccount']?.toString(),
      );
      _loading = false;
    });
  }

  Future<void> _openLoginForPlan() async {
    if (!mounted) return;
    showSnackbar(
      context: context,
      title: 'Conta necessária',
      message: 'Entre ou crie uma conta para assinar planos pagos.',
      variant: SnackbarVariant.warning,
      icon: Icons.lock_outline,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(
          redirectAfterLogin: AssinaturaScreen(),
        ),
      ),
    );
    if (!mounted) return;
    await _loadUserPlan();
  }

  Future<bool> _confirmDowngradeFromPremium(String targetPlan) async {
    final targetName = PlanRules.displayName(targetPlan);
    int contactsCount = 0;
    int activitiesCount = 0;
    try {
      final impact = await _accountRepository.getDowngradeImpactSummary();
      contactsCount = impact['contacts'] ?? 0;
      activitiesCount = impact['activities'] ?? 0;
    } catch (_) {}
    if (!mounted) return false;

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

  Future<bool> _confirmLosingCloudBackup(String targetPlan) async {
    final targetName = PlanRules.displayName(targetPlan);
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Backup em nuvem será pausado'),
          content: Text(
            'Ao migrar para $targetName, novas atividades deixam de ser enviadas para a nuvem. Os dados já enviados continuam guardados e voltam a ser usados se você assinar Avançado ou Colaborativo novamente. Deseja continuar?',
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
      if (PlanAccess.requiresAccount(plan)) {
        await _openLoginForPlan();
      }
      return;
    }

    final normalized = PlanRules.normalize(plan);
    if (normalized == _currentPlan) return;
    if (PlanAccess.requiresAccount(normalized)) {
      await _startPlanPurchase(normalized);
      return;
    }

    final downgradedFromPremium = PlanRules.hasFullAccess(_currentPlan) &&
        PlanRules.isPersonalAgendaOnly(normalized);
    final losingCloudBackup = PlanRules.hasCloudBackup(_currentPlan) &&
        !PlanRules.hasCloudBackup(normalized);
    if (downgradedFromPremium) {
      final confirmed = await _confirmDowngradeFromPremium(normalized);
      if (!confirmed) return;
    } else if (losingCloudBackup) {
      final confirmed = await _confirmLosingCloudBackup(normalized);
      if (!confirmed) return;
    }
    if (!mounted) return;

    setState(() => _updating = true);
    try {
      await _accountRepository.updateAccount(
        email: _email!,
        typeAccount: normalized,
      );
      if (!mounted) return;
      setState(() {
        _currentPlan = normalized;
      });
      ref.read(appChangeProvider.notifier).state++;
      showSnackbar(
        context: context,
        title: 'Plano atualizado',
        message: downgradedFromPremium
            ? 'Você migrou para o plano ${PlanRules.displayName(normalized)}. Dados colaborativos foram limpos.'
            : 'Você migrou para o plano ${PlanRules.displayName(normalized)}.',
        variant: SnackbarVariant.success,
      );
    } catch (e) {
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Falha ao atualizar plano',
        message: 'Não foi possível concluir a alteração. Tente novamente.',
        variant: SnackbarVariant.error,
      );
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _startPlanPurchase(String plan) async {
    setState(() => _updating = true);
    try {
      final result = await _subscriptionService.startPurchase(plan);
      if (!mounted) return;
      switch (result.status) {
        case PurchaseStartStatus.started:
          showSnackbar(
            context: context,
            title: 'Compra iniciada',
            message:
                'Finalize a compra na loja. O plano será ativado após validação.',
            variant: SnackbarVariant.info,
            icon: Icons.shopping_bag_outlined,
          );
          break;
        case PurchaseStartStatus.storeUnavailable:
        case PurchaseStartStatus.productNotFound:
        case PurchaseStartStatus.failed:
          showSnackbar(
            context: context,
            title: 'Compra indisponível',
            message: result.message ?? 'Não foi possível iniciar a compra.',
            variant: SnackbarVariant.error,
          );
          break;
        case PurchaseStartStatus.planDoesNotRequirePurchase:
          break;
      }
    } catch (_) {
      if (!mounted) return;
      showSnackbar(
        context: context,
        title: 'Compra indisponível',
        message: 'Não foi possível iniciar a compra agora.',
        variant: SnackbarVariant.error,
      );
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      final plan = SubscriptionService.planForProductId(purchase.productID);
      if (plan == null) continue;

      if (purchase.status == PurchaseStatus.error) {
        if (!mounted) continue;
        showSnackbar(
          context: context,
          title: 'Falha na compra',
          message: purchase.error?.message ?? 'A loja recusou a compra.',
          variant: SnackbarVariant.error,
        );
        await _subscriptionService.completePurchaseIfNeeded(purchase);
        continue;
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        try {
          await _subscriptionService.submitPurchaseForValidation(purchase);
          await _subscriptionService.completePurchaseIfNeeded(purchase);
          if (!mounted) continue;
          showSnackbar(
            context: context,
            title: 'Compra recebida',
            message:
                'A compra foi enviada para validação. O plano será liberado após confirmação.',
            variant: SnackbarVariant.success,
            icon: Icons.verified_outlined,
          );
          await _loadUserPlan();
        } catch (_) {
          if (!mounted) continue;
          showSnackbar(
            context: context,
            title: 'Validação pendente',
            message:
                'Não foi possível enviar a compra para validação agora. Tente novamente em instantes.',
            variant: SnackbarVariant.warning,
            icon: Icons.info_outline,
          );
        }
      }
    }
  }

  Widget _feature(bool enabled, String text) {
    final semantic = Theme.of(context).extension<AppSemanticColors>()!;
    return Row(
      children: [
        Icon(
          enabled ? Icons.check_circle : Icons.remove_circle_outline,
          color: enabled ? semantic.success : Colors.grey,
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
    final requiresAccount = id != PlanRules.gratuito;
    final buttonText = isCurrent
        ? 'Plano atual'
        : (!_hasAccount && requiresAccount)
            ? 'Entrar para assinar'
            : 'Selecionar plano';

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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
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
              child: Text(buttonText),
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
                    id: PlanRules.gratuito,
                    title: 'Gratuito',
                    subtitle:
                        'Plano gratuito com poucos recursos e dados salvos apenas no celular.',
                    badge: 'R\$ 0',
                    gradient: const [Color(0xFFFFF4D6), Color(0xFFFED7AA)],
                    features: [
                      _feature(true, 'Agenda pessoal'),
                      _feature(true, 'Até 7 atividades'),
                      _feature(true, 'Dados salvos no celular'),
                      _feature(false, 'Agenda colaborativa'),
                    ],
                  ),
                  _planCard(
                    id: PlanRules.basico,
                    title: 'Básico',
                    subtitle:
                        'Mais atividades para sua agenda pessoal, salvas no celular.',
                    badge: 'R\$ 12,90/mês',
                    gradient: const [Color(0xFFDFF7FF), Color(0xFFBDE3F9)],
                    features: [
                      _feature(true, 'Agenda pessoal'),
                      _feature(true, 'Até 20 atividades'),
                      _feature(true, 'Dados salvos no celular'),
                      _feature(false, 'Agenda colaborativa'),
                    ],
                  ),
                  _planCard(
                    id: PlanRules.avancado,
                    title: 'Avançado',
                    subtitle:
                        'Todos os recursos individuais, com backup em nuvem para recuperação.',
                    badge: 'R\$ 14,90/mês',
                    gradient: const [Color(0xFFE7FCEB), Color(0xFFCFF5D8)],
                    features: [
                      _feature(true, 'Agenda pessoal'),
                      _feature(true, 'Atividades ilimitadas'),
                      _feature(true, 'Backup na nuvem'),
                      _feature(true, 'Recuperação em novo dispositivo'),
                      _feature(false, 'Agenda colaborativa'),
                    ],
                  ),
                  _planCard(
                    id: PlanRules.colaborativo,
                    title: 'Colaborativo',
                    subtitle:
                        'Tudo do Avançado, mais convites e agenda compartilhada.',
                    badge: 'R\$ 24,90/mês',
                    gradient: const [Color(0xFFE7E8FF), Color(0xFFC7CEFF)],
                    features: [
                      _feature(true, 'Atividades ilimitadas'),
                      _feature(true, 'Backup na nuvem'),
                      _feature(true, 'Agenda colaborativa'),
                      _feature(true, 'Convites e participantes'),
                      _feature(true, 'Contatos compartilhados'),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
