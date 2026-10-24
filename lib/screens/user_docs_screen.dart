import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_services.dart';
import '../services/user_docs_source.dart';
import '../theme.dart';
import '../userdocs/user_document.dart';
import 'reader_screen.dart';

/// Your Documents: official publications the user adds themselves
/// because the app hasn't ingested them (yet). Stored only on this
/// device; searchable like any other source; read in the Reader.
/// See DESIGN.md §13.
class UserDocsScreen extends StatelessWidget {
  final AppServices services;

  const UserDocsScreen({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    final store = services.userDocs;
    return Scaffold(
      appBar: AppBar(title: const Text('Your Documents')),
      floatingActionButton: store == null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add),
              label: const Text('Add a document'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AddDocumentScreen(services: services),
                ),
              ),
            ),
      body: store == null
          ? const Center(child: Text('Document library unavailable.'))
          : ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final docs = store.items;
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: [
                    const Text(
                      'We can\'t ingest everything. If you have an '
                      'official document we missed — a service manual, a '
                      'state statute, an FAA order — add it here. It '
                      'stays on this device, becomes searchable like '
                      'any other source in the app, and opens in the '
                      'Reader.',
                      style: TextStyle(fontSize: 14, height: 1.45),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Only add documents you have the right to keep — '
                      'public official publications are the intended '
                      'use. Never add classified or CAC-gated material.',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (docs.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No documents yet. Tap "Add a document" to '
                            'paste a document\'s text, import a .txt/.md '
                            'file, or save an official link.',
                          ),
                        ),
                      )
                    else
                      for (final doc in docs)
                        Card(
                          child: ListTile(
                            leading: Icon(
                              doc.isLinkOnly
                                  ? Icons.link
                                  : Icons.description_outlined,
                            ),
                            title: Text(doc.title),
                            subtitle: Text(
                              [
                                if (doc.citation.trim().isNotEmpty)
                                  doc.citation.trim(),
                                doc.authority,
                                'added ${doc.addedAt.toIso8601String().substring(0, 10)}',
                                if (doc.isLinkOnly) 'link only',
                              ].join(' · '),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Remove',
                              onPressed: () =>
                                  _confirmRemove(context, doc),
                            ),
                            onTap: () => _open(context, doc),
                          ),
                        ),
                  ],
                );
              },
            ),
    );
  }

  void _open(BuildContext context, UserDocument doc) {
    if (doc.isLinkOnly && doc.sourceUrl != null) {
      final uri = Uri.tryParse(doc.sourceUrl!);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    final source = UserDocsSource(services.userDocs!);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReaderScreen(services: services, ref: source.refFor(doc)),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, UserDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this document?'),
        content: Text(
          '"${doc.title}" will be removed from this device. This '
          'can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await services.userDocs!.remove(doc.id);
  }
}

/// The add form: title / citation / authority / official link, plus the
/// text itself — pasted, or imported from a .txt/.md file.
class AddDocumentScreen extends StatefulWidget {
  final AppServices services;

  const AddDocumentScreen({super.key, required this.services});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _title = TextEditingController();
  final _citation = TextEditingController();
  final _url = TextEditingController();
  final _text = TextEditingController();
  String _authority = kDocumentAuthorities.first;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _citation.dispose();
    _url.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _importFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'md'],
        withData: true,
      );
      final file = result?.files.single;
      if (file?.bytes == null) return;
      _text.text = utf8.decode(file!.bytes!, allowMalformed: true);
      if (_title.text.trim().isEmpty) {
        _title.text = file.name.replaceAll(RegExp(r'\.(txt|md)$'), '');
      }
      setState(() => _error = null);
    } catch (_) {
      setState(() => _error = 'Could not read that file.');
    }
  }

  Future<void> _save() async {
    final store = widget.services.userDocs;
    if (store == null) return;
    final title = _title.text.trim();
    final text = _text.text;
    final url = _url.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give the document a title.');
      return;
    }
    if (text.trim().isEmpty && url.isEmpty) {
      setState(
        () => _error =
            'Add the document\'s text (paste or import a file), or at '
            'least its official link.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await store.add(
        UserDocument(
          id: 'doc-${DateTime.now().microsecondsSinceEpoch}',
          title: title,
          citation: _citation.text.trim(),
          authority: _authority,
          sourceUrl: url.isEmpty ? null : url,
          text: text,
          addedAt: DateTime.now(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on ArgumentError catch (e) {
      setState(() {
        _saving = false;
        _error = e.message as String?;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add a document')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'e.g. DAFMAN 11-502, Group 1–2 sUAS',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _citation,
            decoration: const InputDecoration(
              labelText: 'Citation (optional)',
              hintText: 'e.g. DAFMAN 11-502 · N.C.G.S. § 143-74.3',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _authority,
            decoration: const InputDecoration(
              labelText: 'Issuing authority',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final a in kDocumentAuthorities)
                DropdownMenuItem(value: a, child: Text(a)),
            ],
            onChanged: (v) => setState(() => _authority = v ?? _authority),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'Official link (optional)',
              hintText: 'https://…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text(
                'Document text',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Import .txt / .md'),
                onPressed: _importFile,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            maxLines: 12,
            minLines: 6,
            decoration: const InputDecoration(
              hintText: 'Paste the document\'s text here…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'PDF text extraction isn\'t built into the app yet — for a '
            'PDF, paste its text or save the official link above. A '
            'link-only entry still shows up in your library and search.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save to my library'),
          ),
          const SizedBox(height: 8),
          const Text(
            'Saved only on this device. Plain-English explanations '
            'aren\'t written for documents you add — the Reader shows '
            'your text as the original, which is what counts.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          // Keep the accent visible on the primary surface.
          const Divider(color: PlainRegsTheme.surfaceHigh),
        ],
      ),
    );
  }
}
