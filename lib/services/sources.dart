import 'ecfr_source.dart';
import 'regulation_source.dart';
import 'sample_source.dart';

/// The corpus registry — the ONLY place sources are listed.
/// Adding a corpus (Federal Register, Department of War pubs, a state code,
/// FAA companion docs…) = implement [RegulationSource], add one line here.
/// No UI changes. See DESIGN.md §1 roadmap and §3.
List<RegulationSource> buildSources() => [
  EcfrSource(),
  SampleSource(),
  // TODO(phase-2): FederalRegisterSource()
  // TODO(phase-1b): FaaCompanionSource() — AIM, FAA Orders, Advisory Circulars
  // TODO(phase-3): DowPublicationsSource() — DAFI/AFI, DoDI, Army ARs (PDF ingest)
  // TODO(phase-4): StateCodeSource('NC') — then one per state
];
