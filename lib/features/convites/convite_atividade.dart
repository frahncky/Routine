import 'package:cloud_firestore/cloud_firestore.dart';

class ConviteAtividade {
  const ConviteAtividade({
    required this.id,
    required this.ownerEmail,
    required this.ownerName,
    required this.participantEmail,
    required this.participantName,
    required this.activityTitle,
    required this.activityDate,
    required this.activityPayload,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String ownerEmail;
  final String ownerName;
  final String participantEmail;
  final String participantName;
  final String activityTitle;
  final DateTime activityDate;
  final Map<String, dynamic> activityPayload;
  final String status;
  final DateTime? createdAt;

  bool get isPending => status.toLowerCase() == 'pending';

  factory ConviteAtividade.fromMap(
    String id,
    Map<String, dynamic> map,
  ) {
    final payload = Map<String, dynamic>.from(
      map['activity_payload'] as Map<String, dynamic>? ?? <String, dynamic>{},
    );

    DateTime dateFromPayload = DateTime.now();
    final dateRaw = payload['date'];
    if (dateRaw is int) {
      dateFromPayload = DateTime.fromMillisecondsSinceEpoch(dateRaw);
    } else if (dateRaw is Timestamp) {
      dateFromPayload = dateRaw.toDate();
    }

    DateTime? created;
    final createdRaw = map['created_at'];
    if (createdRaw is Timestamp) {
      created = createdRaw.toDate();
    }

    return ConviteAtividade(
      id: id,
      ownerEmail: map['owner_email']?.toString() ?? '',
      ownerName: map['owner_name']?.toString() ?? 'Sem nome',
      participantEmail: map['participant_email']?.toString() ?? '',
      participantName: map['participant_name']?.toString() ?? '',
      activityTitle: map['activity_title']?.toString() ?? 'Atividade',
      activityDate: dateFromPayload,
      activityPayload: payload,
      status: map['status']?.toString().toLowerCase() ?? 'pending',
      createdAt: created,
    );
  }
}
