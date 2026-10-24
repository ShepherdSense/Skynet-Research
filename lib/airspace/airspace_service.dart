import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'airspace_grid.dart';
import 'location_provider.dart';

/// Result of a "check my spot" attempt in the wizard.
sealed class AirspaceCheck {
  const AirspaceCheck();
}

/// The point is inside a published grid square with this ceiling (feet).
/// A ceiling of 0 means no pre-authorized operations in that square.
class GridHitCheck extends AirspaceCheck {
  final int ceilingFt;
  final double lat;
  final double lon;
  const GridHitCheck(this.ceilingFt, this.lat, this.lon);
}

/// The point was checked and no grid square covers it (within the data's
/// US coverage) — usually uncontrolled airspace.
class NoGridCheck extends AirspaceCheck {
  final double lat;
  final double lon;
  const NoGridCheck(this.lat, this.lon);
}

/// Grid data doesn't cover this part of the world (outside the US
/// dataset extent). Fall back to the manual questions.
class OutsideCoverageCheck extends AirspaceCheck {
  const OutsideCoverageCheck();
}

/// Location couldn't be obtained. Fall back to the manual questions.
class LocationFailedCheck extends AirspaceCheck {
  final String reason;
  const LocationFailedCheck(this.reason);
}

/// Orchestrates: locate → load bundle (cached) → point lookup.
/// Fully offline apart from the device's own location fix.
class AirspaceService {
  final LocationProvider locationProvider;
  final Future<AirspaceGrid> Function() _loadGrid;
  final Future<AirspaceGridInfo> Function() _loadInfo;

  AirspaceGridInfo? _info;
  Future<AirspaceGrid>? _gridFuture;

  AirspaceService({
    required this.locationProvider,
    Future<AirspaceGrid> Function()? loadGrid,
    Future<AirspaceGridInfo> Function()? loadInfo,
  }) : _loadGrid = loadGrid ?? _loadGridFromAssets,
       _loadInfo = loadInfo ?? _loadInfoFromAssets;

  static Future<AirspaceGrid> _loadGridFromAssets() async {
    final data = await rootBundle.load('assets/airspace_grid.bin');
    return AirspaceGrid.decode(data.buffer.asUint8List());
  }

  static Future<AirspaceGridInfo> _loadInfoFromAssets() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/airspace_grid_manifest.json',
      );
      return AirspaceGridInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AirspaceGridInfo();
    }
  }

  Future<AirspaceGridInfo> info() async => _info ??= await _loadInfo();

  /// Rough extent of the FAA dataset (CONUS, AK, HI, PR, Guam, territories)
  /// — a fix outside this is "outside coverage", not "no grid".
  static bool withinDatasetExtent(double lat, double lon) {
    if (lat < 10 || lat > 72.5) return false;
    // Main block (incl. Alaska/Hawaii/PR): lon -180..-59
    if (lon >= -180 && lon <= -59) return true;
    // Pacific territories east of the antimeridian (Guam ~144.8E)
    if (lon >= 130 && lon <= 180 && lat <= 21) return true;
    return false;
  }

  Future<AirspaceCheck> checkHere() async {
    final outcome = await locationProvider.locate();
    if (outcome is! LocationFound) {
      return LocationFailedCheck((outcome as LocationUnavailable).reason);
    }
    return checkAt(outcome.lat, outcome.lon);
  }

  /// Grid check for an explicitly given point — used for pre-planning
  /// (Shepherd mode manual location entry). No device location involved.
  Future<AirspaceCheck> checkAt(double lat, double lon) async {
    if (!withinDatasetExtent(lat, lon)) return const OutsideCoverageCheck();
    final grid = await (_gridFuture ??= _loadGrid());
    final ceiling = grid.lookup(lat, lon);
    if (ceiling == null) return NoGridCheck(lat, lon);
    return GridHitCheck(ceiling, lat, lon);
  }

  /// Just the ceiling lookup (null = no grid), for callers that already
  /// hold coordinates.
  Future<int?> ceilingAt(double lat, double lon) async {
    final grid = await (_gridFuture ??= _loadGrid());
    return grid.lookup(lat, lon);
  }
}
