import 'dart:convert';

class AppModel {
  const AppModel({
    required this.id,
    required this.appId,
    required this.appName,
    this.playStoreId,
    this.playStoreUrl,
    this.iconPath,
    this.downloadCount,
    this.totalReviews,
    this.description,
    this.screenshots = const <ScreenshotRef>[],
  });

  final int id;
  final String appId;
  final String appName;
  final String? playStoreId;
  final String? playStoreUrl;
  final String? iconPath;
  final String? downloadCount;
  final String? totalReviews;
  final String? description;
  final List<ScreenshotRef> screenshots;

  AppModel copyWith({
    int? id,
    String? appId,
    String? appName,
    String? playStoreId,
    String? playStoreUrl,
    String? iconPath,
    String? downloadCount,
    String? totalReviews,
    String? description,
    List<ScreenshotRef>? screenshots,
  }) {
    return AppModel(
      id: id ?? this.id,
      appId: appId ?? this.appId,
      appName: appName ?? this.appName,
      playStoreId: playStoreId ?? this.playStoreId,
      playStoreUrl: playStoreUrl ?? this.playStoreUrl,
      iconPath: iconPath ?? this.iconPath,
      downloadCount: downloadCount ?? this.downloadCount,
      totalReviews: totalReviews ?? this.totalReviews,
      description: description ?? this.description,
      screenshots: screenshots ?? this.screenshots,
    );
  }

  factory AppModel.fromJson(Map<String, dynamic> json) {
    final screenshotsRaw = json['screenshots'];
    return AppModel(
      id: _parseInt(json['id']) ?? 0,
      appId: _parseString(json['app_id']) ?? _parseString(json['play_store_id']) ?? '',
      appName: _parseString(json['app_name']) ?? 'Unknown App',
      playStoreId: _parseString(json['play_store_id']),
      playStoreUrl: _parseString(json['play_store_url']),
      iconPath: _parseString(json['icon_path']),
      downloadCount: _parseString(json['download_count']),
      totalReviews: _parseString(json['total_reviews']),
      description: _parseString(json['description']),
      screenshots: _parseScreenshots(screenshotsRaw),
    );
  }
}

class ScreenshotRef {
  const ScreenshotRef({required this.path, this.url});

  final String path;
  final String? url;

  factory ScreenshotRef.fromJson(Map<String, dynamic> json) {
    return ScreenshotRef(
      path: _parseString(json['path']) ?? '',
      url: _parseString(json['url']),
    );
  }
}

List<ScreenshotRef> _parseScreenshots(dynamic raw) {
  if (raw == null) {
    return const <ScreenshotRef>[];
  }

  dynamic value = raw;
  if (raw is String && raw.isNotEmpty) {
    try {
      value = jsonDecode(raw);
    } catch (_) {
      return const <ScreenshotRef>[];
    }
  }

  if (value is! List) {
    return const <ScreenshotRef>[];
  }

  return value
      .whereType<Map>()
      .map((item) => ScreenshotRef.fromJson(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

int? _parseInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

String? _parseString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
