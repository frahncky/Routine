class Usuario {
  final String id;
  final String nome;
  final String email;
  final String fotoUrl;
  final String plano;

  Usuario({
    required this.id,
    required this.nome,
    required this.email,
    required this.fotoUrl,
    this.plano = 'Gratuito',
  });

  factory Usuario.vazio() => Usuario(id: '', nome: '', email: '', fotoUrl: '');


  factory Usuario.fromJson(Map<String, dynamic> json) {
    return Usuario(
      id: json['id'],
      nome: json['nome'],
      email: json['email'],
      fotoUrl: json['fotoUrl'],
      plano: json['plano'] ?? 'Gratuito',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'email': email,
      'fotoUrl': fotoUrl,
      'plano': plano,
    };
  }
}
