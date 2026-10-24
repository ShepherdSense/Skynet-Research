import '../models/models.dart';
import 'simplification_service.dart';

/// Hand-written sample simplifications so the skeleton runs end-to-end with
/// no API key and no network. This is a STUB by design:
/// - known citations return a real, hand-checked plain-English sample;
/// - everything else returns [Simplification.isMissing] — an honest
///   "not written yet" plus reading guidance. It NEVER fabricates an
///   explanation of text it has not been given a written sample for.
class StubSimplificationService implements SimplificationService {
  static const Map<String, Simplification> _samples = {
    '14 CFR 107.51': Simplification(
      citation: '14 CFR 107.51',
      isStub: true,
      plainText:
          'This section sets the basic speed, height, and weather limits for '
          'flying a small drone.\n\n'
          'Your drone cannot go faster than 100 miles per hour. It cannot '
          'fly higher than 400 feet above the ground. There is one '
          'exception: if you are flying near a building or tower, you can '
          'go up to 400 feet above the top of that structure, as long as '
          'you stay within 400 feet of it.\n\n'
          'You must be able to see at least 3 miles from where you are '
          'standing. And you must keep the drone at least 500 feet below '
          'any cloud and at least 2,000 feet away from a cloud sideways.',
      keyPoints: [
        'Max speed: 100 mph (87 knots)',
        'Max height: 400 feet above the ground',
        'Near a structure: up to 400 feet above its top, within 400 feet of it',
        'You must be able to see at least 3 miles',
        'Stay 500 feet below clouds and 2,000 feet away from them sideways',
      ],
    ),
    '14 CFR 107.49': Simplification(
      citation: '14 CFR 107.49',
      isStub: true,
      plainText:
          'Before you fly, the pilot in charge has to do homework on the '
          'area and the drone.\n\n'
          'That means: check the weather, know what airspace you are in and '
          'whether there are flight restrictions, know where people and '
          'property are on the ground, and make sure everyone helping you '
          'understands the plan and their job.\n\n'
          'You also have to check the drone itself — that it is working '
          'right, has enough power for the flight, and that everything on '
          'board is attached securely. If anything is unsafe, you do not '
          'fly.',
      keyPoints: [
        'Before flight, learn about the weather, the airspace, and any flight restrictions',
        'Know where people and property are in the operating area',
        'Brief everyone involved on the plan, conditions, and their role',
        'Check the drone works, has enough power, and everything is secure',
        'If conditions are unsafe, do not fly',
      ],
    ),
    '29 CFR 1910.95': Simplification(
      citation: '29 CFR 1910.95',
      isStub: true,
      plainText:
          'This rule protects workers from losing their hearing because of '
          'loud noise at work.\n\n'
          'In plain terms: if noise at work averages 85 decibels or more '
          'over an 8-hour day, the employer must run a hearing protection '
          'program. That includes measuring the noise, testing workers\' '
          'hearing for free, and giving them hearing protection for free.\n\n'
          'At higher levels — an average of 90 decibels over 8 hours — the '
          'employer must first try to make the workplace quieter (better '
          'equipment or barriers), not just hand out earplugs.\n\n'
          'Note: this sample covers the opening parts of a long section. '
          'The full original text has tables and more detail.',
      keyPoints: [
        'Goal: stop workers from losing hearing because of job noise',
        'At an 85-decibel 8-hour average: hearing program, free hearing tests, free protection',
        'At a 90-decibel 8-hour average: employer must first try to reduce the noise itself',
        'This sample covers only part of a long section — read the original for the full rule',
      ],
    ),
  };

  @override
  Future<Simplification> simplify(RegSection section) async {
    final hit = _samples[section.ref.citation];
    if (hit != null) return hit;
    return Simplification(
      citation: section.ref.citation,
      isStub: true,
      isMissing: true,
      plainText:
          'A plain-English version of this section has not been written yet, '
          'so this app will not guess at one — a wrong explanation of a '
          'regulation is worse than none.\n\n'
          'How to read the original: start with the first paragraph — it '
          'usually states the main rule. Watch for "shall" and "must" '
          '(these are requirements), "may" (this is allowed, not required), '
          'and "except" (an exception is coming). Numbers, deadlines, and '
          'distances in the original are exact — rely on those, not on any '
          'summary.',
    );
  }
}
