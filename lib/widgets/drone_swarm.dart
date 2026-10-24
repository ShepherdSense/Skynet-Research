import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// A swarm of drones that flies across the screen on tab switches
/// (Draco, 2026-10-23). Pure decoration: non-interactive overlay,
/// ~900 ms, direction follows the tab movement (later tab → fly
/// right, earlier tab → fly left).
class DroneSwarmOverlay extends StatefulWidget {
  /// Bump this to (re)trigger a pass.
  final int trigger;

  /// True: left → right. False: right → left.
  final bool forward;

  const DroneSwarmOverlay({
    super.key,
    required this.trigger,
    required this.forward,
  });

  @override
  State<DroneSwarmOverlay> createState() => _DroneSwarmOverlayState();
}

class _DroneSwarmOverlayState extends State<DroneSwarmOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(DroneSwarmOverlay old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (!_ctrl.isAnimating && _ctrl.value == 0) {
            return const SizedBox.shrink();
          }
          return CustomPaint(
            size: Size.infinite,
            painter: _SwarmPainter(
              progress: Curves.easeInOut.transform(_ctrl.value),
              forward: widget.forward,
              hue: PlainRegsTheme.hueDeg,
            ),
          );
        },
      ),
    );
  }
}

class _DroneSpec {
  final double lane; // 0..1 of height
  final double size; // body width px
  final double speed; // progress multiplier
  final double offset; // starting offset in progress units
  final double bobPhase;
  const _DroneSpec(
    this.lane,
    this.size,
    this.speed,
    this.offset,
    this.bobPhase,
  );
}

/// Fixed pseudo-random swarm: 14 drones in staggered lanes.
const List<_DroneSpec> _swarm = [
  _DroneSpec(0.10, 30, 1.00, 0.00, 0.0),
  _DroneSpec(0.22, 20, 1.12, 0.05, 1.7),
  _DroneSpec(0.34, 36, 0.94, 0.10, 3.1),
  _DroneSpec(0.46, 18, 1.20, 0.02, 0.8),
  _DroneSpec(0.55, 26, 1.05, 0.14, 2.4),
  _DroneSpec(0.66, 22, 1.15, 0.07, 4.2),
  _DroneSpec(0.76, 32, 0.90, 0.18, 1.2),
  _DroneSpec(0.86, 16, 1.25, 0.04, 5.0),
  _DroneSpec(0.16, 14, 1.30, 0.16, 2.9),
  _DroneSpec(0.40, 15, 1.28, 0.20, 0.4),
  _DroneSpec(0.60, 34, 0.97, 0.22, 3.8),
  _DroneSpec(0.72, 17, 1.22, 0.12, 1.9),
  _DroneSpec(0.28, 24, 1.08, 0.24, 4.7),
  _DroneSpec(0.50, 13, 1.35, 0.26, 5.6),
];

class _SwarmPainter extends CustomPainter {
  final double progress;
  final bool forward;

  /// The user's colorway hue — the swarm's rim light, glow and
  /// LEDs follow the slider just like the rest of the app.
  final double hue;
  _SwarmPainter({
    required this.progress,
    required this.forward,
    required this.hue,
  });

  static const Color _body = Color(0xFF17131F);
  Color get _rim =>
      HSLColor.fromAHSL(1, hue, 0.87, 0.73).toColor();
  Color get _glow =>
      HSLColor.fromAHSL(0.4, hue, 0.87, 0.73).toColor();
  Color get _led =>
      HSLColor.fromAHSL(1, hue, 1.0, 0.84).toColor();

  @override
  void paint(Canvas canvas, Size size) {
    // Fade the whole pass in and out at the edges.
    final fade = math.sin(math.pi * progress.clamp(0.0, 1.0));
    if (fade <= 0.01) return;
    for (final d in _swarm) {
      // Each drone travels slightly more than the full width.
      final local = (progress * d.speed + d.offset).clamp(0.0, 1.15);
      final travel = (size.width + 140) * local - 70;
      final x = forward ? travel : size.width - travel;
      final bob = math.sin(progress * 10 + d.bobPhase) * 5;
      final y = size.height * d.lane + bob;
      final alpha = (fade * 255).round().clamp(0, 255);
      _drawDrone(canvas, Offset(x, y), d.size, alpha, flip: !forward);
    }
  }

  void _drawDrone(
    Canvas canvas,
    Offset c,
    double w,
    int alpha, {
    required bool flip,
  }) {
    final h = w * 0.62; // quadcopter, slight top-down slant
    final bodyPaint = Paint()..color = _body.withAlpha(alpha);
    final rimPaint = Paint()
      ..color = _rim.withAlpha((alpha * 0.55).round())
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    final glowPaint = Paint()
      ..color = _glow.withAlpha((alpha * 0.5).round())
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final ledPaint = Paint()..color = _led.withAlpha(alpha);

    // Purple glow under the drone.
    canvas.drawCircle(c, w * 0.42, glowPaint);

    final dir = flip ? -1.0 : 1.0;
    final arm = w * 0.5;
    // X arms.
    final armPaint = Paint()
      ..color = _body.withAlpha(alpha)
      ..strokeWidth = w * 0.13
      ..strokeCap = StrokeCap.round;
    for (final s in const [-1.0, 1.0]) {
      canvas.drawLine(
        c + Offset(-arm * 0.72, s * h * 0.42),
        c + Offset(arm * 0.72, -s * h * 0.42),
        armPaint,
      );
    }
    // Rotor discs at the four arm ends.
    for (final sx in const [-0.72, 0.72]) {
      for (final sy in const [-0.42, 0.42]) {
        final p = c + Offset(sx * arm, sy * h);
        canvas.drawCircle(p, w * 0.17, bodyPaint);
        canvas.drawCircle(p, w * 0.17, rimPaint);
      }
    }
    // Body: rounded rect, nose toward travel direction.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: c, width: w * 0.62, height: h * 0.72),
      Radius.circular(w * 0.14),
    );
    canvas.drawRRect(bodyRect, bodyPaint);
    canvas.drawRRect(bodyRect, rimPaint);
    // Nose LED.
    canvas.drawCircle(c + Offset(dir * w * 0.22, 0), w * 0.055, ledPaint);
    // Center light.
    canvas.drawCircle(c, w * 0.045, ledPaint);
  }

  @override
  bool shouldRepaint(_SwarmPainter old) =>
      old.progress != progress || old.forward != forward || old.hue != hue;
}
