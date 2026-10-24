import 'package:flutter/material.dart';

import '../app_services.dart';
import '../models/models.dart';
import '../theme.dart';

enum _View { original, plain, both }

/// The Reader. Original text is the default and the legal truth.
/// Plain-English is presented alongside it (Original | Plain | Both),
/// never instead of it, and every plain view leads with the disclaimer.
/// See DESIGN.md §4.
class ReaderScreen extends StatefulWidget {
  final AppServices services;
  final RegulationRef ref;

  const ReaderScreen({super.key, required this.services, required this.ref});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  _View _view = _View.original;
  RegSection? _section;
  Simplification? _simplification;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final section = await widget.services.fetchSectionFor(widget.ref);
      final simp = await widget.services.simplifier.simplify(section);
      if (!mounted) return;
      setState(() {
        _section = section;
        _simplification = simp;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this section.\n$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookmarks = widget.services.bookmarks;
    final saved = bookmarks.isBookmarked(widget.ref);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ref.citation),
        actions: [
          IconButton(
            tooltip: saved ? 'Remove bookmark' : 'Bookmark',
            icon: Icon(
              saved ? Icons.bookmark : Icons.bookmark_border,
              color: saved ? PlainRegsTheme.accent : null,
            ),
            onPressed: () => bookmarks.toggle(widget.ref),
          ),
        ],
      ),
      body: _section == null
          ? Center(
              child: _error != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_error!, textAlign: TextAlign.center),
                    )
                  : const CircularProgressIndicator(),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    widget.ref.heading,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: SegmentedButton<_View>(
                    segments: const [
                      ButtonSegment(
                        value: _View.original,
                        label: Text('Original'),
                      ),
                      ButtonSegment(
                        value: _View.plain,
                        label: Text('Plain English'),
                      ),
                      ButtonSegment(value: _View.both, label: Text('Both')),
                    ],
                    selected: {_view},
                    onSelectionChanged: (s) => setState(() => _view = s.first),
                  ),
                ),
                Expanded(child: _body()),
              ],
            ),
    );
  }

  Widget _body() {
    switch (_view) {
      case _View.original:
        return _pane(_originalPane());
      case _View.plain:
        return _pane(_plainPane());
      case _View.both:
        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _pane(_originalPane())),
                  const VerticalDivider(width: 1),
                  Expanded(child: _pane(_plainPane())),
                ],
              );
            }
            // Narrow: original first, plain below — alongside, not instead.
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _originalContent(),
                const Divider(height: 32),
                _plainContent(),
              ],
            );
          },
        );
    }
  }

  Widget _pane(Widget child) =>
      SingleChildScrollView(padding: const EdgeInsets.all(16), child: child);

  Widget _originalPane() => _originalContent();

  Widget _originalContent() {
    final s = _section!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.sourceDate != null)
          Text(
            'Version: ${s.sourceDate}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 8),
        SelectableText(
          s.bodyText,
          style: const TextStyle(fontSize: 16, height: 1.55),
        ),
      ],
    );
  }

  Widget _plainPane() => _plainContent();

  Widget _plainContent() {
    final simp = _simplification!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The disclaimer banner — always first, always visible.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PlainRegsTheme.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: PlainRegsTheme.accent.withValues(alpha: 0.5),
            ),
          ),
          child: const Text(
            Simplification.disclaimer,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          Simplification.targetReadingLevel,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (simp.isStub)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Chip(
              label: Text('Sample simplification'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        const SizedBox(height: 12),
        SelectableText(
          simp.plainText,
          style: const TextStyle(fontSize: 16, height: 1.55),
        ),
        if (simp.keyPoints.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Key points', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          ...simp.keyPoints.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(p)),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.gavel, size: 18),
          label: const Text('Read the original text'),
          onPressed: () => setState(() => _view = _View.original),
        ),
      ],
    );
  }
}
