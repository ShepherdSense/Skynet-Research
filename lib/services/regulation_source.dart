import '../models/models.dart';

/// The corpus interface. Every regulation collection — eCFR today, military
/// publications / state codes / the Federal Register later — implements
/// this. UI code depends only on this type, never on a concrete source.
/// See DESIGN.md §3.
abstract class RegulationSource {
  String get id;
  String get displayName;

  Future<List<SearchHit>> search(
    String query, {
    int page = 1,
    int perPage = 20,
    String? agencySlug,
  });

  Future<List<CfrTitle>> titles();

  Future<List<Agency>> agencies();

  /// Structure tree for one title. [date] defaults to the title's current
  /// version date as reported by the source.
  Future<StructureNode> structure(int titleNumber, {String? date});

  Future<RegSection> fetchSection(RegulationRef ref);
}
