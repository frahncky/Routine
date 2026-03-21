// Serviço de lógica de planos.
import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:routine/models/usuario.dart';

class PlanoService {
  static final PlanoService _instance = PlanoService._internal();
  factory PlanoService() => _instance;
  PlanoService._internal();

  static const int _limitePremium = 1 << 30;

  /// Limite de atividades por plano.
  static const Map<String, int> _limitesPorPlano = {
    PlanRules.gratis: 3,
    PlanRules.basico: 20,
    PlanRules.premium: _limitePremium,
  };

  static const List<String> planosDisponiveis = [
    PlanRules.gratis,
    PlanRules.basico,
    PlanRules.premium,
  ];

  /// Retorna o limite de atividades permitido para o plano do usuário.
  int obterLimitePara(Usuario usuario) {
    return obterLimiteDoPlano(usuario.plano);
  }

  /// Retorna o limite de atividades para um plano.
  int obterLimiteDoPlano(String plano) {
    final normalized = PlanRules.normalize(plano);
    return _limitesPorPlano[normalized] ?? _limitesPorPlano[PlanRules.gratis]!;
  }

  /// Informa se o plano possui limite prático de atividades.
  bool planoTemLimite(String plano) {
    return !PlanRules.hasFullAccess(plano);
  }

  /// Valida se uma nova atividade pode ser criada para este plano.
  bool podeAdicionarAtividade({
    required String plano,
    required int totalAtividades,
  }) {
    if (!planoTemLimite(plano)) return true;
    final totalAtual = totalAtividades < 0 ? 0 : totalAtividades;
    return totalAtual < obterLimiteDoPlano(plano);
  }

  /// Retorna quantas atividades ainda podem ser criadas no plano.
  int atividadesRestantes({
    required String plano,
    required int totalAtividades,
  }) {
    if (!planoTemLimite(plano)) return _limitePremium;
    final totalAtual = totalAtividades < 0 ? 0 : totalAtividades;
    final restante = obterLimiteDoPlano(plano) - totalAtual;
    return restante < 0 ? 0 : restante;
  }

  /// Retorna a lista dos planos disponíveis.
  List<String> listarPlanosDisponiveis() {
    return List<String>.unmodifiable(planosDisponiveis);
  }

  /// Simula a mudança de plano.
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

  /// Retorna uma descrição do plano.
  String descricaoPlano(String plano) {
    switch (PlanRules.normalize(plano)) {
      case PlanRules.basico:
        return 'Sem anúncios e agenda pessoal.';
      case PlanRules.premium:
        return 'Sem anúncios e experiência colaborativa completa.';
      case PlanRules.gratis:
      default:
        return 'Com anúncios e agenda pessoal.';
    }
  }
}

