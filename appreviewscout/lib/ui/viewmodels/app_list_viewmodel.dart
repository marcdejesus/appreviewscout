import 'package:flutter/foundation.dart';

import '../../data/repositories/app_repository.dart';
import '../../domain/commands/command.dart';
import '../../domain/models/app_model.dart';
import '../../domain/models/result.dart';
import 'active_project_viewmodel.dart';

class AppListViewModel extends ChangeNotifier {
  AppListViewModel(this._appRepository, this._activeProjectViewModel) {
    load = Command0<List<AppModel>>(_loadApps);
    addPlayApp = Command1<AppModel, AddAppInput>(_addPlayApp);
  }

  final AppRepository _appRepository;
  final ActiveProjectViewModel _activeProjectViewModel;

  List<AppModel> _apps = const <AppModel>[];
  List<AppModel> get apps => _apps;

  String? _error;
  String? get error => _error;

  late final Command0<List<AppModel>> load;
  late final Command1<AppModel, AddAppInput> addPlayApp;

  Future<Result<List<AppModel>>> _loadApps() async {
    final result = await _appRepository.fetchApps(
      projectId: _activeProjectViewModel.selectedProjectId,
    );
    if (result case Ok<List<AppModel>>(:final value)) {
      _apps = value;
      _error = null;
    } else if (result case Error<List<AppModel>>(:final message)) {
      _error = message;
    }
    notifyListeners();
    return result;
  }

  Future<Result<AppModel>> _addPlayApp(AddAppInput input) async {
    final result = await _appRepository.addPlayApp(
      input.url,
      downloadScreenshots: input.downloadScreenshots,
    );
    if (result case Ok<AppModel>()) {
      _apps = _appRepository.apps;
      _error = null;
    } else if (result case Error<AppModel>(:final message)) {
      _error = message;
    }
    notifyListeners();
    return result;
  }
}

class AddAppInput {
  const AddAppInput({
    required this.url,
    required this.downloadScreenshots,
  });

  final String url;
  final bool downloadScreenshots;
}
