import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/theme.dart';
import '../../../domain/models/project_model.dart';
import '../../viewmodels/projects_viewmodel.dart';
import '../../widgets/project_icon_helper.dart';
import 'add_or_edit_project_view.dart';

/// Public widget for the shell; wraps the stateful content.
class ProjectsView extends StatelessWidget {
  const ProjectsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _ProjectsViewContent();
  }
}

class _ProjectsViewContent extends StatefulWidget {
  const _ProjectsViewContent();

  @override
  State<_ProjectsViewContent> createState() => _ProjectsViewContentState();
}

class _ProjectsViewContentState extends State<_ProjectsViewContent> {
  bool _showAddForm = false;
  int? _editingProjectId;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ProjectsViewModel>();
    final tokens = context.tokens;

    if (_showAddForm) {
      return AddOrEditProjectView(
        onSaved: () => setState(() => _showAddForm = false),
        onCancel: () => setState(() => _showAddForm = false),
      );
    }
    if (_editingProjectId != null) {
      ProjectModel? project;
      for (final p in vm.projects) {
        if (p.id == _editingProjectId) {
          project = p;
          break;
        }
      }
      if (project != null) {
        return AddOrEditProjectView(
          project: project,
          onSaved: () => setState(() => _editingProjectId = null),
          onCancel: () => setState(() => _editingProjectId = null),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Projects',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => setState(() => _showAddForm = true),
              icon: const Icon(Icons.add),
              label: const Text('Create project'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (vm.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              vm.error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.error,
                  ),
            ),
          ),
        Expanded(
          child: vm.loading && vm.projects.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : vm.projects.isEmpty
                  ? Center(
                      child: Text(
                        'No projects yet. Create a project to organize your apps.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: tokens.textSecondary,
                            ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: vm.projects.length,
                      itemBuilder: (context, index) {
                        final project = vm.projects[index];
                        return ListTile(
                          leading: SizedBox(
                            width: 32,
                            height: 32,
                            child: projectIconWidget(
                              iconKey: project.icon,
                              size: 24,
                              color: tokens.textSecondary,
                            ),
                          ),
                          title: Text(project.name),
                          subtitle: project.description != null && project.description!.isNotEmpty
                              ? Text(project.description!)
                              : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => setState(() => _editingProjectId = project.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () {
                                  _confirmDelete(context, vm, project.id, project.name);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ProjectsViewModel vm,
    int projectId,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete project'),
        content: Text('Delete "$name"? Apps in this project will not be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await vm.deleteProject(projectId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Project deleted')),
        );
      }
    }
  }
}
