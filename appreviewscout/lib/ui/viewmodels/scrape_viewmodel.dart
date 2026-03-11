import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/scrape_repository.dart';
import '../../domain/commands/command.dart';
import '../../domain/models/result.dart';
import '../../domain/models/scrape_job.dart';

class ScrapeViewModel extends ChangeNotifier {
  ScrapeViewModel(this._scrapeRepository) {
    start = Command0<String>(_startScrape);
    refreshStatus = Command0<ScrapeJobModel>(_refreshStatus);
  }

  final ScrapeRepository _scrapeRepository;
  Timer? _pollingTimer;

  String url = '';
  int maxScrolls = 50;
  int scrollPauseMs = 1500;
  int minReviews = 0;
  bool noBrowser = false;

  ScrapeJobModel _job = const ScrapeJobModel(jobId: null, status: 'idle');
  ScrapeJobModel get job => _job;

  String? _error;
  String? get error => _error;

  late final Command0<String> start;
  late final Command0<ScrapeJobModel> refreshStatus;

  void setNoBrowser(bool value) {
    noBrowser = value;
    notifyListeners();
  }

  Future<Result<String>> _startScrape() async {
    if (url.trim().isEmpty) {
      return const Error<String>('A Play Store URL is required.');
    }
    final request = ScrapeRequestModel(
      url: url.trim(),
      maxScrolls: maxScrolls,
      scrollPauseMs: scrollPauseMs,
      minReviews: minReviews,
      noBrowser: noBrowser,
    );
    final result = await _scrapeRepository.startScrape(request);
    if (result case Ok<String>()) {
      _error = null;
      await _refreshStatus();
      _startPolling();
    } else if (result case Error<String>(:final message)) {
      _error = message;
    }
    notifyListeners();
    return result;
  }

  Future<Result<ScrapeJobModel>> _refreshStatus() async {
    final result = await _scrapeRepository.fetchStatus(jobId: _job.jobId);
    if (result case Ok<ScrapeJobModel>(:final value)) {
      _job = value;
      _error = null;
      if (!value.isRunning) {
        _stopPolling();
      }
    } else if (result case Error<ScrapeJobModel>(:final message)) {
      _error = message;
      _stopPolling();
    }
    notifyListeners();
    return result;
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      refreshStatus.execute();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
