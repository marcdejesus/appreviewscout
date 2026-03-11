import '../../domain/models/app_model.dart';
import '../../domain/models/result.dart';
import '../services/api_service.dart';

class AppRepository {
  AppRepository(this._apiService);

  final ApiService _apiService;
  List<AppModel> _apps = const <AppModel>[];

  List<AppModel> get apps => _apps;

  Future<Result<List<AppModel>>> fetchApps({int? projectId}) async {
    try {
      final rows = await _apiService.getApps(projectId: projectId);
      _apps = rows.map(AppModel.fromJson).toList(growable: false);
      return Ok(_apps);
    } catch (e) {
      return Error<List<AppModel>>('Failed to load apps', exception: e);
    }
  }

  Future<Result<AppModel>> addPlayApp(
    String url, {
    bool downloadScreenshots = false,
  }) async {
    try {
      await _apiService.addPlayApp(url, downloadScreenshots: downloadScreenshots);
      final refreshResult = await fetchApps();
      if (refreshResult case Ok<List<AppModel>>(:final value)) {
        final created = value.firstWhere(
          (app) => app.playStoreId == _extractPlayStoreId(url),
          orElse: () => value.first,
        );
        return Ok(created);
      }
      return const Error<AppModel>('App was added, but refresh failed');
    } catch (e) {
      return Error<AppModel>('Failed to add app', exception: e);
    }
  }

  String? _extractPlayStoreId(String url) {
    final uri = Uri.tryParse(url);
    return uri?.queryParameters['id'];
  }
}
