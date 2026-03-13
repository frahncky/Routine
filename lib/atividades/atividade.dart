import 'dart:convert';

import 'package:flutter/material.dart';

class AtividadeStatus {
  static const pendente = 'Pendente';
  static const concluida = 'Concluida';
  static const cancelada = 'Cancelada';
  static const andamento = 'Andamento';
  static const atrasada = 'Atrasada';

  static String normalize(String? value) {
    if (value == null || value.isEmpty) return pendente;
    final normalized = value.trim().toLowerCase();
    if (normalized == 'concluida' || normalized == 'concluída') {
      return concluida;
    }
    if (normalized == 'cancelada') return cancelada;
    if (normalized == 'andamento') return andamento;
    if (normalized == 'atrasada') return atrasada;
    if (normalized == 'pendente') return pendente;
    return value;
  }
}

class ParticipanteStatus {
  static const pendente = 'pendente';
  static const aceito = 'aceito';
  static const recusado = 'recusado';
  static const atrasado = 'atrasado';

  static String normalize(String? value) {
    if (value == null || value.trim().isEmpty) return pendente;
    final normalized = value.trim().toLowerCase();
    if (normalized == 'aceito' || normalized == 'accepted') return aceito;
    if (normalized == 'recusado' ||
        normalized == 'declined' ||
        normalized == 'cancelado' ||
        normalized == 'cancelada') {
      return recusado;
    }
    if (normalized == atrasado || normalized == 'late') return atrasado;
    return pendente;
  }
}

class Atividade {
  final int id;
  final String titulo;
  final String descricao;
  final DateTime data;
  final TimeOfDay horaInicio;
  final TimeOfDay horaFim;
  String status;
  final List<Participante> participantes;
  bool repetirSemanalmente;
  List<int> diasDaSemana;

  Atividade({
    required this.id,
    required this.titulo,
    required this.descricao,
    required this.data,
    required this.horaInicio,
    required this.horaFim,
    required this.status,
    required this.participantes,
    this.repetirSemanalmente = false,
    this.diasDaSemana = const [],
  });

  factory Atividade.fromMap(Map<String, dynamic> map) {
    List<Participante> participantes = [];
    if (map['participants'] is String) {
      try {
        final decoded = jsonDecode(map['participants']);
        if (decoded is List) {
          participantes = decoded
              .map((x) => Participante.fromMap(x))
              .toList()
              .cast<Participante>();
        }
      } catch (_) {}
    } else if (map['participants'] is List) {
      participantes = (map['participants'] as List)
          .map((x) => Participante.fromMap(x))
          .toList()
          .cast<Participante>();
    }

    return Atividade(
      id: map['id'],
      titulo: map['title']?.toString() ?? 'Sem titulo',
      descricao: map['describe']?.toString() ?? '',
      data: DateTime.fromMillisecondsSinceEpoch(map['date']),
      horaInicio: _parseTime(map['initHour'] ?? '00:00'),
      horaFim: _parseTime(map['endtHour'] ?? '00:00'),
      status: AtividadeStatus.normalize(map['status']?.toString()),
      participantes: participantes,
      repetirSemanalmente: map['repetirSemanalmente'] == 1,
      diasDaSemana: (map['diasDaSemana'] as String?)
              ?.split(',')
              .map((e) => int.tryParse(e) ?? 0)
              .where((e) => e != 0)
              .toList() ??
          [],
    );
  }

  static TimeOfDay _parseTime(String timeString) {
    final timeParts = timeString.split(':');
    return TimeOfDay(
      hour: int.parse(timeParts[0]),
      minute: int.parse(timeParts[1]),
    );
  }

  Map<String, dynamic> toMap() {
    final initHour =
        '${horaInicio.hour.toString().padLeft(2, '0')}:${horaInicio.minute.toString().padLeft(2, '0')}';
    final endHour =
        '${horaFim.hour.toString().padLeft(2, '0')}:${horaFim.minute.toString().padLeft(2, '0')}';

    final map = <String, dynamic>{
      'title': titulo,
      'describe': descricao,
      'date': data.millisecondsSinceEpoch,
      'initHour': initHour,
      'endtHour': endHour,
      'status': AtividadeStatus.normalize(status),
      'participants': jsonEncode(participantes.map((p) => p.toMap()).toList()),
      'repetirSemanalmente': repetirSemanalmente ? 1 : 0,
      'diasDaSemana': diasDaSemana.join(','),
    };
    if (id != 0) {
      map['id'] = id;
    }
    return map;
  }

  Atividade copyWith({
    int? id,
    String? titulo,
    String? descricao,
    DateTime? data,
    TimeOfDay? horaInicio,
    TimeOfDay? horaFim,
    String? status,
    List<Participante>? participantes,
    bool? repetirSemanalmente,
    List<int>? diasDaSemana,
  }) {
    return Atividade(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      descricao: descricao ?? this.descricao,
      data: data ?? this.data,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFim: horaFim ?? this.horaFim,
      status: AtividadeStatus.normalize(status ?? this.status),
      participantes: participantes ?? this.participantes,
      repetirSemanalmente: repetirSemanalmente ?? this.repetirSemanalmente,
      diasDaSemana: diasDaSemana ?? this.diasDaSemana,
    );
  }
}

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
    this.status = ParticipanteStatus.pendente,
    this.atrasoMinutos,
  });

  Map<String, dynamic> toMap() {
    final normalizedStatus = ParticipanteStatus.normalize(status);
    return {
      'name': nome,
      'email': email,
      'avatarUrl': fotoUrl,
      'status': normalizedStatus,
      'lateMinutes': normalizedStatus == ParticipanteStatus.atrasado
          ? atrasoMinutos
          : null,
    };
  }

  factory Participante.fromMap(Map<String, dynamic> map) {
    final lateRaw = map['lateMinutes'];
    int? lateMinutes;
    if (lateRaw is int) {
      lateMinutes = lateRaw;
    } else if (lateRaw is String) {
      lateMinutes = int.tryParse(lateRaw);
    }
    return Participante(
      nome: map['name'],
      email: map['email'],
      fotoUrl: map['avatarUrl'],
      status: ParticipanteStatus.normalize(map['status']?.toString()),
      atrasoMinutos: lateMinutes,
    );
  }

  static const Object _copySentinel = Object();

  Participante copyWith({
    String? nome,
    String? email,
    String? fotoUrl,
    String? status,
    Object? atrasoMinutos = _copySentinel,
  }) {
    final resolvedStatus = ParticipanteStatus.normalize(status ?? this.status);
    final resolvedLateMinutes =
        atrasoMinutos == _copySentinel ? this.atrasoMinutos : atrasoMinutos;
    return Participante(
      nome: nome ?? this.nome,
      email: email ?? this.email,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      status: resolvedStatus,
      atrasoMinutos: resolvedStatus == ParticipanteStatus.atrasado
          ? resolvedLateMinutes as int?
          : null,
    );
  }
}
