import 'package:flutter/material.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../domain/models/app_model.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.app});

  final AppModel app;

  static const double _appIconSize = 80;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final imageUrl = app.iconPath != null ? '${ApiConfig.staticUrl}/${app.iconPath}' : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface0,
        borderRadius: BorderRadius.circular(tokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              child: imageUrl == null
                  ? _placeholderIcon(context)
                  : Image.network(
                      imageUrl,
                      width: _appIconSize,
                      height: _appIconSize,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _placeholderIcon(context),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              app.appName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    app.playStoreId ?? app.appId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.textMuted,
                        ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, 'Downloads', app.downloadCount ?? '-'),
              _chip(context, 'Reviews', app.totalReviews ?? '-'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, String value) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surface1,
        borderRadius: BorderRadius.circular(tokens.radiusSm),
        border: Border.all(color: tokens.borderSoft),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tokens.textSecondary,
            ),
      ),
    );
  }

  Widget _placeholderIcon(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: _appIconSize,
      height: _appIconSize,
      color: tokens.surface2,
      alignment: Alignment.center,
      child: Icon(Icons.apps_rounded, color: tokens.textTertiary, size: 32),
    );
  }
}
