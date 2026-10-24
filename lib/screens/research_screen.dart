import 'package:flutter/material.dart';

import '../app_services.dart';
import '../research/research.dart';
import '../theme.dart';
import '../widgets/app_banner.dart';
import 'reader_screen.dart';

/// Research: ask a plain-language question, get a brief — short answer
/// first, the deciding regulations cited and openable, the gaps named,
/// and follow-ups to dig deeper. The free-form sibling of the
/// structured Shepherd flow. See DESIGN.md §14.
class ResearchScreen extends StatefulWidget {
  final AppServices services;

  const ResearchScreen({super.key, required this.services});

  @override
  State<ResearchScreen> createState() => _ResearchScreenState();
}

class _ResearchScreenState extends State<ResearchScreen> {
  final _controller = TextEditingController();
  ResearchBrief? _brief;
  bool _busy = false;

  ResearchService get _research =>
      widget.services.research ?? StubResearchService();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _ask(String q) async {
    final question = q.trim();
    if (question.isEmpty) return;
    _controller.text = question;
    setState(() => _busy = true);
    final brief = await _research.ask(question);
    if (!mounted) return;
    setState(() {
      _brief = brief;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.services.savedBriefs;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppBanner(),
        const SizedBox(height: 16),
        const Text(
          'Ask a question, get a brief',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Plain-language answers built from the regulations — with '
          'the deciding rules cited, and what we don\'t know stated '
          'plainly.',
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'e.g. Can I fly my drone over a parade?',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _ask,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : () => _ask(_controller.text),
              child: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ask'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final q in _research.exampleQuestions)
              ActionChip(
                label: Text(q),
                onPressed: _busy ? null : () => _ask(q),
              ),
          ],
        ),
        if (_brief != null) ...[
          const SizedBox(height: 20),
          _BriefView(
            brief: _brief!,
            services: widget.services,
            onFollowUp: _ask,
          ),
        ],
        if (saved != null) ...[
          const SizedBox(height: 24),
          ListenableBuilder(
            listenable: saved,
            builder: (context, _) {
              if (saved.items.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved briefs',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final s in saved.items)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.bookmark, size: 20),
                        title: Text(s.brief.question),
                        subtitle: Text(
                          'saved '
                          '${s.savedAt.toIso8601String().substring(0, 10)}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove',
                          onPressed: () =>
                              saved.remove(s.brief.question),
                        ),
                        onTap: () => setState(() => _brief = s.brief),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// The brief anatomy, shared in spirit with the Shepherd summary:
/// answer → why (cited) → gaps → dig deeper → disclaimer.
class _BriefView extends StatelessWidget {
  final ResearchBrief brief;
  final AppServices services;
  final void Function(String) onFollowUp;

  const _BriefView({
    required this.brief,
    required this.services,
    required this.onFollowUp,
  });

  @override
  Widget build(BuildContext context) {
    final saved = services.savedBriefs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                brief.question,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (brief.isStub)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: PlainRegsTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'curated brief',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _section('Short answer', null, [Text(brief.shortAnswer)]),
        if (brief.why.isNotEmpty)
          _section(
            'Why — the rules that decide it',
            Icons.gavel_outlined,
            [
              for (final c in brief.why)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.label),
                  subtitle: Text(c.why),
                  trailing: c.openable
                      ? const Icon(Icons.chevron_right, size: 18)
                      : null,
                  onTap: c.openable
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReaderScreen(
                                services: services,
                                ref: c.ref!,
                              ),
                            ),
                          )
                      : null,
                ),
            ],
          ),
        if (brief.gaps.isNotEmpty)
          _section(
            'What we don\'t know',
            Icons.help_outline,
            [
              for (final g in brief.gaps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• '),
                      Expanded(child: Text(g)),
                    ],
                  ),
                ),
            ],
          ),
        if (brief.followUps.isNotEmpty)
          _section('Dig deeper', Icons.explore_outlined, [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in brief.followUps)
                  ActionChip(
                    label: Text(f),
                    onPressed: () => onFollowUp(f),
                  ),
              ],
            ),
          ]),
        const SizedBox(height: 4),
        Row(
          children: [
            if (saved != null)
              ListenableBuilder(
                listenable: saved,
                builder: (context, _) {
                  final isSaved = saved.isSaved(brief.question);
                  return OutlinedButton.icon(
                    icon: Icon(
                      isSaved ? Icons.bookmark : Icons.bookmark_border,
                      size: 18,
                    ),
                    label: Text(isSaved ? 'Saved' : 'Save brief'),
                    onPressed: isSaved
                        ? null
                        : () => saved.save(brief),
                  );
                },
              ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          ResearchBrief.disclaimer,
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _section(String title, IconData? icon, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: PlainRegsTheme.accent),
                  const SizedBox(width: 6),
                ],
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
