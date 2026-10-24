// ignore_for_file: avoid_print
// One-off live smoke check against the real eCFR API through the app's own
// EcfrSource code. Not part of the app or the test suite.
// Run: dart run tool/live_check.dart
import 'package:plainregs/models/models.dart';
import 'package:plainregs/services/ecfr_source.dart';

Future<void> main() async {
  final src = EcfrSource();

  final titles = await src.titles();
  print('titles: ${titles.length} (first: ${titles.first.name})');

  final hits = await src.search('small unmanned aircraft', perPage: 3);
  print('search hits: ${hits.length}');
  for (final h in hits) {
    print('  ${h.ref.citation} — ${h.ref.heading}');
  }

  const ref = RegulationRef(
    sourceId: 'ecfr',
    titleNumber: 14,
    part: '107',
    section: '107.51',
    heading: 'Operating limitations for small unmanned aircraft.',
  );
  final section = await src.fetchSection(ref);
  print('fetched ${ref.citation} (version ${section.sourceDate}):');
  print(section.bodyText.substring(0, 300));
}
