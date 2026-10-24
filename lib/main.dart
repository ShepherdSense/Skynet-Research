import 'package:flutter/material.dart';

import 'airspace/airspace_service.dart';
import 'airspace/geocoder.dart';
import 'airspace/location_provider.dart';
import 'app.dart';
import 'app_services.dart';
import 'services/sources.dart';
import 'services/stub_simplification_service.dart';
import 'research/research.dart';
import 'services/user_docs_source.dart';
import 'state/bookmarks_store.dart';
import 'state/saved_briefs_store.dart';
import 'state/user_docs_store.dart';

void main() {
  final userDocs = UserDocsStore();
  final services = AppServices(
    sources: [...buildSources(), UserDocsSource(userDocs)],
    simplifier: StubSimplificationService(),
    bookmarks: BookmarksStore(),
    airspace: AirspaceService(locationProvider: GeolocatorLocationProvider()),
    geocoder: NominatimGeocoder(),
    userDocs: userDocs,
    research: StubResearchService(),
    savedBriefs: SavedBriefsStore(),
  );
  runApp(PlainRegsApp(services: services));
}
