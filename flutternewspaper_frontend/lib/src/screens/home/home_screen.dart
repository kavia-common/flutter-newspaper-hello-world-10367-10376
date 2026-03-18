import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../state/news_app_state.dart';
import '../device_token/device_token_screen.dart';
import '../notification_test/notification_test_screen.dart';
import '../saved/saved_news_screen.dart';
import '../settings/settings_screen.dart';
import 'tabs/business_tab.dart';
import 'tabs/entertainment_tab.dart';
import 'tabs/general_tab.dart';
import 'tabs/health_tab.dart';
import 'tabs/science_tab.dart';
import 'tabs/sports_tab.dart';
import 'tabs/technology_tab.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const routeName = '/';

  static const _tabs = <_CategoryTabSpec>[
    _CategoryTabSpec(title: AppConstants.homeTabTitle, widget: GeneralTab()),
    _CategoryTabSpec(title: AppConstants.business, widget: BusinessTab()),
    _CategoryTabSpec(title: AppConstants.entertainment, widget: EntertainmentTab()),
    _CategoryTabSpec(title: AppConstants.science, widget: ScienceTab()),
    _CategoryTabSpec(title: AppConstants.sports, widget: SportsTab()),
    _CategoryTabSpec(title: AppConstants.technology, widget: TechnologyTab()),
    _CategoryTabSpec(title: AppConstants.health, widget: HealthTab()),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NewsAppState>();

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        // Ensures a leading hamburger icon can appear when appropriate and also
        // provides a secondary navigation path (without relying on AppBar icons).
        drawer: const _HomeDrawer(),
        appBar: AppBar(
          title: const Text('Pavana'),
          actions: [
            IconButton(
              tooltip: 'Saved News',
              onPressed: () => Navigator.of(context).pushNamed(SavedNewsScreen.routeName),
              icon: const Icon(Icons.bookmarks_outlined),
            ),
            IconButton(
              tooltip: 'Settings',
              onPressed: () => Navigator.of(context).pushNamed(SettingsScreen.routeName),
              icon: const Icon(Icons.settings_outlined),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: AppConstants.homeTabTitle),
              Tab(text: AppConstants.business),
              Tab(text: AppConstants.entertainment),
              Tab(text: AppConstants.science),
              Tab(text: AppConstants.sports),
              Tab(text: AppConstants.technology),
              Tab(text: AppConstants.health),
            ],
          ),
        ),
        body: Column(
          children: [
            if (state.errorMessage != null && !state.isLoading)
              Material(
                color: Theme.of(context).colorScheme.surface,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.withAlpha(0x33)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.wifi_off, color: Colors.grey.withAlpha(0xAA)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.errorMessage!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const Expanded(
              child: TabBarView(
                children: [
                  GeneralTab(),
                  BusinessTab(),
                  EntertainmentTab(),
                  ScienceTab(),
                  SportsTab(),
                  TechnologyTab(),
                  HealthTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabSpec {
  const _CategoryTabSpec({required this.title, required this.widget});

  final String title;
  final Widget widget;
}

class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'News App',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(SettingsScreen.routeName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmarks_outlined),
              title: const Text('Saved News'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(SavedNewsScreen.routeName);
              },
            ),
          ],
        ),
      ),
    );
  }
}
