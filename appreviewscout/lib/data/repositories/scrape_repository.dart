import '../../domain/models/result.dart';
import '../../domain/models/scrape_job.dart';
import '../services/api_service.dart';

class ScrapeRepository {
  ScrapeRepository(this._apiService);

  final ApiService _apiService;
  ScrapeJobModel _latestJob = const ScrapeJobModel(jobId: null, status: 'idle');

  ScrapeJobModel get latestJob => _latestJob;

  Future<Result<String>> startScrape(ScrapeRequestModel request) async {
    try {
      final jobId = await _apiService.startScrape(request);
      _latestJob = ScrapeJobModel(
        jobId: jobId,
        status: 'pending',
      );
      return Ok(jobId);
    } catch (e) {
      return Error<String>('Failed to start scrape', exception: e);
    }
  }

  Future<Result<ScrapeJobModel>> fetchStatus({String? jobId}) async {
    try {
      final status = await _apiService.getScrapeStatus(jobId: jobId ?? _latestJob.jobId);
      _latestJob = ScrapeJobModel.fromJson(status);
      return Ok(_latestJob);
    } catch (e) {
      return Error<ScrapeJobModel>('Failed to fetch scrape status', exception: e);
    }
  }
}
