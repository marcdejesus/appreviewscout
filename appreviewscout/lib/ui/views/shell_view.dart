import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../viewmodels/active_project_viewmodel.dart';
import '../viewmodels/app_list_viewmodel.dart';
import '../viewmodels/pinned_reviews_viewmodel.dart';
import '../viewmodels/projects_viewmodel.dart';
import '../viewmodels/review_list_viewmodel.dart';
import '../widgets/project_icon_helper.dart';
import 'apps/app_list_view.dart';
import 'pinned_reviews_view.dart';
import 'projects/projects_view.dart';
import 'reviews/review_list_view.dart';
import 'scrape/scrape_view.dart';

enum AppSection { apps, reviews, pinnedReviews, projects, scrape }

class ShellView extends StatefulWidget {
  const ShellView({super.key});

  @override
  State<ShellView> createState() => _ShellViewState();
}

class _ShellViewState extends State<ShellView> {
  AppSection _section = AppSection.apps;

  void _onProjectSelected(BuildContext context, int? projectId) {
    context.read<ActiveProjectViewModel>().setSelectedProject(projectId);
    context.read<AppListViewModel>().load.execute();
    context.read<ReviewListViewModel>().load.execute();
    context.read<PinnedReviewsViewModel>().load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final activeProject = context.watch<ActiveProjectViewModel>();
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 220,
            decoration: BoxDecoration(
              color: tokens.canvas,
              border: Border(right: BorderSide(color: tokens.borderSoft)),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                    child: Text(
                      'AppReviewScout',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: tokens.accent,
                          ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    child: Container(
                      decoration: BoxDecoration(
                        color: tokens.surface0,
                        borderRadius: BorderRadius.circular(tokens.radiusSm),
                        border: Border.all(
                          color: activeProject.selectedProject != null
                              ? tokens.border
                              : tokens.borderSoft,
                        ),
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          popupMenuTheme: PopupMenuThemeData(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(tokens.radiusSm),
                            ),
                          ),
                        ),
                        child: PopupMenuButton<int?>(
                          onOpened: () => activeProject.loadProjects(),
                          tooltip: 'Select project',
                          offset: const Offset(0, 4),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(tokens.radiusSm),
                          ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.folder_rounded,
                              size: 18,
                              color: activeProject.selectedProject != null
                                  ? tokens.accent
                                  : tokens.textTertiary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                activeProject.selectedProject?.name ?? 'All',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: activeProject.selectedProject != null
                                          ? tokens.textPrimary
                                          : tokens.textSecondary,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: activeProject.selectedProject != null
                                  ? tokens.accent
                                  : tokens.textTertiary,
                            ),
                          ],
                        ),
                      itemBuilder: (context) {
                        const menuPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 10);
                        const menuWidth = 200.0;
                        final menuItemChild = (Widget row) => SizedBox(
                          width: menuWidth,
                          child: row,
                        );
                        final items = <PopupMenuEntry<int?>>[
                          PopupMenuItem<int?>(
                            value: null,
                            padding: menuPadding,
                            child: menuItemChild(Row(
                              children: [
                                Icon(Icons.folder_rounded, size: 18, color: tokens.textTertiary),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text('All', overflow: TextOverflow.ellipsis),
                                ),
                              ],
                            )),
                          ),
                          const PopupMenuDivider(),
                        ];
                        for (final p in activeProject.projects) {
                          items.add(
                            PopupMenuItem<int?>(
                              value: p.id,
                              padding: menuPadding,
                              child: menuItemChild(Row(
                                children: [
                                  SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: projectIconWidget(
                                      iconKey: p.icon,
                                      size: 18,
                                      color: tokens.textTertiary,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )),
                            ),
                          );
                        }
                        items.add(const PopupMenuDivider());
                        items.add(
                          PopupMenuItem<int?>(
                            value: -1,
                            padding: menuPadding,
                            child: menuItemChild(Row(
                              children: [
                                Icon(Icons.add, size: 18, color: tokens.textTertiary),
                                const SizedBox(width: 10),
                                const Text('Add project...'),
                              ],
                            )),
                          ),
                        );
                        return items;
                      },
                      onSelected: (value) {
                        if (value == -1) {
                          setState(() => _section = AppSection.projects);
                        } else {
                          _onProjectSelected(context, value);
                        }
                      },
                        ),
                      ),
                    ),
                  ),
                  _navTile(context, AppSection.projects, Icons.folder_rounded, 'Manage projects'),
                  _navTile(context, AppSection.apps, Icons.apps_rounded, 'Apps'),
                  _navTile(context, AppSection.reviews, Icons.reviews_rounded, 'Reviews'),
                  _navTile(context, AppSection.pinnedReviews, Icons.push_pin_rounded, 'Pinned'),
                  _navTile(context, AppSection.scrape, Icons.cloud_sync_rounded, 'Scrape'),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IndexedStack(
                index: _section.index,
                children: [
                  const AppListView(),
                  const ReviewListView(),
                  const PinnedReviewsView(),
                  const ProjectsView(),
                  const ScrapeView(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(BuildContext context, AppSection section, IconData icon, String label) {
    final tokens = context.tokens;
    final isActive = _section == section;
    return InkWell(
      onTap: () {
        if (section == AppSection.pinnedReviews) {
          context.read<PinnedReviewsViewModel>().load();
        }
        if (section == AppSection.projects) {
          context.read<ProjectsViewModel>().load();
        }
        setState(() => _section = section);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? tokens.surface0 : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          border: Border.all(
            color: isActive ? tokens.border : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? tokens.accent : tokens.textTertiary),
            const SizedBox(width: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: isActive ? tokens.textPrimary : tokens.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
