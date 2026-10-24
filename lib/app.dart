import 'package:flutter/material.dart';

import 'app_services.dart';
import 'screens/bookmarks_screen.dart';
import 'screens/browse_screen.dart';
import 'screens/research_screen.dart';
import 'screens/resources_screen.dart';
import 'screens/fly_check_screen.dart';
import 'screens/search_screen.dart';
import 'theme.dart';
import 'widgets/drone_swarm.dart';

/// App title lives here only — renaming the product is a one-line change.
const String kAppTitle = 'Skynet Research by Shepherd';

class PlainRegsApp extends StatefulWidget {
  final AppServices services;
  const PlainRegsApp({super.key, required this.services});

  @override
  State<PlainRegsApp> createState() => _PlainRegsAppState();
}

class _PlainRegsAppState extends State<PlainRegsApp> {
  int _index = 0;

  /// Drone-swarm tab transition: bumped on every tab change;
  /// direction follows the move (later tab flies right).
  int _swarmTrigger = 0;
  bool _swarmForward = true;

  /// The user's colorway hue (landing-page slider).
  final ThemeHueController _hueCtl = ThemeHueController();

  /// Tabs build lazily on first visit — the Resources catalogue is a
  /// 1.2 MB bundled asset and should not parse at app startup.
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();
    widget.services.bookmarks.load();
    widget.services.userDocs?.load();
    widget.services.savedBriefs?.load();
    _hueCtl.load();
  }

  @override
  void dispose() {
    _hueCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = <Widget Function()>[
      () => SearchScreen(services: widget.services, themeHue: _hueCtl),
      () => FlyCheckScreen(services: widget.services),
      () => BrowseScreen(services: widget.services),
      () => ResearchScreen(services: widget.services),
      () => BookmarksScreen(services: widget.services),
      () => const ResourcesScreen(),
    ];
    final screens = [
      for (var i = 0; i < all.length; i++)
        if (_visited.contains(i)) all[i]() else const SizedBox.shrink(),
    ];
    return AnimatedBuilder(
      animation: _hueCtl,
      builder: (context, _) {
        PlainRegsTheme.hueDeg = _hueCtl.hue;
        return MaterialApp(
          title: kAppTitle,
          theme: PlainRegsTheme.dark,
          home: Scaffold(
            body: Stack(
              children: [
                IndexedStack(index: _index, children: screens),
                Positioned.fill(
                  child: DroneSwarmOverlay(
                    trigger: _swarmTrigger,
                    forward: _swarmForward,
                  ),
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() {
                if (i != _index) {
                  _swarmForward = i > _index;
                  _swarmTrigger++;
                }
                _index = i;
                _visited.add(i);
              }),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.search),
                  label: 'Search',
                ),
                NavigationDestination(
                  icon: Icon(Icons.flight_takeoff),
                  label: 'Can I Fly?',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book),
                  label: 'Browse',
                ),
                NavigationDestination(
                  icon: Icon(Icons.science_outlined),
                  selectedIcon: Icon(Icons.science),
                  label: 'Research',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bookmark),
                  label: 'Bookmarks',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_books),
                  label: 'Resources',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
