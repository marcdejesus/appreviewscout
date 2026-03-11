import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../data/repositories/app_repository.dart';
import '../../../data/repositories/project_repository.dart';
import '../../../domain/models/app_model.dart';
import '../../../domain/models/project_model.dart';
import '../../../domain/models/result.dart';
import '../../viewmodels/projects_viewmodel.dart';
import '../../widgets/project_icon_helper.dart';

class AddOrEditProjectView extends StatefulWidget {
  const AddOrEditProjectView({
    super.key,
    this.project,
    required this.onSaved,
    required this.onCancel,
  });

  final ProjectModel? project;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  @override
  State<AddOrEditProjectView> createState() => _AddOrEditProjectViewState();
}

class _AddOrEditProjectViewState extends State<AddOrEditProjectView> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedIconKey;
  final Set<int> _selectedAppIds = {};
  List<AppModel> _allApps = [];
  bool _appsLoading = true;

  bool get isEditing => widget.project != null;

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _nameController.text = widget.project!.name;
      _descriptionController.text = widget.project!.description ?? '';
      _selectedIconKey = widget.project!.icon;
      _loadProjectAndApps();
    } else {
      _selectedIconKey = 'strokeRoundedFolder01';
      _loadAllApps();
    }
  }

  Future<void> _loadProjectAndApps() async {
    final projectId = widget.project!.id;
    final projectRepo = context.read<ProjectRepository>();
    final appRepo = context.read<AppRepository>();
    final projectResult = await projectRepo.fetchProject(projectId);
    await appRepo.fetchApps(projectId: null);
    if (!mounted) return;
    if (projectResult case Ok<ProjectModel>(:final value)) {
      if (value.appIds != null) _selectedAppIds.addAll(value.appIds!);
      _nameController.text = value.name;
      _descriptionController.text = value.description ?? '';
      _selectedIconKey = value.icon ?? 'strokeRoundedFolder01';
    }
    setState(() {
      _allApps = appRepo.apps;
      _appsLoading = false;
    });
  }

  Future<void> _loadAllApps() async {
    final repo = context.read<AppRepository>();
    await repo.fetchApps(projectId: null);
    if (mounted) {
      setState(() {
        _allApps = repo.apps;
        _appsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProjectsViewModel>();
    final tokens = context.tokens;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isEditing ? 'Edit project' : 'New project',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Project name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Optional description',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Text('Icon', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: projectIconPickerOptions.map((e) {
              final isSelected = _selectedIconKey == e.key;
              return GestureDetector(
                onTap: () => setState(() => _selectedIconKey = e.key),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected ? tokens.surface1 : tokens.surface0,
                    borderRadius: BorderRadius.circular(tokens.radiusSm),
                    border: Border.all(
                      color: isSelected ? tokens.accent : tokens.borderSoft,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: projectIconWidget(
                      iconKey: e.key,
                      size: 24,
                      color: isSelected ? tokens.accent : tokens.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('Apps in this project', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_appsLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_allApps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No apps yet. Add apps from the Apps page first.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.textSecondary,
                    ),
              ),
            )
          else
            ..._allApps.map((app) => CheckboxListTile(
                  value: _selectedAppIds.contains(app.id),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedAppIds.add(app.id);
                      } else {
                        _selectedAppIds.remove(app.id);
                      }
                    });
                  },
                  title: Text(app.appName),
                  secondary: const Icon(Icons.apps_rounded),
                )),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: vm.loading
                    ? null
                    : () => _save(context),
                child: vm.loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEditing ? 'Save' : 'Create'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }
    final vm = context.read<ProjectsViewModel>();
    final success = isEditing
        ? await vm.updateProject(
            widget.project!.id,
            name: name,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            icon: _selectedIconKey,
            appIds: _selectedAppIds.toList(),
          )
        : await vm.createProject(
            name: name,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            icon: _selectedIconKey,
            appIds: _selectedAppIds.isEmpty ? null : _selectedAppIds.toList(),
          );
    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Project updated' : 'Project created')),
        );
        widget.onSaved();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(vm.error ?? 'Failed to save')),
        );
      }
    }
  }
}
