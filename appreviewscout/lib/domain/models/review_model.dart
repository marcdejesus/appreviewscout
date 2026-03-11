class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.appPk,
    required this.storeAppId,
    required this.appName,
    required this.platform,
    required this.content,
    this.rating,
    this.title,
    this.author,
    this.reviewDate,
    this.hasFeatureRequest = false,
    this.pinned = false,
  });

  final int id;
  final int appPk;
  final String storeAppId;
  final String appName;
  final String platform;
  final String content;
  final int? rating;
  final String? title;
  final String? author;
  final String? reviewDate;
  final bool hasFeatureRequest;
  final bool pinned;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: _parseInt(json['id']) ?? 0,
      appPk: _parseInt(json['app_id']) ?? 0,
      storeAppId: _parseString(json['store_app_id']) ?? '',
      appName: _parseString(json['app_name']) ?? 'Unknown App',
      platform: _parseString(json['platform']) ?? 'Google Play',
      content: _parseString(json['content']) ?? '',
      rating: _parseInt(json['rating']),
      title: _parseString(json['title']),
      author: _parseString(json['author']),
      reviewDate: _parseString(json['review_date']),
      hasFeatureRequest: _parseBool(json['has_feature_request']),
      pinned: json['pinned'] == null ? false : _parseBool(json['pinned']),
    );
  }

  ReviewModel copyWith({bool? pinned}) {
    return ReviewModel(
      id: id,
      appPk: appPk,
      storeAppId: storeAppId,
      appName: appName,
      platform: platform,
      content: content,
      rating: rating,
      title: title,
      author: author,
      reviewDate: reviewDate,
      hasFeatureRequest: hasFeatureRequest,
      pinned: pinned ?? this.pinned,
    );
  }
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

bool _parseBool(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value == 1;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == '1' || normalized == 'true';
  }
  return false;
}
