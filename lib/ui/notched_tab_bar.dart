import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

class NotchedTabBar extends StatelessWidget {
  const NotchedTabBar({
    super.key,
    required this.index,
    required this.onChanged,
    required this.onCreate,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onCreate;

  static const _buttonSize = 54.0;
  static const _barHeight = 72.0;
  static const _overhang = 26.0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final barColor = dark ? const Color(0xFF1B2436) : Colors.white;
    final idle = dark ? const Color(0xFFAEB6C2) : const Color(0xFF4A5160);
    final active = dark ? accentDark : accent;
    final buttonBg = dark ? accentDark : accent;
    final buttonFg = dark ? const Color(0xFF06241F) : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: SizedBox(
        height: _overhang + _barHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _barHeight,
              child: CustomPaint(
                painter: _NotchedBarPainter(
                  color: barColor,
                  shadow: dark ? Colors.black54 : const Color(0x22152033),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TabSlot(
                          icon: Icons.home_rounded,
                          label: 'Accueil',
                          selected: index == 0,
                          idle: idle,
                          active: active,
                          onTap: () => onChanged(0),
                        ),
                      ),
                      Expanded(
                        child: _TabSlot(
                          icon: Icons.calendar_today_rounded,
                          label: 'Calendrier',
                          selected: index == 1,
                          idle: idle,
                          active: active,
                          onTap: () => onChanged(1),
                        ),
                      ),
                      const SizedBox(width: 72),
                      Expanded(
                        child: _TabSlot(
                          icon: Icons.bar_chart_rounded,
                          label: 'Bilan',
                          selected: index == 2,
                          idle: idle,
                          active: active,
                          onTap: () => onChanged(2),
                        ),
                      ),
                      Expanded(
                        child: _TabSlot(
                          icon: Icons.person_rounded,
                          label: 'Profil',
                          selected: index == 3,
                          idle: idle,
                          active: active,
                          onTap: () => onChanged(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: Tooltip(
                  message: 'Créer une tâche',
                  child: Material(
                    color: buttonBg,
                    elevation: 4,
                    shadowColor: buttonBg.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: onCreate,
                      child: SizedBox(
                        width: _buttonSize,
                        height: _buttonSize,
                        child: Icon(Icons.add, color: buttonFg, size: 30),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.icon,
    required this.label,
    required this.selected,
    required this.idle,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color idle;
  final Color active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? active : idle;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NotchedBarPainter extends CustomPainter {
  const _NotchedBarPainter({required this.color, required this.shadow});

  final Color color;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _notchedBarPath(size);
    canvas.drawShadow(path, shadow, 16, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _NotchedBarPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.shadow != shadow;
  }
}

Path _notchedBarPath(Size size) {
  final width = size.width;
  final height = size.height;
  const corner = 32.0;
  final centerX = width / 2;
  // Same center as the round button, so the scoop is a true circle around it.
  const notchRadius = 33.0;
  const notchCenterY = 1.0;
  final left = _notchShoulder(centerX, notchCenterY, notchRadius, left: true);
  final right = _notchShoulder(centerX, notchCenterY, notchRadius, left: false);

  return Path()
    ..moveTo(corner, 0)
    ..lineTo(left.start.dx, 0)
    ..quadraticBezierTo(
      left.control.dx,
      left.control.dy,
      left.touch.dx,
      left.touch.dy,
    )
    ..arcToPoint(
      right.touch,
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    )
    ..quadraticBezierTo(right.control.dx, right.control.dy, right.start.dx, 0)
    ..lineTo(width - corner, 0)
    ..arcToPoint(Offset(width, corner), radius: const Radius.circular(corner))
    ..lineTo(width, height - corner)
    ..arcToPoint(
      Offset(width - corner, height),
      radius: const Radius.circular(corner),
    )
    ..lineTo(corner, height)
    ..arcToPoint(
      Offset(0, height - corner),
      radius: const Radius.circular(corner),
    )
    ..lineTo(0, corner)
    ..arcToPoint(const Offset(corner, 0), radius: const Radius.circular(corner))
    ..close();
}

typedef _Shoulder = ({Offset start, Offset control, Offset touch});

_Shoulder _notchShoulder(
  double centerX,
  double centerY,
  double radius, {
  required bool left,
}) {
  const drop = 0.5;
  final theta = left ? math.pi - drop : drop;
  final touch = Offset(
    centerX + radius * math.cos(theta),
    centerY + radius * math.sin(theta),
  );
  final tangentX = left ? math.sin(theta) : -math.sin(theta);
  final tangentY = left ? -math.cos(theta) : math.cos(theta);
  final scale = touch.dy / tangentY;
  final control = Offset(touch.dx - scale * tangentX, 0);
  final start = Offset(control.dx + (left ? -12 : 12), 0);
  return (start: start, control: control, touch: touch);
}
