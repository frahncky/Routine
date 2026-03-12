import 'package:shared_preferences/shared_preferences.dart';

Future<void> salvarDados(String nome, String email, String idioma, String? fotoPath) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('nome', nome);
  await prefs.setString('email', email);
  await prefs.setString('idioma', idioma);
  if (fotoPath != null) {
    await prefs.setString('fotoPerfil', fotoPath);
  }
}

Future<Map<String, dynamic>> carregarDados() async {
  final prefs = await SharedPreferences.getInstance();
  return {
    'nome': prefs.getString('nome') ?? 'João Silva',
    'email': prefs.getString('email') ?? 'joao@email.com',
    'idioma': prefs.getString('idioma') ?? 'pt',
    'fotoPerfil': prefs.getString('fotoPerfil'),
  };
}
