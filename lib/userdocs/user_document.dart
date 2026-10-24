/// A document the user added themselves — an official publication the
/// app hasn't ingested (or hasn't ingested yet). Lives only on the
/// user's device. See DESIGN.md §13.
class UserDocument {
  final String id;
  final String title;

  /// The document's own citation as the user knows it, e.g.
  /// "DAFMAN 11-502" or "N.C.G.S. § 15A-300.1". May be empty.
  final String citation;

  /// Issuing authority label (FAA, a DoW service, a state, …).
  final String authority;

  /// Where the official document lives, when known.
  final String? sourceUrl;

  /// The document's full text as pasted or imported from a text file.
  /// Empty for link-only entries.
  final String text;

  final DateTime addedAt;

  const UserDocument({
    required this.id,
    required this.title,
    this.citation = '',
    required this.authority,
    this.sourceUrl,
    this.text = '',
    required this.addedAt,
  });

  bool get isLinkOnly => text.trim().isEmpty;

  /// Display label used as the Reader citation.
  String get label => citation.trim().isNotEmpty ? citation.trim() : title;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'citation': citation,
        'authority': authority,
        'sourceUrl': sourceUrl,
        'text': text,
        'addedAt': addedAt.toIso8601String(),
      };

  factory UserDocument.fromJson(Map<String, dynamic> j) => UserDocument(
        id: j['id'] as String,
        title: j['title'] as String,
        citation: (j['citation'] as String?) ?? '',
        authority: (j['authority'] as String?) ?? 'Other official',
        sourceUrl: j['sourceUrl'] as String?,
        text: (j['text'] as String?) ?? '',
        addedAt:
            DateTime.tryParse((j['addedAt'] as String?) ?? '') ??
                DateTime.now(),
      );
}

/// Authorities offered in the Add Document form.
const List<String> kDocumentAuthorities = [
  'FAA',
  'Federal (other)',
  'State',
  'Department of War — Air Force',
  'Department of War — Army',
  'Department of War — Navy',
  'Department of War — Marine Corps',
  'Department of War — Space Force',
  'Other official',
];
