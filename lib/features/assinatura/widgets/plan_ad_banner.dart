import 'package:flutter/material.dart';

class PlanAdBanner extends StatelessWidget {
  const PlanAdBanner({
    super.key,
    required this.message,
    this.useGradient = true,
  });

  final String message;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: useGradient
            ? const LinearGradient(
                colors: [Color(0xFFFFE7C2), Color(0xFFFFD39A)],
              )
            : null,
        color: useGradient ? null : const Color(0xFFFFF0CC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
