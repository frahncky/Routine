import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:routine/features/assinatura/plan_rules.dart';

enum PurchaseStartStatus {
  started,
  storeUnavailable,
  productNotFound,
  failed,
  planDoesNotRequirePurchase,
}

class PurchaseStartResult {
  const PurchaseStartResult(this.status, [this.message]);

  final PurchaseStartStatus status;
  final String? message;
}

class SubscriptionService {
  SubscriptionService({
    InAppPurchase? inAppPurchase,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _inAppPurchase = inAppPurchase ?? InAppPurchase.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  static const Map<String, String> productIdsByPlan = {
    PlanRules.basico: 'routine_basico_monthly',
    PlanRules.avancado: 'routine_plus_monthly',
    PlanRules.colaborativo: 'routine_premium_monthly',
  };

  final InAppPurchase _inAppPurchase;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Stream<List<PurchaseDetails>> get purchaseStream =>
      _inAppPurchase.purchaseStream;

  static String? productIdForPlan(String plan) {
    return productIdsByPlan[PlanRules.normalize(plan)];
  }

  static String? planForProductId(String productId) {
    for (final entry in productIdsByPlan.entries) {
      if (entry.value == productId) return entry.key;
    }
    return null;
  }

  Future<PurchaseStartResult> startPurchase(String plan) async {
    final normalized = PlanRules.normalize(plan);
    final productId = productIdForPlan(normalized);
    if (productId == null) {
      return const PurchaseStartResult(
        PurchaseStartStatus.planDoesNotRequirePurchase,
      );
    }

    if (!await _inAppPurchase.isAvailable()) {
      return const PurchaseStartResult(
        PurchaseStartStatus.storeUnavailable,
        'A loja não está disponível neste dispositivo.',
      );
    }

    final response = await _inAppPurchase.queryProductDetails({productId});
    if (response.error != null) {
      return PurchaseStartResult(
        PurchaseStartStatus.failed,
        response.error!.message,
      );
    }
    if (response.productDetails.isEmpty) {
      return PurchaseStartResult(
        PurchaseStartStatus.productNotFound,
        'Produto não encontrado na loja: $productId.',
      );
    }

    final purchaseParam = PurchaseParam(
      productDetails: response.productDetails.first,
    );
    final started =
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
    return PurchaseStartResult(
      started ? PurchaseStartStatus.started : PurchaseStartStatus.failed,
      started ? null : 'Não foi possível iniciar a compra.',
    );
  }

  Future<void> submitPurchaseForValidation(PurchaseDetails purchase) async {
    final targetPlan = planForProductId(purchase.productID);
    final user = _auth.currentUser;
    if (targetPlan == null || user == null) return;

    final email = user.email?.trim().toLowerCase() ?? '';
    final purchaseId = purchase.purchaseID?.trim();
    final docId = _safeDocumentId(
      '${user.uid}_${purchaseId?.isNotEmpty == true ? purchaseId : DateTime.now().microsecondsSinceEpoch}',
    );

    await _firestore.collection('purchase_validations').doc(docId).set({
      'uid': user.uid,
      'email': email,
      'target_plan': targetPlan,
      'product_id': purchase.productID,
      'purchase_id': purchase.purchaseID,
      'source': purchase.verificationData.source,
      'server_verification_data':
          purchase.verificationData.serverVerificationData,
      'local_verification_data': purchase.verificationData.localVerificationData,
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> completePurchaseIfNeeded(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchase);
    }
  }

  static String _safeDocumentId(String value) {
    return value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }
}
