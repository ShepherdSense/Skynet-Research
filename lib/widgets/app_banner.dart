import 'package:flutter/material.dart';

import '../theme.dart';

/// The app banner — drone background, Cooper icon above the title.
/// Used at the top of every main tab (Draco, 2026-10-23: "use that
/// banner throughout the app; add icon above Skynet Research").
/// The drone artwork re-hues with the user's colorway: the banner
/// image runs through a hue-rotate filter set from the theme, so
/// the slider changes the drone's trail too (Draco, 2026-10-23).
/// The icon is Cooper's real photo, shown big (Draco, 2026-10-23).
class AppBanner extends StatelessWidget {
  const AppBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          ColorFiltered(
            colorFilter: ColorFilter.matrix(PlainRegsTheme.droneHueMatrix),
            child: Image.asset(
              'assets/images/header_drone.jpg',
              height: 228,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.05),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/icon/icon.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Skynet Research',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'by Shepherd',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PlainRegsTheme.accentTint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
