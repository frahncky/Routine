import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedCurvedBottomNavBar extends StatefulWidget {
  final List<IconData> icons;
  final int selectedIndex;
  final Function(int) onItemTap;
  final Color backgroundColor;
  final List<String> labels;

  const AnimatedCurvedBottomNavBar({
    required this.icons,
    required this.selectedIndex,
    required this.onItemTap,
    this.backgroundColor = const Color(0xFF1C1C2D),
    required this.labels,
  });

  @override
  _AnimatedCurvedBottomNavBarState createState() =>
      _AnimatedCurvedBottomNavBarState();
}

class _AnimatedCurvedBottomNavBarState extends State<AnimatedCurvedBottomNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curveAnim;
  double _currentX = 0;
  double _targetX = 0;
  final double _horizontalPadding = 10.0;
  int? _showingLabelIndex;
  Timer? _labelTimer;


  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _curveAnim = AlwaysStoppedAnimation(0.0);
  }

  void _updateCurve(double newX) {
    _curveAnim.removeListener(_onAnimUpdate);
    _curveAnim = Tween<double>(begin: _currentX, end: newX).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    )..addListener(_onAnimUpdate);
    _controller.forward(from: 0).then((_) => _currentX = newX);
  }

  void _onAnimUpdate() => setState(() {});

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth =
        (screenWidth - _horizontalPadding * 2) / widget.icons.length;
    _currentX =
        _horizontalPadding + itemWidth * widget.selectedIndex + itemWidth / 2;
    _curveAnim = AlwaysStoppedAnimation(_currentX);
  }

  @override
  void didUpdateWidget(covariant AnimatedCurvedBottomNavBar oldWidget) {
    _labelTimer?.cancel(); // cancela o anterior se existir

    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      final screenWidth = MediaQuery.of(context).size.width;
      final itemWidth =
          (screenWidth - _horizontalPadding * 2) / widget.icons.length;
      _targetX =
          _horizontalPadding + itemWidth * widget.selectedIndex + itemWidth / 2;
      _updateCurve(_targetX);

      _labelTimer = Timer(Duration(seconds: 2), () {
        setState(() {
          _showingLabelIndex = null;
        });
      });

      setState(() {
        _showingLabelIndex = widget.selectedIndex;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
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
                    int index = entry.key;
                    IconData icon = entry.value;
                    bool isSelected = index == widget.selectedIndex;

                    return GestureDetector(
                      onTap: () => widget.onItemTap(index),
                      child: Tooltip(
                        message: icon.toString(),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          alignment: Alignment(0, isSelected ? -0.6 : 0),
                          child: CircleAvatar(
                            backgroundColor: isSelected
                                ? Colors.blue.shade300
                                : Colors.transparent,
                            radius: 22,
                            child: Icon(
                              icon,
                              color:
                                  isSelected ? Colors.black : Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // Display label below the selected icon
              if (_showingLabelIndex != null)
  Positioned(
    bottom: 5,
    left: 0,
    right: 0,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: widget.labels.asMap().entries.map((entry) {
        int index = entry.key;
        String label = entry.value;

        return Expanded(
          child: Center(
            child: AnimatedOpacity(
              opacity: _showingLabelIndex == index ? 1.0 : 0.0,
              duration: Duration(milliseconds: 200),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.orange.shade300,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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

  @override
  void dispose() {
    _curveAnim.removeListener(_onAnimUpdate);
    _controller.dispose();
    _labelTimer?.cancel(); // só cancela se não for null
    super.dispose();
  }
}

class _BottomUnderIconCurvePainter extends CustomPainter {
  final double centerX;
  final Color color;

  _BottomUnderIconCurvePainter({
    required this.centerX,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = color;
    Path path = Path();

    final iconSize = 40.0;
    final padding = size.height * 0.12;
    final arcRadius = iconSize / 2 + padding;
    final cornerRadius = size.height * 0.1;

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
