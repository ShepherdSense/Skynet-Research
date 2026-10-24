import 'package:flutter/material.dart';

import '../app_services.dart';
import '../widgets/app_banner.dart';
import 'reader_screen.dart';

class BookmarksScreen extends StatelessWidget {
  final AppServices services;
  const BookmarksScreen({super.key, required this.services});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No top title bar — the banner carries the branding now.
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AppBanner(),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: services.bookmarks,
              builder: (context, _) {
                final items = services.bookmarks.items;
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Nothing saved yet.\nOpen a regulation and tap the '
                        'bookmark icon to keep it here.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final b = items[i];
                    return Dismissible(
                      key: ValueKey(b.ref.key),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red.shade900,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => services.bookmarks.toggle(b.ref),
                      child: ListTile(
                        leading: const Icon(Icons.bookmark),
                        title: Text(b.ref.citation),
                        subtitle: Text(b.ref.heading),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ReaderScreen(services: services, ref: b.ref),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
