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
  });

  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onItemTap;
  final Color backgroundColor;
  final Color activeColor;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          height: 78,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: activeColor.withValues(alpha: 0.22),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: List.generate(icons.length, (index) {
              final isSelected = selectedIndex == index;
              return Expanded(
                child: GestureDetector(
                  key: Key('bottom_nav_item_$index'),
                  onTap: () => onItemTap(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                activeColor.withValues(alpha: 0.20),
                                activeColor.withValues(alpha: 0.08),
                              ],
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icons[index],
                          key: Key('bottom_nav_icon_$index'),
                          size: 22,
                          color: isSelected
                              ? activeColor
                              : backgroundColor.withValues(alpha: 0.55),
                        ),
                        const SizedBox(height: 3),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          child: isSelected
                              ? AnimatedOpacity(
                                  opacity: 1,
                                  duration: const Duration(milliseconds: 180),
                                  child: Text(
                                    labels[index],
                                    key: Key('bottom_nav_label_$index'),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: activeColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
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
