// ignore_for_file: avoid_print
// One-off check of the bundled grid asset through the app's own decoder.
// Run: dart run tool/grid_check.dart
import 'dart:io';

import 'package:plainregs/airspace/airspace_grid.dart';

void main() {
  final bytes = File('assets/airspace_grid.bin').readAsBytesSync();
  final grid = AirspaceGrid.decode(bytes);
  print('asset: ${bytes.length} bytes, ${grid.cellCount} cells');
  final checks = <String, (double, double)>{
    'KFAY airport (expect 400)': (35.0625, -78.8792),
    'Fayetteville downtown (expect a grid)': (35.0526, -78.8789),
    'Rural NC west (expect null or grid)': (35.5, -80.5),
    'Mid-Atlantic ocean (expect null)': (35.0, -72.0),
    'LAX (expect a grid <= 400)': (33.9416, -118.4085),
    'Denver Intl (expect a grid)': (39.8561, -104.6737),
    'Guam (expect a grid)': (13.4833, 144.7833),
    'Paris (expect null — outside dataset)': (48.8566, 2.3522),
  };
  checks.forEach((label, p) {
    print('$label -> ${grid.lookup(p.$1, p.$2)}');
  });
}
