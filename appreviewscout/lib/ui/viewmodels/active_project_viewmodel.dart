import 'package:flutter/foundation.dart';

import '../../data/repositories/project_repository.dart';
import '../../domain/models/project_model.dart';
import '../../domain/models/result.dart';

class ActiveProjectViewModel extends ChangeNotifier {
  ActiveProjectViewModel(this._projectRepository);

  final ProjectRepository _projectRepository;

  int? _selectedProjectId;
  int? get selectedProjectId => _selectedProjectId;
  void setSelectedProject(int? id) {
    if (_selectedProjectId == id) return;
    _selectedProjectId = id;
    notifyListeners();
  }

  List<ProjectModel> _projects = const [];
  List<ProjectModel> get projects => _projects;

  ProjectModel? get selectedProject {
    if (_selectedProjectId == null) return null;
    try {
      return _projects.firstWhere((p) => p.id == _selectedProjectId);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadProjects() async {
    final result = await _projectRepository.fetchProjects();
    if (result case Ok(:final value)) {
      _projects = value;
      notifyListeners();
    }
  }
}
