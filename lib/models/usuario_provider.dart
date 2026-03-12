import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'usuario.dart';

class UsuarioProvider extends ChangeNotifier {
  late Usuario _usuario;

  Usuario get usuario => _usuario;

 UsuarioProvider([Usuario? usuario]) {
  _usuario = usuario ?? Usuario.vazio();
}




  void carregarUsuario(Usuario usuario) {
    _usuario = usuario;
    notifyListeners();
  }

  Future<void> atualizarNome(String novoNome) async {
    _usuario = Usuario(
      id: _usuario.id,
      nome: novoNome,
      email: _usuario.email,
      fotoUrl: _usuario.fotoUrl,
      plano: _usuario.plano,
    );
    notifyListeners();
  }

  Future<void> atualizarEmail(String novoEmail) async {
    _usuario = Usuario(
      id: _usuario.id,
      nome: _usuario.nome,
      email: novoEmail,
      fotoUrl: _usuario.fotoUrl,
      plano: _usuario.plano,
    );
    notifyListeners();
  }

  Future<void> atualizarFoto(String caminhoFoto) async {
    _usuario = Usuario(
      id: _usuario.id,
      nome: _usuario.nome,
      email: _usuario.email,
      fotoUrl: caminhoFoto,
      plano: _usuario.plano,
    );
    notifyListeners();
  }

  Future<void> atualizarPlano(String novoPlano) async {
  _usuario = Usuario(
    id: _usuario.id,
    nome: _usuario.nome,
    email: _usuario.email,
    fotoUrl: _usuario.fotoUrl,
    plano: novoPlano,
  );
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('plano', novoPlano);
  notifyListeners();
}



  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _usuario = Usuario.vazio();
    notifyListeners();
  }

  Future<void> deletarConta() async {
    // await http.delete('https://suaapi.com/usuarios/${_usuario.id}');
    await logout();
  }

  Future<void> verificarLogin() async {
  final prefs = await SharedPreferences.getInstance();
  final id = prefs.getString('id');
  final nome = prefs.getString('nome');
  final email = prefs.getString('email');
  final foto = prefs.getString('fotoUrl');
  final plano = prefs.getString('plano') ?? 'Gratuito';

  if (id != null && nome != null && email != null && foto != null) {
    _usuario = Usuario(
      id: id,
      nome: nome,
      email: email,
      fotoUrl: foto,
      plano: plano,
    );
  } else {
    _usuario = Usuario.vazio();
  }
  notifyListeners();
}

}
