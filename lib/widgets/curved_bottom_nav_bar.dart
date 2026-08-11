import 'package:flutter/material.dart';

class AnimatedCurvedBottomNavBar extends StatelessWidget {
  const AnimatedCurvedBottomNavBar({
    super.key,
    required this.icons,
    required this.selectedIndex,
    required this.onItemTap,
    required this.labels,
    this.backgroundColor = const Color(0xFF0F1E3A),
    this.activeColor = const Color(0xFF60A5FA),
    this.badgeCounts = const {},
    this.lockedIndices = const {},
    this.lockedLabel = 'Locked',
  })  : assert(icons.length == labels.length),
        assert(icons.length > 1);

  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onItemTap;
  final Color backgroundColor;
  final Color activeColor;
  final List<String> labels;

  /// Contagem de badge por índice de aba (ex.: `{2: 3}` mostra "3" na
  /// terceira aba). Índices ausentes ou com valor <= 0 não mostram badge.
  final Map<int, int> badgeCounts;

  /// Abas que continuam acessíveis para explicar o plano, mas cujo recurso
  /// principal exige upgrade. O ícone da aba é preservado e o bloqueio é
  /// comunicado por um pequeno badge.
  final Set<int> lockedIndices;

  /// Texto localizado usado no tooltip e na árvore de acessibilidade das
  /// abas bloqueadas.
  final String lockedLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Container(
          height: 70,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.68),
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.09),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(icons.length, (index) {
              final isSelected = selectedIndex == index;
              final isLocked = lockedIndices.contains(index);
              final badgeCount = badgeCounts[index] ?? 0;
              final semanticLabel =
                  isLocked ? '${labels[index]}. $lockedLabel' : labels[index];

              return Expanded(
                child: Semantics(
                  container: true,
                  selected: isSelected,
                  button: true,
                  label: semanticLabel,
                  child: Tooltip(
                    message: semanticLabel,
                    excludeFromSemantics: true,
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(15),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: Key('bottom_nav_item_$index'),
                        onTap: () => onItemTap(index),
                        borderRadius: BorderRadius.circular(15),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          constraints: const BoxConstraints(minHeight: 54),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? scheme.primaryContainer
                                    .withValues(alpha: 0.72)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Badge.count(
                                      count: badgeCount,
                                      isLabelVisible: badgeCount > 0,
                                      child: Icon(
                                        icons[index],
                                        key: Key('bottom_nav_icon_$index'),
                                        size: 21,
                                        color: isSelected
                                            ? activeColor
                                            : backgroundColor.withValues(
                                                alpha: 0.62,
                                              ),
                                      ),
                                    ),
                                    if (isLocked)
                                      Positioned(
                                        right: -8,
                                        bottom: -3,
                                        child: Container(
                                          width: 16,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: backgroundColor.withValues(
                                                alpha: 0.16,
                                              ),
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.lock_rounded,
                                            size: 10,
                                            color: isSelected
                                                ? activeColor
                                                : backgroundColor.withValues(
                                                    alpha: 0.72,
                                                  ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  labels[index],
                                  key: Key('bottom_nav_label_$index'),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? activeColor
                                        : backgroundColor.withValues(
                                            alpha: 0.68,
                                          ),
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    fontSize: 10.5,
                                    height: 1.05,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
