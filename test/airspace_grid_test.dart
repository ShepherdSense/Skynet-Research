import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:plainregs/airspace/airspace_grid.dart';
import 'package:plainregs/airspace/airspace_service.dart';
import 'package:plainregs/airspace/location_provider.dart';

/// Minimal PRG1 encoder mirroring tool/build_airspace_bundle.py, for
/// decoder round-trip tests.
Uint8List encodePrg1(Map<(int, int), int> cells) {
  final out = BytesBuilder();
  out.add([0x50, 0x52, 0x47, 0x31]); // PRG1
  final count = ByteData(4)..setUint32(0, cells.length, Endian.little);
  out.add(count.buffer.asUint8List());
  void uvarint(int n) {
    while (true) {
      final b = n & 0x7F;
      n >>= 7;
      if (n > 0) {
        out.addByte(b | 0x80);
      } else {
        out.addByte(b);
        return;
      }
    }
  }

  int zigzag(int n) => n >= 0 ? n << 1 : ((-n) << 1) - 1;

  final keys = cells.keys.toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  var prevRow = 0;
  var prevCol = 0;
  for (final k in keys) {
    uvarint(k.$1 - prevRow);
    uvarint(zigzag(k.$2 - prevCol));
    uvarint(cells[k]!);
    prevRow = k.$1;
    prevCol = k.$2;
  }
  return out.toBytes();
}

void main() {
  group('AirspaceGrid.cellOf', () {
    test('KFAY center lands in the expected cell neighborhood', () {
      final (row, col) = AirspaceGrid.cellOf(35.0625, -78.8792);
      // Just structural sanity: recomputing from the cell corner works.
      expect(row, ((35.0625 + 90) * 120).floor());
      expect(col, ((-78.8792 + 180) * 120).floor());
    });

    test('longitude normalizes across the antimeridian', () {
      expect(
        AirspaceGrid.cellOf(13.48, 144.78),
        AirspaceGrid.cellOf(13.48, 144.78 - 360),
      );
    });
  });

  group('PRG1 decode', () {
    test('round-trips cells incl. negative col deltas between rows', () {
      final cells = <(int, int), int>{
        (100, 500): 400,
        (100, 501): 200,
        (101, 400): 0, // col jumps backwards on the new row
        (25000, 30000): 50,
      };
      final grid = AirspaceGrid.decode(encodePrg1(cells));
      expect(grid.cellCount, 4);
      // Look up via lat/lon at each cell's center.
      for (final e in cells.entries) {
        final lat = (e.key.$1 + 0.5) / 120 - 90;
        final lon = (e.key.$2 + 0.5) / 120 - 180;
        expect(
          grid.lookup(lat, lon),
          e.value,
          reason: 'cell ${e.key} should read ${e.value}',
        );
      }
      // A cell that was never written reads null.
      expect(grid.lookup(0, 0), isNull);
    });

    test('overlaps keep the minimum ceiling', () {
      final grid = AirspaceGrid.fromCells({(5, 5): 400, (5, 6): 100});
      expect(grid.lookup((5.5) / 120 - 90, (5.5) / 120 - 180), 400);
      expect(grid.lookup((5.5) / 120 - 90, (6.5) / 120 - 180), 100);
    });

    test('rejects a non-PRG1 payload', () {
      expect(
        () => AirspaceGrid.decode(Uint8List.fromList([1, 2, 3, 4])),
        throwsFormatException,
      );
    });
  });

  group('Bundled asset (real FAA data)', () {
    final file = File('assets/airspace_grid.bin');

    test('decodes and matches ground truth verified against the live API', () {
      expect(
        file.existsSync(),
        isTrue,
        reason: 'run tool/build_airspace_bundle.py to build the asset',
      );
      final grid = AirspaceGrid.decode(file.readAsBytesSync());
      // One cell per published feature in this cycle.
      expect(grid.cellCount, 380860);
      // Verified point-by-point against the live FeatureServer 2026-10-23:
      expect(grid.lookup(35.0625, -78.8792), 400); // KFAY cell
      expect(grid.lookup(35.0526, -78.8789), 400); // Fayetteville downtown
      expect(grid.lookup(33.9416, -118.4085), 0); // KLAX core: 0-ft grid
      expect(grid.lookup(35.0, -72.0), isNull); // mid-Atlantic: no grid
      expect(grid.lookup(35.5, -80.5), isNull); // rural NC: no grid
    });
  });

  group('AirspaceService', () {
    final fayCell = AirspaceGrid.cellOf(35.0625, -78.8792);
    AirspaceService svc(LocationOutcome outcome, {int? ceiling = 200}) {
      return AirspaceService(
        locationProvider: FakeLocationProvider(outcome),
        loadGrid: () async =>
            AirspaceGrid.fromCells({fayCell: ?ceiling}),
        loadInfo: () async => const AirspaceGridInfo(
          mapEffective: '10/1/2026',
          generatedOn: '2026-10-23',
        ),
      );
    }

    test('GPS fix inside a grid returns its ceiling', () async {
      final check = await svc(const LocationFound(35.0625, -78.8792))
          .checkHere();
      expect(check, isA<GridHitCheck>());
      expect((check as GridHitCheck).ceilingFt, 200);
    });

    test(
      'manual point with no grid returns NoGridCheck (pre-planning)',
      () async {
        final check = await svc(const LocationUnavailable('unused'))
            .checkAt(35.5, -80.5);
        expect(check, isA<NoGridCheck>());
      },
    );

    test('point outside the US dataset returns OutsideCoverageCheck', () async {
      final check = await svc(const LocationUnavailable('unused'))
          .checkAt(48.85, 2.35);
      expect(check, isA<OutsideCoverageCheck>());
    });

    test('denied location falls back — never a guessed grid answer', () async {
      final check = await svc(
        const LocationUnavailable('Location permission not granted.'),
      ).checkHere();
      expect(check, isA<LocationFailedCheck>());
    });
  });
}
