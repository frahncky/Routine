import 'package:flutter/material.dart';

class PlanLockedCard extends StatelessWidget {
  const PlanLockedCard({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.centered = true,
    this.icon = Icons.lock_outline,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool centered;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final action = onAction != null
        ? ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.upgrade),
            label: Text(actionLabel ?? 'Ver planos'),
          )
        : const SizedBox.shrink();

    if (centered) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Colors.grey.shade600),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            if (onAction != null) const SizedBox(height: 16),
            action,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 26, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(message),
                  ],
                ),
              ),
            ],
          ),
          if (onAction != null) ...[
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerLeft, child: action),
          ],
        ],
      ),
    );
  }
}
