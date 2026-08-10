import 'package:flutter/material.dart';
import 'package:routine/theme/app_semantic_colors.dart';

/// Uma ação selecionável em [showActionDialog].
class DialogAction<T> {
  const DialogAction({
    required this.label,
    required this.value,
    this.isDestructive = false,
  });

  final String label;
  final T value;
  final bool isDestructive;
}

/// Diálogo genérico de múltiplas ações — sempre inclui um botão de cancelar
/// que fecha retornando `null`. Ações marcadas `isDestructive` usam a cor
/// de perigo do tema em vez de cor hardcoded por call-site.
Future<T?> showActionDialog<T>(
  BuildContext context, {
  required String title,
  required String message,
  required List<DialogAction<T>> actions,
  String cancelLabel = 'Cancelar',
}) {
  final danger = Theme.of(context).extension<AppSemanticColors>()!.danger;
  return showDialog<T>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelLabel),
        ),
        for (final action in actions)
          TextButton(
            onPressed: () => Navigator.of(context).pop(action.value),
            style: action.isDestructive
                ? TextButton.styleFrom(foregroundColor: danger)
                : null,
            child: Text(action.label),
          ),
      ],
    ),
  );
}

/// Wrapper binário de [showActionDialog] para o caso comum "Excluir X?".
/// Retorna `true` só quando o usuário confirma explicitamente.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  bool destructive = false,
}) async {
  final result = await showActionDialog<bool>(
    context,
    title: title,
    message: message,
    cancelLabel: cancelLabel,
    actions: [
      DialogAction(label: confirmLabel, value: true, isDestructive: destructive),
    ],
  );
  return result ?? false;
}
