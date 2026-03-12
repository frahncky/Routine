import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class AssinaturaScreen extends StatefulWidget {
  const AssinaturaScreen({super.key});

  @override
  State<AssinaturaScreen> createState() => _AssinaturaScreenState();
}

class _AssinaturaScreenState extends State<AssinaturaScreen> {
  final InAppPurchase _iap = InAppPurchase.instance;
  final List<String> _productIds = ['plano_basico', 'plano_intermediario', 'plano_vip'];
  List<ProductDetails> _produtos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    final bool available = await _iap.isAvailable();
    if (!available) {
      setState(() => _carregando = false);
      return;
    }

    final ProductDetailsResponse response = await _iap.queryProductDetails(_productIds.toSet());
    setState(() {
      _produtos = response.productDetails;
      _carregando = false;
    });
  }

  void _comprar(ProductDetails produto) {
    final PurchaseParam compra = PurchaseParam(productDetails: produto);
    _iap.buyNonConsumable(purchaseParam: compra);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(t.planoAtual)),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _produtos.length,
              itemBuilder: (_, i) {
                final produto = _produtos[i];
                return ListTile(
                  title: Text(produto.title),
                  subtitle: Text(produto.description),
                  trailing: Text(produto.price),
                  onTap: () => _comprar(produto),
                );
              },
            ),
    );
  }
}
