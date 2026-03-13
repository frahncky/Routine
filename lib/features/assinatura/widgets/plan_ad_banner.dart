import 'package:flutter/material.dart';

class PlanAdBanner extends StatelessWidget {
  const PlanAdBanner({
    super.key,
    required this.message,
    this.useGradient = true,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final bool useGradient;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: useGradient
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFF0DA), Color(0xFFFFD7A8)],
              )
            : null,
        color: useGradient ? null : const Color(0xFFFFF0DA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF5A524), width: 1.1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.70),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.campaign_outlined, color: scheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: onAction,
              child: Text(actionLabel ?? 'Ver planos'),
            ),
          ],
        ],
      ),
    );
  }
}
