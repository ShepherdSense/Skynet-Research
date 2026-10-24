import '../models/models.dart';

/// The simplification interface. Any engine — hand-written, on-device model,
/// or cloud LLM — implements this. The UI depends only on this type.
///
/// The contract (DESIGN.md §4) is not optional for implementers:
/// explain, never add/remove obligations; disclaimer is a constant on
/// [Simplification]; target ~8th-grade reading level; show uncertainty.
abstract class SimplificationService {
  Future<Simplification> simplify(RegSection section);
}
