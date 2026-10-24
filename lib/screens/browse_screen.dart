import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/models.dart';
import '../services/regulation_source.dart';
import '../theme.dart';
import '../widgets/app_banner.dart';
import 'reader_screen.dart';
import 'shepherd_screen.dart';
import 'states_screen.dart';
import 'user_docs_screen.dart';

/// Simple status page for a corpus that is still being researched/built.
class CorpusStatusScreen extends StatelessWidget {
  final String title;
  final String body;

  const CorpusStatusScreen({
    super.key,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(body, style: const TextStyle(fontSize: 16, height: 1.5)),
      ),
    );
  }
}

/// Browse by CFR title, or by agency. FAA / airspace gets a one-tap curated
/// filter because that's a primary use case (DESIGN.md §1, Phase 1b).
class BrowseScreen extends StatefulWidget {
  final AppServices services;
  const BrowseScreen({super.key, required this.services});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  bool _byAgency = false;
  Future<List<CfrTitle>>? _titles;
  Future<List<Agency>>? _agencies;

  RegulationSource get _source => widget.services.primary;

  @override
  void initState() {
    super.initState();
    _titles = _source.titles();
    _agencies = _source.agencies();
  }

  /// Curated FAA / airspace entry points — all inside 14 CFR, one tap away.
  static const List<(String, String)> faaQuickLinks = [
    ('14 CFR 107.51', 'Drone operating limits — speed, height, weather'),
    ('14 CFR 107.49', 'Before you fly — preflight checks'),
    ('14 CFR 107.41', 'Flying in controlled airspace — permission rules'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No top title bar — the banner carries the branding now.
      body: Column(
        children: [
          _corpusHub(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('By Title')),
                ButtonSegment(value: true, label: Text('By Agency')),
              ],
              selected: {_byAgency},
              onSelectionChanged: (s) => setState(() => _byAgency = s.first),
            ),
          ),
          Expanded(child: _byAgency ? _agencyList() : _titleList()),
        ],
      ),
    );
  }

  /// Branches/offices hub: one button per corpus, plus the Shepherd
  /// fused-check button above them all.
  Widget _corpusHub(BuildContext context) {
    void openStatus(String title, String body) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CorpusStatusScreen(title: title, body: body),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner — shared across the app.
          const AppBanner(),
          const SizedBox(height: 12),
          Card(
            color: PlainRegsTheme.surfaceHigh,
            child: ListTile(
              leading: const Icon(Icons.radar, size: 30),
              title: const Text(
                'SHEPHERD',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              subtitle: const Text(
                'Fused check: tell it the drone group, munitions, and '
                'location — it fuses every layer into one summary',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShepherdScreen(services: widget.services),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.flight, size: 16),
                label: const Text('FAA Regulations'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TitleDetailScreen(
                      services: widget.services,
                      title: const CfrTitle(
                        number: 14,
                        name: 'Aeronautics and Space',
                      ),
                    ),
                  ),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.account_balance, size: 16),
                label: const Text('Federal — All Titles'),
                onPressed: () => setState(() => _byAgency = false),
              ),
              ActionChip(
                avatar: const Icon(Icons.map, size: 16),
                label: const Text('State Regulations · all 50 live'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const StatesScreen(),
                  ),
                ),
              ),
              ActionChip(
                avatar: const Icon(Icons.shield, size: 16),
                label: const Text('Department of War · map landed'),
                onPressed: () => openStatus(
                  'Department of War',
                  'The DoW research map has landed: 22 mapped entries '
                      'covering DoD issuances, the UAS Groups 1–5 '
                      'definitions, the FAA Certificate of Authorization '
                      'path for public aircraft, and each service\'s '
                      'publication stack — use the service buttons below '
                      'for your branch.\n\n'
                      'Only public sources will be ingested. Anything '
                      'CAC-gated stays a titled placeholder or a link '
                      'out — it is never copied into the app, and its '
                      'contents are never guessed.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Department of War — services & offices',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _serviceBodies.entries)
                ActionChip(
                  avatar: const Icon(
                    Icons.military_tech,
                    size: 16,
                    color: Colors.white,
                  ),
                  backgroundColor: _serviceColors[s.key],
                  label: Text(
                    s.key,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () => openStatus(s.key, s.value),
                ),
            ],
          ),
          if (widget.services.userDocs != null) ...[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.library_add_outlined),
                title: const Text('Your Documents'),
                subtitle: const Text(
                  'Add official documents we haven\'t ingested yet — '
                  'they stay on your device and become searchable',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        UserDocsScreen(services: widget.services),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Deep transparent service colors for the service boxes
  /// (Draco, 2026-10-23): Air Force blue, Army green, Navy gold,
  /// Marines red.
  static const Map<String, Color> _serviceColors = {
    'Air Force': Color(0xC7004C9C),
    'Army': Color(0xC73E6218),
    'Navy': Color(0xC78A6400),
    'Marine Corps': Color(0xC78C1D2F),
  };

  /// Per-service status pages, drawn from the DoW research map
  /// (~/workspace/research_notes/plainregs-drone-regs/dow.md). Each
  /// names the governing public publications and the approval chain;
  /// restricted publications stay titled placeholders, never summarized.
  static const Map<String, String> _serviceBodies = {
    'Air Force':
        'The Air Force has the most completely public UAS stack of any '
            'service, posted on AF e-Publishing with no releasability '
            'restrictions.\n\n'
            '• AFPD 11-5 — the sUAS policy directive at the top of the '
            'chain.\n'
            '• DAFMAN 11-501 — Small UAS Management: the approval chain '
            '(AF/A3S → MAJCOMs → installation commanders → squadron '
            'commanders → unit sUAS program managers), airworthiness '
            'and authority-to-operate, airspace coordination, and the '
            'DAF COA request checklist. It also carries the DoD UAS '
            'Categories (Groups 1–5) as Attachment 2.\n'
            '• DAFMAN 11-502 — Group 1 and 2 sUAS operations: training, '
            'standardization, and operating procedures.\n'
            '• AFMAN 11-202 Vol 3 — Flight Operations, which governs '
            'Group 4–5 UAS.\n\n'
            'Corpus ingest from these public PDFs is the next step.',
    'Army':
        'Army UAS governance is folded into the Army\'s main aviation '
            'regulation rather than a drone-only rulebook.\n\n'
            '• AR 95-1 — Flight Regulations: the single-source flight '
            'regulation for manned and unmanned aviation, including '
            'UAS airspace-integration policy and small-UAS guidance in '
            'Appendix D. It superseded the old UAS-specific AR 95-23.\n'
            '• Training circulars (TC series) — the UAS and small-UAS '
            'commander/aircrew training programs.\n\n'
            'Public via the Army Publishing Directorate. Corpus ingest '
            'is the next step.',
    'Navy':
        'The Navy has no public, UAS-specific operations instruction '
            'like the Air Force\'s 11-50x series. Navy UAS governance '
            'sits inside two general frameworks.\n\n'
            '• OPNAVINST 3710.7 — NATOPS General Flight and Operating '
            'Instructions: the umbrella under which naval UAS '
            'operations and flight clearances are framed.\n'
            '• NAVAIRINST 13034.1 — the flight-clearance authority: '
            'every Department of the Navy unmanned system requires a '
            'NAVAIR flight clearance before flight.\n\n'
            'The detailed model-specific NATOPS manuals are not '
            'publicly posted — in this app they stay titled '
            'placeholders, never summarized from guesswork.',
    'Marine Corps':
        'Marine Corps sUAS governance runs through training-and-'
            'readiness standards and fast-moving administrative '
            'messages.\n\n'
            '• NAVMC 3500.107 — Group 1 and 2 UAS training-and-'
            'readiness standards, the core USMC UAS publication '
            'against which operator certifications are issued.\n'
            '• Current sUAS training and certification requirements '
            'issued under the Secretary\'s 2025 drone-dominance '
            'guidance, with MARADMINs (e.g. 537/25, 624/25) as the '
            'fastest-moving public channel.\n\n'
            'Public on marines.mil. Corpus ingest is the next step.',
    // Space Force button removed per Draco (2026-10-23). USSF sUAS
    // still falls under the Air Force stack (DAFMAN 11-501 applies
    // to USSF) — that fact lives on in the Air Force page and the
    // Shepherd briefs; there is just no separate button.
  };

  Widget _titleList() {
    return FutureBuilder<List<CfrTitle>>(
      future: _titles,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) {
          return _offlineNote();
        }
        final titles = snap.data!;
        return ListView(
          children: [
            _faaCard(context),
            ...titles.map(
              (t) => ListTile(
                leading: CircleAvatar(child: Text('${t.number}')),
                title: Text('Title ${t.number} — ${t.name}'),
                subtitle: t.upToDateAsOf != null
                    ? Text('Current as of ${t.upToDateAsOf}')
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        TitleDetailScreen(services: widget.services, title: t),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _faaCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.flight, size: 20),
                SizedBox(width: 8),
                Text(
                  'FAA & Airspace — quick links',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'FAA rules live inside Title 14. These are the sections '
              'people look up most.',
              style: TextStyle(fontSize: 13),
            ),
            ...faaQuickLinks.map(
              (l) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.$1),
                subtitle: Text(l.$2),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () {
                  // The two 107 samples open offline; 107.41 goes live.
                  final isSample = l.$1 != '14 CFR 107.41';
                  final ref = RegulationRef(
                    sourceId: isSample ? 'sample' : 'ecfr',
                    titleNumber: 14,
                    part: '107',
                    section: l.$1.replaceAll('14 CFR ', ''),
                    heading: l.$2,
                  );
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ReaderScreen(services: widget.services, ref: ref),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _agencyList() {
    return FutureBuilder<List<Agency>>(
      future: _agencies,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError || !snap.hasData) return _offlineNote();
        return ListView(
          children: snap.data!
              .map(
                (a) => ListTile(
                  title: Text(a.name),
                  subtitle: Text(a.cfrReferences.join(' · ')),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _offlineNote() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Browse needs a connection for the live federal list.\n'
        'The sample sections on the Search tab work offline.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

/// Title → parts → sections → Reader.
class TitleDetailScreen extends StatelessWidget {
  final AppServices services;
  final CfrTitle title;

  const TitleDetailScreen({
    super.key,
    required this.services,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Title ${title.number}')),
      body: FutureBuilder<StructureNode>(
        future: services.primary.structure(title.number),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Loading the title structure…\n'
                    '(large titles can take a moment)',
                  ),
                ],
              ),
            );
          }
          if (snap.hasError || !snap.hasData) {
            return const Center(
              child: Text('Could not load this title\'s structure.'),
            );
          }
          final parts = snap.data!.findAll('part');
          if (parts.isEmpty) {
            return const Center(child: Text('No parts found.'));
          }
          return ListView.builder(
            itemCount: parts.length,
            itemBuilder: (context, i) {
              final part = parts[i];
              final sections = part.findAll('section');
              return ExpansionTile(
                title: Text(part.label),
                subtitle: Text('${sections.length} sections'),
                children: sections
                    .take(200)
                    .map(
                      (s) => ListTile(
                        dense: true,
                        title: Text(s.label),
                        onTap: () {
                          final ref = RegulationRef(
                            sourceId: services.primary.id,
                            titleNumber: title.number,
                            part: part.identifier,
                            section: s.identifier,
                            heading: s.label,
                          );
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ReaderScreen(services: services, ref: ref),
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
              );
            },
          );
        },
      ),
    );
  }
}
