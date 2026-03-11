import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../viewmodels/feature_request_viewmodel.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/review_tile.dart';
import '../../widgets/stat_chip.dart';

class FeatureRequestView extends StatefulWidget {
  const FeatureRequestView({super.key});

  @override
  State<FeatureRequestView> createState() => _FeatureRequestViewState();
}

class _FeatureRequestViewState extends State<FeatureRequestView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeatureRequestViewModel>().load.execute();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FeatureRequestViewModel>();
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Feature Requests', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatChip(
              label: 'Feature Requests',
              value: vm.items.length.toString(),
              highlight: true,
            ),
            StatChip(
              label: 'Distinct Apps',
              value: vm.appCount.toString(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (vm.error != null)
          Text(
            vm.error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.error),
          ),
        Expanded(
          child: ListenableBuilder(
            listenable: vm.load,
            builder: (context, _) {
              if (vm.load.running && vm.items.isEmpty) {
                return const LoadingState(label: 'Loading feature requests...');
              }
              if (vm.items.isEmpty) {
                return const EmptyState(
                  title: 'No feature requests yet',
                  message: 'Run scraping and feature detection to populate this view.',
                  icon: Icons.lightbulb_outline_rounded,
                );
              }
              return ListView.builder(
                itemCount: vm.items.length,
                itemBuilder: (_, index) => ReviewTile(
                  review: vm.items[index],
                  highlight: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
