import 'airspace/airspace_service.dart';
import 'airspace/geocoder.dart';
import 'models/models.dart';
import 'research/research.dart';
import 'services/regulation_source.dart';
import 'services/simplification_service.dart';
import 'state/bookmarks_store.dart';
import 'state/saved_briefs_store.dart';
import 'state/user_docs_store.dart';

/// Everything the screens need, wired once in main.dart. Screens take this
/// in their constructor — no globals, no DI framework at skeleton size.
class AppServices {
  final List<RegulationSource> sources;
  final SimplificationService simplifier;
  final BookmarksStore bookmarks;

  /// LAANC grid checker (location → offline grid bundle). Optional so
  /// tests / embeds can run the wizard with the manual flow only.
  final AirspaceService? airspace;

  /// Place-name → coordinates for Shepherd pre-planning (optional;
  /// typed coordinates always work without it).
  final Geocoder? geocoder;

  /// The user's own added documents (optional; the library that backs
  /// the 'userdocs' source and the Your Documents screen).
  final UserDocsStore? userDocs;

  /// The research engine (optional; the screen falls back to the stub).
  final ResearchService? research;

  /// Saved research briefs (optional; extends the Bookmarks idea).
  final SavedBriefsStore? savedBriefs;

  AppServices({
    required this.sources,
    required this.simplifier,
    required this.bookmarks,
    this.airspace,
    this.geocoder,
    this.userDocs,
    this.research,
    this.savedBriefs,
  });

  /// The live federal source is the default; the sample source is the
  /// offline fallback / demo.
  RegulationSource get primary => sources.first;

  RegulationSource byId(String id) =>
      sources.firstWhere((s) => s.id == id, orElse: () => sources.last);

  /// Fetch a section from whichever source owns its ref.
  Future<RegSection> fetchSectionFor(RegulationRef ref) =>
      byId(ref.sourceId).fetchSection(ref);
}
