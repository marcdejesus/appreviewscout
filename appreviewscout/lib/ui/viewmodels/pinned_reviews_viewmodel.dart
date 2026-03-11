import 'package:flutter/foundation.dart';

import '../../data/repositories/review_repository.dart';
import '../../domain/models/result.dart';
import '../../domain/models/review_model.dart';
import 'active_project_viewmodel.dart';

class PinnedReviewsViewModel extends ChangeNotifier {
  PinnedReviewsViewModel(this._reviewRepository, this._activeProjectViewModel);

  static const int pageSize = 20;

  final ReviewRepository _reviewRepository;
  final ActiveProjectViewModel _activeProjectViewModel;

  List<ReviewModel> _reviews = const <ReviewModel>[];
  List<ReviewModel> get reviews => _reviews;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  int _currentPage = 0;
  int get currentPage => _currentPage;

  int get pageCount => _totalCount == 0 ? 0 : (_totalCount / pageSize).ceil();

  String? _error;
  String? get error => _error;

  bool _loading = false;
  bool get loading => _loading;

  /// Load page 0 (e.g. when user opens Pinned tab). Call from Shell when navigating to Pinned.
  Future<void> load() async {
    _currentPage = 0;
    await _fetchPage();
  }

  Future<void> goToPage(int page) async {
    if (page < 0 || page >= pageCount) return;
    _currentPage = page;
    await _fetchPage();
  }

  Future<void> _fetchPage() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final result = await _reviewRepository.fetchReviews(
        pinned: true,
        projectId: _activeProjectViewModel.selectedProjectId,
        limit: pageSize,
        offset: _currentPage * pageSize,
      );
      if (result case Ok(:final value)) {
        _reviews = value.reviews;
        _totalCount = value.total;
        _error = null;
      } else if (result case Error(:final message)) {
        _error = message;
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setReviewPinned(int reviewId, bool pinned) async {
    await _reviewRepository.setReviewPinned(reviewId, pinned);
    await _fetchPage();
  }
}
