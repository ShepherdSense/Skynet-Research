import 'package:flutter/material.dart';

import '../states/states_matrix.dart';
import '../theme.dart';

/// All 50 states' drone-law matrix (DESIGN.md §15). Every state
/// shows its verification status and date; a state still being
/// verified shows RESEARCHING and no values — never provisional data
/// dressed up as fact.
class StatesScreen extends StatefulWidget {
  /// Pre-loaded matrix (tests); the app loads the bundled asset.
  final List<StateMatrixEntry>? states;

  const StatesScreen({super.key, this.states});

  @override
  State<StatesScreen> createState() => _StatesScreenState();
}

class _StatesScreenState extends State<StatesScreen> {
  Future<List<StateMatrixEntry>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = widget.states != null
        ? Future.value(widget.states)
        : loadStateMatrix();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('State Regulations')),
      body: FutureBuilder<List<StateMatrixEntry>>(
        future: _future,
        builder: (context, snap) {
          final states = snap.data;
          if (states == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search states…',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'State drone law sits on top of the federal rules '
                    '— it never replaces them. Each state below was '
                    'researched against its official code; the date '
                    'is when its law was last verified. State law '
                    'changes — a repeal is how North Carolina\'s old '
                    'permit traps people — so check the date.',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ),
                Expanded(
                  child: ListView(
                    children: [
                      for (final s in states.where(
                        (s) =>
                            _query.isEmpty ||
                            s.name.toLowerCase().contains(_query) ||
                            s.code.toLowerCase() == _query,
                      ))
                        ListTile(
                          title: Text('${s.name} (${s.code})'),
                          subtitle: Text(_subtitle(s)),
                          trailing: _chip(s),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => StateDetailScreen(state: s),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
          );
        },
      ),
    );
  }

  String _subtitle(StateMatrixEntry s) {
    if (!s.hasData) return 'Verification pending — no values published';
    if (s.noDroneLawFound) {
      return 'No state drone law found on top of the federal rules';
    }
    final n = s.substantive.length;
    return n == 0
        ? 'Researched — see detail'
        : '$n of 13 categories carry state rules';
  }

  Widget _chip(StateMatrixEntry s) {
    final (label, color) = switch (s.status) {
      StateMatrixStatus.verified => ('VERIFIED', Colors.green),
      StateMatrixStatus.partial => ('PARTIAL', Colors.orange),
      StateMatrixStatus.unverified => ('RESEARCHING', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        s.hasData ? '$label · ${s.verifiedDate}' : label,
        style: TextStyle(fontSize: 11, color: color),
      ),
    );
  }
}

class StateDetailScreen extends StatelessWidget {
  final StateMatrixEntry state;

  const StateDetailScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = state;
    return Scaffold(
      appBar: AppBar(title: Text('${s.name} (${s.code})')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!s.hasData) ...[
            const Text(
              'Still being verified',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              s.caveat.isNotEmpty
                  ? s.caveat
                  : 'This state\'s research has not finished '
                      'verification, so no values are published yet.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Until it lands: the federal rules (Search and Browse) '
              'are the floor everywhere, and the state legislature\'s '
              'official code site is the source to trust.',
            ),
          ] else ...[
            Text(
              'Verified ${s.verifiedDate} against the official state '
              'code${s.status == StateMatrixStatus.partial ? ' — partial: a verified core with the gaps noted below' : ''}.',
              style: const TextStyle(color: Colors.grey),
            ),
            if (s.noDroneLawFound) ...[
              const SizedBox(height: 12),
              const Text(
                'No state drone law found on top of the federal '
                'rules — verified.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Researchers checked this state\'s code across all '
                '13 categories and found no drone-specific provision. '
                'Federal rules still apply in full.',
              ),
            ],
            if (s.caveat.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: PlainRegsTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Research note: ${s.caveat}',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
            const SizedBox(height: 12),
            for (final c in s.categories)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.n}. ${c.name}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.headline,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (c.detail.isNotEmpty &&
                          c.detail != c.headline) ...[
                        const SizedBox(height: 4),
                        Text(c.detail),
                      ],
                      if (c.basis.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          c.basis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            const Text(
              'Plain-language research summaries from the official '
              'code — not legal advice. The statute text is what '
              'legally counts.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }
}
