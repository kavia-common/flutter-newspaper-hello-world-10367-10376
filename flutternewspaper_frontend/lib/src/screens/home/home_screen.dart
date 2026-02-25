import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../state/news_app_state.dart';
import '../saved/saved_news_screen.dart';
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
    final hasApiKey = (dotenv.env['NEWSAPI_KEY']?.trim().isNotEmpty ?? false);

    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('News App'),
          actions: [
            IconButton(
              tooltip: 'Saved News',
              onPressed: () => Navigator.of(context).pushNamed(SavedNewsScreen.routeName),
              icon: const Icon(Icons.bookmarks_outlined),
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
        body: Builder(
          builder: (context) {
            // Show setup instructions in-app (non-blocking) when NEWSAPI_KEY is missing.
            final setupBanner = hasApiKey
                ? const SizedBox.shrink()
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary.withAlpha(0x14),
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor.withAlpha(0x44),
                        ),
                      ),
                    ),
                    child: const Text(
                      'Preview mode: NEWSAPI_KEY is not set. '
                      'Add it to a .env file (see .env.example) to load live news.',
                      textAlign: TextAlign.center,
                    ),
                  );

            if (state.errorMessage != null && !state.isLoading) {
              // Keep existing error behavior for real network failures, etc.
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    state.errorMessage!,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            return Column(
              children: [
                setupBanner,
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
            );
          },
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
