import 'dart:typed_data';

/// The FAA UAS Facility Map (LAANC) altitude grid, reduced to uniform
/// 1/120-degree cells (verified against the live dataset — see
/// tool/build_airspace_bundle.py). Each cell carries the maximum altitude
/// (feet AGL) that LAANC can pre-authorize in that square; 0 means no
/// pre-authorized operations there.
///
/// The bundle is a bundled app asset: lookups are fully offline and the
/// user's location never leaves the device.
///
/// IMPORTANT: the facility maps are informational. They do NOT authorize
/// a flight (that still takes a LAANC request through an FAA-approved
/// app), and they don't show TFRs, NOTAMs, stadium restrictions,
/// restricted/prohibited areas, or local rules.
class AirspaceGrid {
  /// Cells per degree (cells are 1/120° ≈ 30 arc-second squares).
  static const int cellsPerDegree = 120;

  final Map<int, Map<int, int>> _rows; // row -> {col -> ceilingFt}
  final int cellCount;

  AirspaceGrid._(this._rows, this.cellCount);

  /// Build directly from cells — used by tests and the decoder.
  factory AirspaceGrid.fromCells(Map<(int, int), int> cells) {
    final rows = <int, Map<int, int>>{};
    cells.forEach((key, ceiling) {
      final (row, col) = key;
      final rowMap = rows.putIfAbsent(row, () => {});
      final existing = rowMap[col];
      if (existing == null || ceiling < existing) rowMap[col] = ceiling;
    });
    return AirspaceGrid._(rows, cells.length);
  }

  /// Decode the PRG1 bundle produced by tool/build_airspace_bundle.py:
  /// magic 'PRG1', u32le count, then per cell (sorted by row, col):
  /// uvarint row-delta, zigzag-varint col-delta, uvarint ceiling.
  factory AirspaceGrid.decode(Uint8List bytes) {
    if (bytes.length < 8 ||
        bytes[0] != 0x50 || // P
        bytes[1] != 0x52 || // R
        bytes[2] != 0x47 || // G
        bytes[3] != 0x31) {
      // 1
      throw const FormatException('Not a PRG1 airspace bundle');
    }
    final count = ByteData.sublistView(bytes, 4, 8).getUint32(0, Endian.little);
    var pos = 8;

    int uvarint() {
      var result = 0;
      var shift = 0;
      while (true) {
        final b = bytes[pos++];
        result |= (b & 0x7F) << shift;
        if (b & 0x80 == 0) return result;
        shift += 7;
      }
    }

    int zigzag(int n) => (n >> 1) ^ -(n & 1);

    final cells = <(int, int), int>{};
    var row = 0;
    var col = 0;
    for (var i = 0; i < count; i++) {
      row += uvarint();
      col += zigzag(uvarint());
      final ceiling = uvarint();
      final key = (row, col);
      final existing = cells[key];
      if (existing == null || ceiling < existing) cells[key] = ceiling;
    }
    return AirspaceGrid.fromCells(cells);
  }

  /// The grid cell (row, col) containing a point. Longitude is normalized
  /// to [-180, 180).
  static (int, int) cellOf(double lat, double lon) {
    var normalizedLon = lon;
    while (normalizedLon >= 180) {
      normalizedLon -= 360;
    }
    while (normalizedLon < -180) {
      normalizedLon += 360;
    }
    final row = ((lat + 90) * cellsPerDegree).floor();
    final col = ((normalizedLon + 180) * cellsPerDegree).floor();
    return (row, col);
  }

  /// The LAANC ceiling (feet AGL) for the square containing this point,
  /// or null when no published grid square covers it — which usually
  /// means uncontrolled airspace (Class G), but see the class doc:
  /// absence of a grid is not a guarantee, and says nothing about
  /// restricted areas, TFRs, or local rules.
  int? lookup(double lat, double lon) {
    final (row, col) = cellOf(lat, lon);
    return _rows[row]?[col];
  }
}

/// Provenance for the bundled grid data, from
/// assets/airspace_grid_manifest.json (written by the build script).
class AirspaceGridInfo {
  final String? mapEffective;
  final String? generatedOn;
  final int? cells;

  const AirspaceGridInfo({this.mapEffective, this.generatedOn, this.cells});

  factory AirspaceGridInfo.fromJson(Map<String, dynamic> j) => AirspaceGridInfo(
    mapEffective: j['map_effective'] as String?,
    generatedOn: j['generated_on'] as String?,
    cells: (j['cells_after_reduction'] as num?)?.toInt(),
  );

  String get stamp {
    final parts = [
      if (mapEffective != null) 'FAA facility maps effective $mapEffective',
      if (generatedOn != null) 'downloaded $generatedOn',
    ];
    return parts.isEmpty ? 'FAA facility maps' : parts.join(' · ');
  }
}
