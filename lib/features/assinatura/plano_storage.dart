import 'package:routine/features/assinatura/plan_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlanoStorage {
  static const _chavePlano = 'plano_usuario';

  static Future<void> salvarPlano(String plano) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_chavePlano, PlanRules.normalize(plano));
  }

  static Future<String> carregarPlano() async {
    final prefs = await SharedPreferences.getInstance();
    return PlanRules.normalize(prefs.getString(_chavePlano));
  }
}
