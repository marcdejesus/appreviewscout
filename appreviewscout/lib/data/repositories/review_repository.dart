import '../../domain/models/result.dart';
import '../../domain/models/review_model.dart';
import '../services/api_service.dart';

class PaginatedReviews {
  const PaginatedReviews({required this.reviews, required this.total});
  final List<ReviewModel> reviews;
  final int total;
}

class ReviewRepository {
  ReviewRepository(this._apiService);

  final ApiService _apiService;
  List<ReviewModel> _reviews = const <ReviewModel>[];
  List<ReviewModel> _featureRequests = const <ReviewModel>[];

  List<ReviewModel> get reviews => _reviews;
  List<ReviewModel> get featureRequests => _featureRequests;

  Future<Result<PaginatedReviews>> fetchReviews({
    String? appId,
    String? platform,
    int? projectId,
    bool featureRequestOnly = false,
    bool? pinned,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final data = await _apiService.getReviews(
        appId: appId,
        platform: platform,
        projectId: projectId,
        featureRequestOnly: featureRequestOnly,
        pinned: pinned,
        limit: limit,
        offset: offset,
      );
      final rawList = data['reviews'] as List<dynamic>;
      final list = rawList
          .map((item) => ReviewModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(growable: false);
      final total = data['total'] as int;
      _reviews = list;
      return Ok(PaginatedReviews(reviews: list, total: total));
    } catch (e) {
      return Error<PaginatedReviews>('Failed to load reviews', exception: e);
    }
  }

  Future<void> setReviewPinned(int reviewId, bool pinned) async {
    await _apiService.setReviewPinned(reviewId, pinned);
  }

  Future<Result<List<ReviewModel>>> fetchFeatureRequests({
    String? appId,
    String? platform,
    int? projectId,
  }) async {
    try {
      final rows = await _apiService.getFeatureRequests(
        appId: appId,
        platform: platform,
        projectId: projectId,
      );
      _featureRequests = rows.map(ReviewModel.fromJson).toList(growable: false);
      return Ok(_featureRequests);
    } catch (e) {
      return Error<List<ReviewModel>>('Failed to load feature requests', exception: e);
    }
  }
}
