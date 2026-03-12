import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IdiomaProvider with ChangeNotifier {
  Locale _locale = const Locale('pt');

  Locale get locale => _locale;

  Future<void> carregarIdioma() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = Locale(prefs.getString('idioma') ?? 'pt');
    notifyListeners();
  }

  Future<void> atualizarIdioma(String novoIdioma) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('idioma', novoIdioma);
    _locale = Locale(novoIdioma);
    notifyListeners();
  }
}
