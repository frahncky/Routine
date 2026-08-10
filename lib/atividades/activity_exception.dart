import 'dart:convert';

/// Classe de domínio tipada para uma linha da tabela `activity_exception` —
/// representa um desvio pontual de uma ocorrência de atividade recorrente
/// (excluída naquele dia, ou editada com campos sobrescritos, incluindo o
/// `status` que alimenta a sequência/streak de hábito).
class ActivityException {
  const ActivityException({
    required this.id,
    required this.atividadeId,
    required this.data,
    required this.tipo,
    required this.camposEditados,
  });

  static const excluida = 'excluida';
  static const editada = 'editada';

  final int id;
  final int atividadeId;
  final DateTime data;
  final String tipo;
  final Map<String, dynamic>? camposEditados;

  factory ActivityException.fromMap(Map<String, dynamic> map) {
    return ActivityException(
      id: map['id'] as int,
      atividadeId: map['atividade_id'] as int,
      data: DateTime.fromMillisecondsSinceEpoch(map['data'] as int),
      tipo: map['tipo']?.toString() ?? '',
      camposEditados: _decodeCamposEditados(map['campos_editados']),
    );
  }

  String? get statusOverride => camposEditados?['status']?.toString();

  static Map<String, dynamic>? _decodeCamposEditados(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    final text = raw.toString();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }
}
