import 'package:flutter/material.dart';

/// Cores que não têm um slot dedicado no [ColorScheme] padrão do Material 3
/// (sucesso/aviso/informação/perigo/neutro), usadas para status de
/// atividade, status de participante e variantes de feedback (snackbars).
///
/// [ColorScheme.primary]/[ColorScheme.secondary]/[ColorScheme.tertiary]/
/// [ColorScheme.error] continuam sendo a fonte para o que já tem slot lá —
/// esta extensão cobre só o que faltava.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.danger,
    required this.onDanger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.neutral,
    required this.onNeutral,
    required this.neutralContainer,
    required this.onNeutralContainer,
  });

  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  final Color info;
  final Color onInfo;
  final Color infoContainer;
  final Color onInfoContainer;

  final Color danger;
  final Color onDanger;
  final Color dangerContainer;
  final Color onDangerContainer;

  final Color neutral;
  final Color onNeutral;
  final Color neutralContainer;
  final Color onNeutralContainer;

  // Migra 1:1 a paleta que já existia hardcoded (e duplicada) em
  // atividade_card.dart (_corPorStatus/_corStatusParticipante).
  static const light = AppSemanticColors(
    success: Color(0xFF16A34A),
    onSuccess: Colors.white,
    successContainer: Color(0x1F16A34A),
    onSuccessContainer: Color(0xFF15803D),
    warning: Color(0xFFD97706),
    onWarning: Colors.white,
    warningContainer: Color(0x1FD97706),
    onWarningContainer: Color(0xFFB45309),
    info: Color(0xFF2563EB),
    onInfo: Colors.white,
    infoContainer: Color(0x1F2563EB),
    onInfoContainer: Color(0xFF1D4ED8),
    danger: Color(0xFFDC2626),
    onDanger: Colors.white,
    dangerContainer: Color(0x1FDC2626),
    onDangerContainer: Color(0xFFB91C1C),
    neutral: Color(0xFF64748B),
    onNeutral: Colors.white,
    neutralContainer: Color(0x1F64748B),
    onNeutralContainer: Color(0xFF475569),
  );

  // Ainda não usada (o app só tem tema claro hoje) — fica pronta para
  // quando um AppTheme.dark existir, sem precisar redesenhar a paleta.
  static const dark = AppSemanticColors(
    success: Color(0xFF4ADE80),
    onSuccess: Color(0xFF052E16),
    successContainer: Color(0x334ADE80),
    onSuccessContainer: Color(0xFF86EFAC),
    warning: Color(0xFFFBBF24),
    onWarning: Color(0xFF451A03),
    warningContainer: Color(0x33FBBF24),
    onWarningContainer: Color(0xFFFCD34D),
    info: Color(0xFF60A5FA),
    onInfo: Color(0xFF0C1E3D),
    infoContainer: Color(0x3360A5FA),
    onInfoContainer: Color(0xFF93C5FD),
    danger: Color(0xFFF87171),
    onDanger: Color(0xFF450A0A),
    dangerContainer: Color(0x33F87171),
    onDangerContainer: Color(0xFFFCA5A5),
    neutral: Color(0xFF94A3B8),
    onNeutral: Color(0xFF0F172A),
    neutralContainer: Color(0x3394A3B8),
    onNeutralContainer: Color(0xFFCBD5E1),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
    Color? onInfoContainer,
    Color? danger,
    Color? onDanger,
    Color? dangerContainer,
    Color? onDangerContainer,
    Color? neutral,
    Color? onNeutral,
    Color? neutralContainer,
    Color? onNeutralContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
      onInfoContainer: onInfoContainer ?? this.onInfoContainer,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      dangerContainer: dangerContainer ?? this.dangerContainer,
      onDangerContainer: onDangerContainer ?? this.onDangerContainer,
      neutral: neutral ?? this.neutral,
      onNeutral: onNeutral ?? this.onNeutral,
      neutralContainer: neutralContainer ?? this.neutralContainer,
      onNeutralContainer: onNeutralContainer ?? this.onNeutralContainer,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    Color m(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      success: m(success, other.success),
      onSuccess: m(onSuccess, other.onSuccess),
      successContainer: m(successContainer, other.successContainer),
      onSuccessContainer: m(onSuccessContainer, other.onSuccessContainer),
      warning: m(warning, other.warning),
      onWarning: m(onWarning, other.onWarning),
      warningContainer: m(warningContainer, other.warningContainer),
      onWarningContainer: m(onWarningContainer, other.onWarningContainer),
      info: m(info, other.info),
      onInfo: m(onInfo, other.onInfo),
      infoContainer: m(infoContainer, other.infoContainer),
      onInfoContainer: m(onInfoContainer, other.onInfoContainer),
      danger: m(danger, other.danger),
      onDanger: m(onDanger, other.onDanger),
      dangerContainer: m(dangerContainer, other.dangerContainer),
      onDangerContainer: m(onDangerContainer, other.onDangerContainer),
      neutral: m(neutral, other.neutral),
      onNeutral: m(onNeutral, other.onNeutral),
      neutralContainer: m(neutralContainer, other.neutralContainer),
      onNeutralContainer: m(onNeutralContainer, other.onNeutralContainer),
    );
  }
}
