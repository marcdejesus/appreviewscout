import 'package:flutter/foundation.dart';

import '../../data/repositories/project_repository.dart';
import '../../domain/models/project_model.dart';
import '../../domain/models/result.dart';
import 'active_project_viewmodel.dart';

class ProjectsViewModel extends ChangeNotifier {
  ProjectsViewModel(this._projectRepository, this._activeProjectViewModel);

  final ProjectRepository _projectRepository;
  final ActiveProjectViewModel _activeProjectViewModel;

  List<ProjectModel> _projects = const [];
  List<ProjectModel> get projects => _projects;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    final result = await _projectRepository.fetchProjects();
    _loading = false;
    if (result case Ok(:final value)) {
      _projects = value;
      _error = null;
    } else if (result case Error(:final message)) {
      _error = message;
    }
    notifyListeners();
    await _activeProjectViewModel.loadProjects();
  }

  Future<bool> createProject({
    required String name,
    String? description,
    String? icon,
    List<int>? appIds,
  }) async {
    final result = await _projectRepository.createProject(
      name: name,
      description: description,
      icon: icon,
      appIds: appIds,
    );
    if (result case Ok()) {
      await load();
      return true;
    }
    if (result case Error(:final message)) {
      _error = message;
      notifyListeners();
    }
    return false;
  }

  Future<bool> updateProject(
    int id, {
    String? name,
    String? description,
    String? icon,
    List<int>? appIds,
  }) async {
    final result = await _projectRepository.updateProject(
      id,
      name: name,
      description: description,
      icon: icon,
      appIds: appIds,
    );
    if (result case Ok()) {
      await load();
      return true;
    }
    if (result case Error(:final message)) {
      _error = message;
      notifyListeners();
    }
    return false;
  }

  Future<bool> deleteProject(int id) async {
    final result = await _projectRepository.deleteProject(id);
    if (result case Ok()) {
      if (_activeProjectViewModel.selectedProjectId == id) {
        _activeProjectViewModel.setSelectedProject(null);
      }
      await load();
      return true;
    }
    if (result case Error(:final message)) {
      _error = message;
      notifyListeners();
    }
    return false;
  }
}
