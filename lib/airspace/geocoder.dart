import 'dart:convert';

import 'package:http/http.dart' as http;

/// A place name resolved to coordinates for pre-planning ("Fayetteville,
/// NC" → 35.0526, -78.8789). Used by Shepherd's manual location entry so
/// pre-planning doesn't require knowing raw coordinates.
class GeocodedPlace {
  final double lat;
  final double lon;
  final String displayName;

  const GeocodedPlace({
    required this.lat,
    required this.lon,
    required this.displayName,
  });
}

/// Place-name lookup. Returns null when the place can't be found — the
/// caller must say so plainly and offer coordinates instead; a guessed
/// location would silently check the wrong airspace.
abstract class Geocoder {
  Future<GeocodedPlace?> lookup(String query);
}

/// OpenStreetMap Nominatim — free, no key. Network-only by nature; the
/// resolved coordinates are then checked against the on-device grid
/// bundle exactly like a GPS fix or typed coordinates.
class NominatimGeocoder implements Geocoder {
  final http.Client _client;

  NominatimGeocoder({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<GeocodedPlace?> lookup(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': q,
        'format': 'jsonv2',
        'limit': '1',
        'countrycodes': 'us',
      });
      final resp = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final list = jsonDecode(utf8.decode(resp.bodyBytes)) as List;
      if (list.isEmpty) return null;
      final first = list.first as Map<String, dynamic>;
      final lat = double.tryParse('${first['lat']}');
      final lon = double.tryParse('${first['lon']}');
      if (lat == null || lon == null) return null;
      return GeocodedPlace(
        lat: lat,
        lon: lon,
        displayName: (first['display_name'] as String?) ?? q,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Test double: resolves a fixed place (or nothing).
class FakeGeocoder implements Geocoder {
  final GeocodedPlace? result;
  const FakeGeocoder(this.result);

  @override
  Future<GeocodedPlace?> lookup(String query) async => result;
}
