// Serviço de lógica de planos
import 'package:routine/models/usuario.dart';

class PlanoService {
  static final PlanoService _instance = PlanoService._internal();
  factory PlanoService() => _instance;
  PlanoService._internal();

  /// Simula o limite de atividades por plano
  final Map<String, int> _limitesPorPlano = {
    'gratuito': 3,
    'individual': 10,
    'familia': 50,
  };

  static var planosDisponiveis;

  /// Retorna o limite de atividades permitido para o plano do usuário
  int obterLimitePara(Usuario usuario) {
    return _limitesPorPlano[usuario.plano] ?? 0;
  }

  /// Retorna a lista dos planos disponíveis
  List<String> listarPlanosDisponiveis() {
    return _limitesPorPlano.keys.toList();
  }

  /// Simula a mudança de plano
  Future<Usuario> mudarPlano(Usuario usuario, String novoPlano) async {
    await Future.delayed(const Duration(milliseconds: 500));

    return Usuario(
      id: usuario.id,
      nome: usuario.nome,
      email: usuario.email,
      fotoUrl: usuario.fotoUrl,
      plano: novoPlano,
     // inicioAssinatura: DateTime.now(),
    );
  }

  /// Retorna uma descrição do plano (pode ser usado na tela de assinatura)
  String descricaoPlano(String plano) {
    switch (plano) {
      case 'Gratuito':
        return 'Até 3 atividades por semana';
      case 'Intermediario':
        return 'Até 10 atividades por semana';
      case 'ViP':
        return 'Até 50 atividades por semana e suporte a múltiplos usuários';
      default:
        return 'Plano desconhecido';
    }
  }
}
