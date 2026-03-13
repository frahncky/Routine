class Participante {
  final String nome;
  final String email;
  final String? fotoUrl;
  final String status;
  final int? atrasoMinutos;

  Participante({
    required this.nome,
    required this.email,
    this.fotoUrl,
    this.status = 'pendente',
    this.atrasoMinutos,
  });

  factory Participante.fromMap(Map<String, dynamic> map) {
    final lateRaw = map['lateMinutes'];
    int? lateMinutes;
    if (lateRaw is int) {
      lateMinutes = lateRaw;
    } else if (lateRaw is String) {
      lateMinutes = int.tryParse(lateRaw);
    }
    return Participante(
      nome: map['name'] as String,
      email: map['email'] as String,
      fotoUrl: map['avatarUrl'] as String?,
      status: map['status'] as String? ?? 'pendente',
      atrasoMinutos: lateMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': nome,
      'email': email,
      'avatarUrl': fotoUrl,
      'status': status,
      'lateMinutes': status == 'atrasado' ? atrasoMinutos : null,
    };
  }

  static const Object _copySentinel = Object();

  Participante copyWith({
    String? nome,
    String? email,
    String? fotoUrl,
    String? status,
    Object? atrasoMinutos = _copySentinel,
  }) {
    final resolvedStatus = status ?? this.status;
    final resolvedLateMinutes =
        atrasoMinutos == _copySentinel ? this.atrasoMinutos : atrasoMinutos;
    return Participante(
      nome: nome ?? this.nome,
      email: email ?? this.email,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      status: resolvedStatus,
      atrasoMinutos:
          resolvedStatus == 'atrasado' ? resolvedLateMinutes as int? : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Participante &&
        other.nome == nome &&
        other.email == email &&
        other.fotoUrl == fotoUrl &&
        other.status == status &&
        other.atrasoMinutos == atrasoMinutos;
  }

  @override
  int get hashCode =>
      nome.hashCode ^
      email.hashCode ^
      fotoUrl.hashCode ^
      status.hashCode ^
      atrasoMinutos.hashCode;

  @override
  String toString() {
    return 'Participante(nome: $nome, email: $email, fotoUrl: $fotoUrl, status: $status, atrasoMinutos: $atrasoMinutos)';
  }
}
