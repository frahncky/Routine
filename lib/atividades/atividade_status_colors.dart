import 'package:flutter/material.dart';
import 'package:routine/atividades/atividade.dart';
import 'package:routine/theme/app_semantic_colors.dart';

/// Fonte única da cor por status de atividade/participante — antes vivia
/// duplicada (com os mesmos valores hex reescritos) em `atividade_card.dart`.
extension AtividadeStatusColors on AppSemanticColors {
  Color forAtividadeStatus(String status) {
    switch (AtividadeStatus.normalize(status)) {
      case AtividadeStatus.concluida:
        return success;
      case AtividadeStatus.andamento:
        return info;
      case AtividadeStatus.atrasada:
        return danger;
      case AtividadeStatus.cancelada:
        return warning;
      default:
        return neutral;
    }
  }

  Color containerForAtividadeStatus(String status) {
    switch (AtividadeStatus.normalize(status)) {
      case AtividadeStatus.concluida:
        return successContainer;
      case AtividadeStatus.andamento:
        return infoContainer;
      case AtividadeStatus.atrasada:
        return dangerContainer;
      case AtividadeStatus.cancelada:
        return warningContainer;
      default:
        return neutralContainer;
    }
  }

  Color onContainerForAtividadeStatus(String status) {
    switch (AtividadeStatus.normalize(status)) {
      case AtividadeStatus.concluida:
        return onSuccessContainer;
      case AtividadeStatus.andamento:
        return onInfoContainer;
      case AtividadeStatus.atrasada:
        return onDangerContainer;
      case AtividadeStatus.cancelada:
        return onWarningContainer;
      default:
        return onNeutralContainer;
    }
  }

  Color forParticipanteStatus(String status) {
    switch (ParticipanteStatus.normalize(status)) {
      case ParticipanteStatus.aceito:
        return success;
      case ParticipanteStatus.recusado:
        return danger;
      case ParticipanteStatus.atrasado:
        return warning;
      default:
        return neutral;
    }
  }
}
