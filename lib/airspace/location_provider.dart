import 'package:geolocator/geolocator.dart';

/// Where the device is, for the airspace grid check. Behind an interface
/// so the wizard and tests never touch the platform plugin directly.
abstract class LocationProvider {
  Future<LocationOutcome> locate();
}

sealed class LocationOutcome {
  const LocationOutcome();
}

class LocationFound extends LocationOutcome {
  final double lat;
  final double lon;
  const LocationFound(this.lat, this.lon);
}

/// Permission denied, location services off, timed out, or unsupported.
/// All of these mean the same thing to the wizard: fall back to the
/// user-reported airspace questions — never guess.
class LocationUnavailable extends LocationOutcome {
  final String reason;
  const LocationUnavailable(this.reason);
}

class GeolocatorLocationProvider implements LocationProvider {
  @override
  Future<LocationOutcome> locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationUnavailable('Location services are off.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const LocationUnavailable('Location permission not granted.');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationFound(pos.latitude, pos.longitude);
    } catch (e) {
      return LocationUnavailable('Could not get a location fix ($e).');
    }
  }
}

/// Test double: returns whatever it was seeded with.
class FakeLocationProvider implements LocationProvider {
  final LocationOutcome outcome;
  const FakeLocationProvider(this.outcome);

  @override
  Future<LocationOutcome> locate() async => outcome;
}
