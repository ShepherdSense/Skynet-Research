import 'package:flutter_test/flutter_test.dart';
import 'package:plainregs/theme.dart';

/// Applies a 4x5 color matrix to an RGB triple (alpha untouched).
(int, int, int) apply(List<double> m, int r, int g, int b) {
  int ch(double v) => v.round().clamp(0, 255);
  return (
    ch(m[0] * r + m[1] * g + m[2] * b + m[4] * 255),
    ch(m[5] * r + m[6] * g + m[7] * b + m[9] * 255),
    ch(m[10] * r + m[11] * g + m[12] * b + m[14] * 255),
  );
}

void main() {
  group('hueRotateMatrix', () {
    test('zero degrees is the identity', () {
      expect(apply(hueRotateMatrix(0), 200, 30, 90), (200, 30, 90));
      expect(apply(hueRotateMatrix(360), 200, 30, 90), (200, 30, 90));
    });

    test('grey is unchanged by any rotation', () {
      for (final deg in [40.0, 137.0, 262.0, 359.0]) {
        expect(apply(hueRotateMatrix(deg), 128, 128, 128), (128, 128, 128),
            reason: 'grey drifted at $deg');
      }
    });

    test('pure red rotates toward green at +120 and blue at -120', () {
      // The luminance-based matrix desaturates pure primaries, so
      // assert the dominant channel rather than an absolute level.
      final (r1, g1, b1) = apply(hueRotateMatrix(120), 255, 0, 0);
      expect(g1, greaterThan(r1));
      expect(g1, greaterThan(b1));
      expect(g1, greaterThan(80));
      final (r2, g2, b2) = apply(hueRotateMatrix(-120), 255, 0, 0);
      expect(b2, greaterThan(150));
      expect(r2, lessThan(110));
      expect(g2, lessThan(110));
    });
  });

  group('drone hue filter', () {
    test('at the default hue the drone filter is the identity', () {
      PlainRegsTheme.hueDeg = ThemeHueController.defaultHue;
      final m = PlainRegsTheme.droneHueMatrix;
      expect(apply(m, 142, 104, 190), (142, 104, 190));
    });

    test('moving the hue re-colors the trail violet', () {
      PlainRegsTheme.hueDeg = ThemeHueController.defaultHue + 120;
      final (r, g, b) = apply(PlainRegsTheme.droneHueMatrix, 142, 104, 190);
      // Violet (262°) rotated +120° lands at ~22° — the red/orange
      // family, so red becomes the dominant channel.
      expect(r, greaterThan(g));
      expect(r, greaterThan(b));
      PlainRegsTheme.hueDeg = ThemeHueController.defaultHue;
    });
  });
}
