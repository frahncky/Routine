class Participante {
  final String nome;
  final String email;
  final String? fotoUrl;
  final String status; // 'aceito', 'pendente', 'recusado'

  Participante({
    required this.nome,
    required this.email,
    this.fotoUrl,
    this.status = 'pendente',
  });

  factory Participante.fromMap(Map<String, dynamic> map) {
    return Participante(
      nome: map['name'] as String,
      email: map['email'] as String,
      fotoUrl: map['avatarUrl'] as String?,
      status: map['status'] as String? ?? 'pendente',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nome,
      'email': email,
      'avatarUrl': fotoUrl,
      'status': status,
    };
  }

  Participante copyWith({
    String? nome,
    String? email,
    String? fotoUrl,
    String? status,
  }) {
    return Participante(
      nome: nome ?? this.nome,
      email: email ?? this.email,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Participante &&
        other.nome == nome &&
        other.email == email &&
        other.fotoUrl == fotoUrl &&
        other.status == status;
  }

  @override
  int get hashCode =>
      nome.hashCode ^ email.hashCode ^ fotoUrl.hashCode ^ status.hashCode;

  @override
  String toString() {
    return 'Participante(nome: $nome, email: $email, fotoUrl: $fotoUrl, status: $status)';
  }
}