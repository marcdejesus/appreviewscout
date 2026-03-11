import '../../domain/models/project_model.dart';
import '../../domain/models/result.dart';
import '../services/api_service.dart';

class ProjectRepository {
  ProjectRepository(this._apiService);

  final ApiService _apiService;

  Future<Result<List<ProjectModel>>> fetchProjects() async {
    try {
      final rows = await _apiService.getProjects();
      final list = rows.map(ProjectModel.fromJson).toList(growable: false);
      return Ok(list);
    } catch (e) {
      return Error<List<ProjectModel>>('Failed to load projects', exception: e);
    }
  }

  Future<Result<ProjectModel>> fetchProject(int id) async {
    try {
      final map = await _apiService.getProject(id);
      return Ok(ProjectModel.fromJson(map));
    } catch (e) {
      return Error<ProjectModel>('Failed to load project', exception: e);
    }
  }

  Future<Result<ProjectModel>> createProject({
    required String name,
    String? description,
    String? icon,
    List<int>? appIds,
  }) async {
    try {
      final map = await _apiService.createProject(
        name: name,
        description: description,
        icon: icon,
        appIds: appIds,
      );
      return Ok(ProjectModel.fromJson(map));
    } catch (e) {
      return Error<ProjectModel>('Failed to create project', exception: e);
    }
  }

  Future<Result<ProjectModel>> updateProject(
    int id, {
    String? name,
    String? description,
    String? icon,
    List<int>? appIds,
  }) async {
    try {
      final map = await _apiService.updateProject(
        id,
        name: name,
        description: description,
        icon: icon,
        appIds: appIds,
      );
      return Ok(ProjectModel.fromJson(map));
    } catch (e) {
      return Error<ProjectModel>('Failed to update project', exception: e);
    }
  }

  Future<Result<void>> deleteProject(int id) async {
    try {
      await _apiService.deleteProject(id);
      return const Ok(null);
    } catch (e) {
      return Error<void>('Failed to delete project', exception: e);
    }
  }
}
