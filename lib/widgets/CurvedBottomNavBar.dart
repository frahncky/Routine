import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedCurvedBottomNavBar extends StatefulWidget {
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
  State<AnimatedCurvedBottomNavBar> createState() =>
      _AnimatedCurvedBottomNavBarState();
}

class _AnimatedCurvedBottomNavBarState extends State<AnimatedCurvedBottomNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _curveAnim;
  double _currentX = 0;
  int? _showingLabelIndex;
  Timer? _labelTimer;
  final double _horizontalPadding = 10;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _curveAnim = const AlwaysStoppedAnimation(0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentX = _resolveCenterX(widget.selectedIndex);
    _curveAnim = AlwaysStoppedAnimation(_currentX);
  }

  @override
  void didUpdateWidget(covariant AnimatedCurvedBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _animateTo(widget.selectedIndex);
      _labelTimer?.cancel();
      _showingLabelIndex = widget.selectedIndex;
      _labelTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() => _showingLabelIndex = null);
      });
    }
  }

  double _resolveCenterX(int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth =
        (screenWidth - (_horizontalPadding * 2)) / widget.icons.length;
    return _horizontalPadding + (itemWidth * index) + (itemWidth / 2);
  }

  void _animateTo(int index) {
    _curveAnim.removeListener(_onAnimUpdate);
    final targetX = _resolveCenterX(index);
    _curveAnim = Tween<double>(begin: _currentX, end: targetX).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(_onAnimUpdate);
    _controller.forward(from: 0).then((_) => _currentX = targetX);
  }

  void _onAnimUpdate() => setState(() {});

  @override
  void dispose() {
    _curveAnim.removeListener(_onAnimUpdate);
    _controller.dispose();
    _labelTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onBackground = Colors.white;
    return SizedBox(
      height: 92,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 62,
                child: CustomPaint(
                  painter: _BottomUnderIconCurvePainter(
                    centerX: _curveAnim.value,
                    color: widget.backgroundColor,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: _horizontalPadding),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: widget.icons.asMap().entries.map((entry) {
                    final index = entry.key;
                    final icon = entry.value;
                    final isSelected = index == widget.selectedIndex;

                    return GestureDetector(
                      onTap: () => widget.onItemTap(index),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(0, isSelected ? -0.62 : 0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOut,
                          width: isSelected ? 46 : 40,
                          height: isSelected ? 46 : 40,
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(
                                    colors: [
                                      widget.activeColor,
                                      widget.activeColor
                                          .withValues(alpha: 0.82),
                                    ],
                                  )
                                : null,
                            color: isSelected ? null : Colors.transparent,
                            shape: BoxShape.circle,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: widget.activeColor
                                          .withValues(alpha: 0.35),
                                      blurRadius: 14,
                                      offset: const Offset(0, 5),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            icon,
                            color: isSelected
                                ? Colors.white
                                : onBackground.withValues(alpha: 0.86),
                            size: 24,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_showingLabelIndex != null)
                Positioned(
                  bottom: 6,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: widget.labels.asMap().entries.map((entry) {
                      final index = entry.key;
                      final label = entry.value;
                      final visible = _showingLabelIndex == index;
                      return Expanded(
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: visible ? 1 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BottomUnderIconCurvePainter extends CustomPainter {
  _BottomUnderIconCurvePainter({
    required this.centerX,
    required this.color,
  });

  final double centerX;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    final iconSize = 42.0;
    final padding = size.height * 0.14;
    final arcRadius = iconSize / 2 + padding;
    final cornerRadius = size.height * 0.14;

    final left = math.max(centerX - arcRadius, 0).toDouble();
    final right = math.min(centerX + arcRadius, size.width).toDouble();

    path.moveTo(0, cornerRadius);
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
      clockwise: true,
    );
    path.lineTo(left, 0);
    path.arcToPoint(
      Offset(right, 0),
      radius: Radius.circular(arcRadius),
      clockwise: false,
    );
    path.lineTo(size.width - cornerRadius, 0);
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: true,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BottomUnderIconCurvePainter oldDelegate) {
    return oldDelegate.centerX != centerX || oldDelegate.color != color;
  }
}
