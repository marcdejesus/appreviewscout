import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../domain/models/result.dart';
import '../../viewmodels/app_list_viewmodel.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import 'add_app_dialog.dart';

class AppListView extends StatefulWidget {
  const AppListView({super.key});

  @override
  State<AppListView> createState() => _AppListViewState();
}

class _AppListViewState extends State<AppListView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppListViewModel>().load.execute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AppListViewModel>();
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Tracked Apps', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _onAddApp(context),
              icon: const Icon(Icons.add),
              label: const Text('Add App'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (vm.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              vm.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.error),
            ),
          ),
        Expanded(
          child: ListenableBuilder(
            listenable: vm.load,
            builder: (context, _) {
              if (vm.load.running && vm.apps.isEmpty) {
                return const LoadingState(label: 'Loading apps...');
              }
              if (vm.apps.isEmpty) {
                return const EmptyState(
                  title: 'No apps tracked yet',
                  message: 'Add a Play Store app to start collecting reviews.',
                  icon: Icons.apps_outlined,
                );
              }
              return GridView.builder(
                itemCount: vm.apps.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.5,
                ),
                itemBuilder: (_, index) => AppCard(app: vm.apps[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _onAddApp(BuildContext context) async {
    final result = await showAddAppDialog(context);
    if (!context.mounted || result == null) {
      return;
    }

    final (url, downloadScreenshots) = result;
    final vm = context.read<AppListViewModel>();
    await vm.addPlayApp.execute(
      AddAppInput(
        url: url,
        downloadScreenshots: downloadScreenshots,
      ),
    );

    if (!context.mounted) {
      return;
    }
    final addResult = vm.addPlayApp.result;
    if (addResult is Error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add app')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('App added')),
      );
    }
  }
}
