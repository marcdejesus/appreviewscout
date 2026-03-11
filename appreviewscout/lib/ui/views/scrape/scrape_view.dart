import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../domain/models/result.dart';
import '../../viewmodels/scrape_viewmodel.dart';
import '../../widgets/status_badge.dart';

class ScrapeView extends StatefulWidget {
  const ScrapeView({super.key});

  @override
  State<ScrapeView> createState() => _ScrapeViewState();
}

class _ScrapeViewState extends State<ScrapeView> {
  final _urlController = TextEditingController();
  final _maxScrollsController = TextEditingController(text: '50');
  final _pauseMsController = TextEditingController(text: '1500');
  final _minReviewsController = TextEditingController(text: '0');
  bool _showAdvanced = false;

  @override
  void dispose() {
    _urlController.dispose();
    _maxScrollsController.dispose();
    _pauseMsController.dispose();
    _minReviewsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScrapeViewModel>();
    final tokens = context.tokens;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scrape Play Store', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface0,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    labelText: 'Play Store URL',
                    hintText: 'https://play.google.com/store/apps/details?id=...',
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                  icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
                  label: const Text('Advanced Options'),
                ),
                if (_showAdvanced) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _maxScrollsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max Scrolls'),
                        ),
                      ),
                      SizedBox(
                        width: 180,
                        child: TextField(
                          controller: _pauseMsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Scroll Pause (ms)'),
                        ),
                      ),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _minReviewsController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Reviews'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: vm.noBrowser,
                    title: const Text('No Browser Mode'),
                    subtitle: const Text('Use HTTP fetch only when possible'),
                    onChanged: vm.setNoBrowser,
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: vm.start.running ? null : () => _startScrape(context),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(vm.start.running ? 'Starting...' : 'Start Scrape'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface0,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              border: Border.all(color: tokens.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Current Job', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 8),
                    StatusBadge(status: vm.job.status),
                    const Spacer(),
                    TextButton(
                      onPressed: () => vm.refreshStatus.execute(),
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text('Job ID: ${vm.job.jobId ?? '-'}'),
                if (vm.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    vm.error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tokens.error),
                  ),
                ],
                if (vm.job.result != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _summaryChip(context, 'Parsed', vm.job.result!.reviewsParsed),
                      _summaryChip(context, 'Inserted', vm.job.result!.reviewsInserted),
                      _summaryChip(context, 'Feature Req', vm.job.result!.featureRequestsFlagged),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(BuildContext context, String label, int value) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surface1,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: Text('$label: $value'),
    );
  }

  Future<void> _startScrape(BuildContext context) async {
    final vm = context.read<ScrapeViewModel>();
    vm.url = _urlController.text.trim();
    vm.maxScrolls = int.tryParse(_maxScrollsController.text.trim()) ?? 50;
    vm.scrollPauseMs = int.tryParse(_pauseMsController.text.trim()) ?? 1500;
    vm.minReviews = int.tryParse(_minReviewsController.text.trim()) ?? 0;

    await vm.start.execute();
    if (!context.mounted) {
      return;
    }
    final result = vm.start.result;
    if (result is Error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scrape failed to start')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scrape started')),
      );
    }
  }
}
