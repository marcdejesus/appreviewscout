import 'package:flutter/foundation.dart';

import '../../data/repositories/review_repository.dart';
import '../../domain/commands/command.dart';
import '../../domain/models/result.dart';
import '../../domain/models/review_model.dart';
import 'active_project_viewmodel.dart';

class ReviewFilters {
  const ReviewFilters({
    this.appId,
    this.platform,
    this.projectId,
    this.featureRequestOnly = false,
  });

  final String? appId;
  final String? platform;
  final int? projectId;
  final bool featureRequestOnly;
}

class ReviewListViewModel extends ChangeNotifier {
  static const int pageSize = 20;

  ReviewListViewModel(this._reviewRepository, this._activeProjectViewModel) {
    load = Command0<List<ReviewModel>>(_loadReviews);
  }

  final ReviewRepository _reviewRepository;
  final ActiveProjectViewModel _activeProjectViewModel;

  List<ReviewModel> _reviews = const <ReviewModel>[];
  List<ReviewModel> get reviews => _reviews;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  int _currentPage = 0;
  int get currentPage => _currentPage;

  int get pageCount => _totalCount == 0 ? 0 : (_totalCount / pageSize).ceil();

  ReviewFilters _filters = const ReviewFilters();
  ReviewFilters get filters => _filters;

  String? _error;
  String? get error => _error;

  late final Command0<List<ReviewModel>> load;

  Future<void> setFilters(ReviewFilters filters) async {
    assert(() {
      debugPrint('[ReviewListVM] setFilters called: appId=${filters.appId}, platform=${filters.platform}, featureOnly=${filters.featureRequestOnly}');
      return true;
    }());
    _filters = filters;
    _currentPage = 0;
    notifyListeners();
    Result<List<ReviewModel>> result = await load.execute();
    assert(() {
      debugPrint('[ReviewListVM] load.execute() returned: running=${load.running}, result is Error=${result is Error}, message=${result is Error ? (result as Error<List<ReviewModel>>).message : ""}');
      return true;
    }());
    if (result is Error<List<ReviewModel>> &&
        result.message == 'Command already running') {
      debugPrint('[ReviewListVM] Command was already running, waiting then retrying...');
      while (load.running) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await load.execute();
      debugPrint('[ReviewListVM] Retry load completed. reviews.length=${_reviews.length}');
    }
  }

  Future<void> goToPage(int page) async {
    if (page < 0 || page >= pageCount) return;
    _currentPage = page;
    notifyListeners();
    await load.execute();
  }

  Future<void> setReviewPinned(int reviewId, bool pinned) async {
    await _reviewRepository.setReviewPinned(reviewId, pinned);
    notifyListeners();
    await load.execute();
    notifyListeners();
  }

  Future<Result<List<ReviewModel>>> _loadReviews() async {
    final projectId = _activeProjectViewModel.selectedProjectId ?? _filters.projectId;
    assert(() {
      debugPrint('[ReviewListVM] _loadReviews page=$_currentPage filters: appId=${_filters.appId}, platform=${_filters.platform}, projectId=$projectId');
      return true;
    }());
    final result = await _reviewRepository.fetchReviews(
      appId: _filters.appId,
      platform: _filters.platform,
      projectId: projectId,
      featureRequestOnly: _filters.featureRequestOnly,
      limit: pageSize,
      offset: _currentPage * pageSize,
    );
    if (result case Ok(:final value)) {
      _reviews = value.reviews;
      _totalCount = value.total;
      _error = null;
      debugPrint('[ReviewListVM] _loadReviews OK: ${value.reviews.length} reviews, total=${value.total}');
      notifyListeners();
      return Ok(_reviews);
    } else if (result case Error<PaginatedReviews>(:final message)) {
      _error = message;
      debugPrint('[ReviewListVM] _loadReviews ERROR: $message');
      notifyListeners();
      return Error<List<ReviewModel>>(message);
    }
    notifyListeners();
    return Ok(_reviews);
  }
}
