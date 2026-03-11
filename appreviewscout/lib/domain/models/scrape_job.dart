class ScrapeRequestModel {
  const ScrapeRequestModel({
    required this.url,
    this.maxScrolls = 50,
    this.scrollPauseMs = 1500,
    this.minReviews = 0,
    this.noBrowser = false,
  });

  final String url;
  final int maxScrolls;
  final int scrollPauseMs;
  final int minReviews;
  final bool noBrowser;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'url': url,
      'max_scrolls': maxScrolls,
      'scroll_pause_ms': scrollPauseMs,
      'min_reviews': minReviews,
      'no_browser': noBrowser,
    };
  }
}

class ScrapeResultModel {
  const ScrapeResultModel({
    required this.reviewsParsed,
    required this.reviewsInserted,
    required this.featureRequestsFlagged,
  });

  final int reviewsParsed;
  final int reviewsInserted;
  final int featureRequestsFlagged;

  factory ScrapeResultModel.fromJson(Map<String, dynamic> json) {
    return ScrapeResultModel(
      reviewsParsed: _parseInt(json['reviews_parsed']) ?? 0,
      reviewsInserted: _parseInt(json['reviews_inserted']) ?? 0,
      featureRequestsFlagged: _parseInt(json['feature_requests_flagged']) ?? 0,
    );
  }
}

class ScrapeJobModel {
  const ScrapeJobModel({
    required this.jobId,
    required this.status,
    this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.error,
    this.result,
  });

  final String? jobId;
  final String status;
  final String? createdAt;
  final String? startedAt;
  final String? finishedAt;
  final String? error;
  final ScrapeResultModel? result;

  bool get isRunning => status == 'pending' || status == 'running';
  bool get isDone => status == 'done';
  bool get isFailed => status == 'failed';

  factory ScrapeJobModel.fromJson(Map<String, dynamic> json) {
    final rawResult = json['result'];
    return ScrapeJobModel(
      jobId: _parseString(json['job_id']),
      status: _parseString(json['status']) ?? 'idle',
      createdAt: _parseString(json['created_at']),
      startedAt: _parseString(json['started_at']),
      finishedAt: _parseString(json['finished_at']),
      error: _parseString(json['error']),
      result: rawResult is Map<String, dynamic>
          ? ScrapeResultModel.fromJson(rawResult)
          : rawResult is Map
              ? ScrapeResultModel.fromJson(Map<String, dynamic>.from(rawResult))
              : null,
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
