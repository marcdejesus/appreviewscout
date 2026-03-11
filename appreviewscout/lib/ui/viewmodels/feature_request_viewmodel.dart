import 'package:flutter/foundation.dart';

import '../../data/repositories/review_repository.dart';
import '../../domain/commands/command.dart';
import '../../domain/models/result.dart';
import '../../domain/models/review_model.dart';

class FeatureRequestViewModel extends ChangeNotifier {
  FeatureRequestViewModel(this._reviewRepository) {
    load = Command0<List<ReviewModel>>(_loadFeatureRequests);
  }

  final ReviewRepository _reviewRepository;

  List<ReviewModel> _items = const <ReviewModel>[];
  List<ReviewModel> get items => _items;

  String? _selectedAppId;
  String? get selectedAppId => _selectedAppId;

  String? _error;
  String? get error => _error;

  late final Command0<List<ReviewModel>> load;

  Future<void> setAppFilter(String? appId) async {
    _selectedAppId = appId;
    notifyListeners();
    await load.execute();
  }

  int get appCount => _items.map((item) => item.storeAppId).toSet().length;

  Future<Result<List<ReviewModel>>> _loadFeatureRequests() async {
    final result = await _reviewRepository.fetchFeatureRequests(appId: _selectedAppId);
    if (result case Ok<List<ReviewModel>>(:final value)) {
      _items = value;
      _error = null;
    } else if (result case Error<List<ReviewModel>>(:final message)) {
      _error = message;
    }
    notifyListeners();
    return result;
  }
}
