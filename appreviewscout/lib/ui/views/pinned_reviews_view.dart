import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../viewmodels/pinned_reviews_viewmodel.dart';
import '../widgets/empty_state.dart';
import '../widgets/loading_state.dart';
import '../widgets/review_tile.dart';

class PinnedReviewsView extends StatelessWidget {
  const PinnedReviewsView({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PinnedReviewsViewModel>();
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pinned Reviews', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (vm.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              vm.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.error),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: vm.loading && vm.reviews.isEmpty
              ? const LoadingState(label: 'Loading pinned reviews...')
              : vm.reviews.isEmpty
                  ? const EmptyState(
                      title: 'No pinned reviews',
                      message: 'Pin reviews from the Reviews list to see them here.',
                      icon: Icons.push_pin_outlined,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: vm.reviews.length,
                            itemBuilder: (context, index) => ReviewTile(
                              review: vm.reviews[index],
                              onPinPressed: (r) => vm.setReviewPinned(r.id, !r.pinned),
                            ),
                          ),
                        ),
                        _buildPagination(context, vm),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildPagination(BuildContext context, PinnedReviewsViewModel vm) {
    final tokens = context.tokens;
    final pageCount = vm.pageCount;
    if (pageCount <= 1) return const SizedBox.shrink();
    final currentPage = vm.currentPage;
    final totalCount = vm.totalCount;
    final start = currentPage * PinnedReviewsViewModel.pageSize + 1;
    final end = (currentPage + 1) * PinnedReviewsViewModel.pageSize;
    final endClamped = end > totalCount ? totalCount : end;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: tokens.surface0,
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filled(
            onPressed: currentPage > 0 && !vm.loading
                ? () => vm.goToPage(currentPage - 1)
                : null,
            icon: const Icon(Icons.chevron_left),
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Page ${currentPage + 1} of $pageCount',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.textSecondary,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            '($start–$endClamped of $totalCount)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: tokens.textMuted,
                ),
          ),
          const SizedBox(width: 16),
          IconButton.filled(
            onPressed: currentPage < pageCount - 1 && !vm.loading
                ? () => vm.goToPage(currentPage + 1)
                : null,
            icon: const Icon(Icons.chevron_right),
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
