// Servico de logica de planos.
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/models/usuario.dart';

class PlanoService {
  static final PlanoService _instance = PlanoService._internal();
  factory PlanoService() => _instance;
  PlanoService._internal();

  /// Simula o limite de atividades por plano.
  final Map<String, int> _limitesPorPlano = {
    PlanRules.gratis: 3,
    PlanRules.basico: 20,
    PlanRules.premium: 9999,
  };

  static final List<String> planosDisponiveis = [
    PlanRules.gratis,
    PlanRules.basico,
    PlanRules.premium,
  ];

  /// Retorna o limite de atividades permitido para o plano do usuario.
  int obterLimitePara(Usuario usuario) {
    final normalized = PlanRules.normalize(usuario.plano);
    return _limitesPorPlano[normalized] ?? 0;
  }

  /// Retorna a lista dos planos disponiveis.
  List<String> listarPlanosDisponiveis() {
    return List<String>.from(planosDisponiveis);
  }

  /// Simula a mudanca de plano.
  Future<Usuario> mudarPlano(Usuario usuario, String novoPlano) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final normalized = PlanRules.normalize(novoPlano);

    return Usuario(
      id: usuario.id,
      nome: usuario.nome,
      email: usuario.email,
      fotoUrl: usuario.fotoUrl,
      plano: normalized,
    );
  }

  /// Retorna uma descricao do plano.
  String descricaoPlano(String plano) {
    switch (PlanRules.normalize(plano)) {
      case PlanRules.basico:
        return 'Sem anuncios e agenda pessoal.';
      case PlanRules.premium:
        return 'Sem anuncios e experiencia colaborativa completa.';
      case PlanRules.gratis:
      default:
        return 'Com anuncios e agenda pessoal.';
    }
  }
}
