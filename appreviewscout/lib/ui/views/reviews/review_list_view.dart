import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../domain/models/app_model.dart';
import '../../viewmodels/app_list_viewmodel.dart';
import '../../viewmodels/review_list_viewmodel.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/loading_state.dart';
import '../../widgets/review_tile.dart';

class ReviewListView extends StatefulWidget {
  const ReviewListView({super.key});

  @override
  State<ReviewListView> createState() => _ReviewListViewState();
}

class _ReviewListViewState extends State<ReviewListView> {
  String _platform = '';
  bool _featureOnly = false;
  AppModel? _selectedApp;
  TextEditingController? _appsFieldController;
  void _onAppsFieldChanged() {
    if (_appsFieldController?.text.trim().isEmpty ?? true) {
      if (mounted) setState(() => _selectedApp = null);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReviewListViewModel>().load.execute();
      context.read<AppListViewModel>().load.execute();
    });
  }

  @override
  void dispose() {
    _appsFieldController?.removeListener(_onAppsFieldChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReviewListViewModel>();
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.surface0,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: 260,
                height: 48,
                child: _buildAppsAutocomplete(context),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                height: 48,
                child: DropdownButtonFormField<String>(
                  value: _platform.isEmpty ? null : _platform,
                  decoration: const InputDecoration(
                    labelText: 'Platform',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All')),
                    DropdownMenuItem(value: 'Google Play', child: Text('Google Play')),
                  ],
                  onChanged: (value) => setState(() => _platform = value ?? ''),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: Center(
                  child: FilterChip(
                    label: const Text('Feature Requests Only'),
                    selected: _featureOnly,
                    onSelected: (value) => setState(() => _featureOnly = value),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () => _applyFilters(context),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: () => _clearFilters(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text('Clear Filters'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (vm.error != null)
          Text(
            vm.error!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.error),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: ListenableBuilder(
            listenable: vm.load,
            builder: (context, child) {
              if (vm.load.running && vm.reviews.isEmpty) {
                return const LoadingState(label: 'Loading reviews...');
              }
              if (vm.reviews.isEmpty) {
                return const EmptyState(
                  title: 'No reviews found',
                  message: 'Try changing your filters or run a new scrape.',
                );
              }
              return Column(
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPagination(BuildContext context, ReviewListViewModel vm) {
    final tokens = context.tokens;
    final pageCount = vm.pageCount;
    if (pageCount <= 1) return const SizedBox.shrink();
    final currentPage = vm.currentPage;
    final totalCount = vm.totalCount;
    final start = currentPage * ReviewListViewModel.pageSize + 1;
    final end = (currentPage + 1) * ReviewListViewModel.pageSize;
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
            onPressed: currentPage > 0 && !vm.load.running
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
            onPressed: currentPage < pageCount - 1 && !vm.load.running
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

  Widget _buildAppsAutocomplete(BuildContext context) {
    final appVm = context.watch<AppListViewModel>();
    final apps = appVm.apps;

    return Autocomplete<AppModel>(
      displayStringForOption: (app) => app.appName,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return apps;
        return apps.where(
          (app) => app.appName.toLowerCase().startsWith(query),
        );
      },
      onSelected: (app) {
        setState(() => _selectedApp = app);
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (_appsFieldController != controller) {
          _appsFieldController?.removeListener(_onAppsFieldChanged);
          _appsFieldController = controller;
          _appsFieldController!.addListener(_onAppsFieldChanged);
        }
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Apps',
            hintText: 'All apps',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final app = options.elementAt(index);
                  return ListTile(
                    title: Text(app.appName),
                    onTap: () => onSelected(app),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _applyFilters(BuildContext context) async {
    final vm = context.read<ReviewListViewModel>();
    final appVm = context.read<AppListViewModel>();
    final String? appId = _selectedApp != null &&
            appVm.apps.any((a) => a.appId == _selectedApp!.appId)
        ? _selectedApp!.appId
        : null;
    await vm.setFilters(
      ReviewFilters(
        appId: appId,
        platform: _platform.isEmpty ? null : _platform,
        featureRequestOnly: _featureOnly,
      ),
    );
    if (appId == null && _selectedApp != null) {
      setState(() {
        _selectedApp = null;
        _appsFieldController?.clear();
      });
    }
  }

  Future<void> _clearFilters(BuildContext context) async {
    debugPrint('[ReviewListView] _clearFilters pressed');
    final vm = context.read<ReviewListViewModel>();
    setState(() {
      _selectedApp = null;
      _platform = '';
      _featureOnly = false;
    });
    _appsFieldController?.clear();
    await vm.setFilters(const ReviewFilters());
    debugPrint('[ReviewListView] _clearFilters setFilters completed');
  }
}
