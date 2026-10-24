import 'package:flutter/material.dart';

import '../theme.dart';

/// The landing-page colorway picker (Draco, 2026-10-23): a rainbow
/// slider that re-hues the whole app live, plus preset dots.
class HueSlider extends StatelessWidget {
  final ThemeHueController controller;
  const HueSlider({super.key, required this.controller});

  static const List<(String, double)> _presets = [
    ('Trail violet', 262),
    ('Blue', 215),
    ('Green', 135),
    ('Gold', 42),
    ('Red', 350),
    ('Pink', 318),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final hue = controller.hue;
        final thumb = HSLColor.fromAHSL(1, hue, 0.85, 0.65).toColor();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette_outlined,
                  size: 18,
                  color: PlainRegsTheme.accent,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Site color',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if ((hue - ThemeHueController.defaultHue).abs() > 0.5)
                  TextButton(
                    onPressed: () =>
                        controller.setHue(ThemeHueController.defaultHue),
                    child: const Text('Reset'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                void update(double dx) {
                  controller.setHue((dx / w).clamp(0.0, 1.0) * 360);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => update(d.localPosition.dx),
                  onHorizontalDragUpdate: (d) => update(d.localPosition.dx),
                  child: SizedBox(
                    height: 34,
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(7),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFFF0000),
                                Color(0xFFFFFF00),
                                Color(0xFF00FF00),
                                Color(0xFF00FFFF),
                                Color(0xFF0000FF),
                                Color(0xFFFF00FF),
                                Color(0xFFFF0000),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: (hue / 360) * (w - 26),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: thumb,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(color: Colors.black54, blurRadius: 4),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (name, h) in _presets)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Tooltip(
                      message: name,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => controller.setHue(h),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: HSLColor.fromAHSL(1, h, 0.7, 0.55).toColor(),
                            border: Border.all(
                              color: (hue - h).abs() < 1
                                  ? Colors.white
                                  : Colors.white24,
                              width: (hue - h).abs() < 1 ? 2.5 : 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}
