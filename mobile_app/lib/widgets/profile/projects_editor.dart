import 'package:flutter/material.dart';
import '../../models/project_model.dart';
import '../../utils/app_theme.dart';
import '../modern/modern_text_field.dart';
import '../modern/modern_button.dart';

class ProjectsEditor extends StatefulWidget {
  final List<ProjectModel> projects;
  final Function(List<ProjectModel>) onProjectsChanged;

  const ProjectsEditor({
    super.key,
    required this.projects,
    required this.onProjectsChanged,
  });

  @override
  State<ProjectsEditor> createState() => _ProjectsEditorState();
}

class _ProjectsEditorState extends State<ProjectsEditor> {
  late List<ProjectModel> _projects;

  @override
  void initState() {
    super.initState();
    _projects = List.from(widget.projects);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.lightGrayColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.folder,
                    color: AppTheme.secondaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: AppTheme.spaceSm),
                  Text(
                    'Projects',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryColor,
                        ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _addProject,
                icon: const Icon(
                  Icons.add_circle,
                  color: AppTheme.secondaryColor,
                  size: 28,
                ),
                tooltip: 'Add Project',
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spaceSm),

          Text(
            'Showcase Your Projects',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.grayColor,
                ),
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Projects List
          if (_projects.isEmpty)
            _buildEmptyState()
          else
            ..._projects.asMap().entries.map((entry) {
              final index = entry.key;
              final project = entry.value;
              return _buildProjectCard(project, index);
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.lightGrayColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.lightGrayColor,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.folder_open,
            size: 48,
            color: AppTheme.grayColor,
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Text(
            'No projects added',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.grayColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Text(
            'Tap + to start adding',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.grayColor,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: AppTheme.lightGrayColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.lightGrayColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  project.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.secondaryColor,
                      ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _editProject(project, index),
                    icon: const Icon(
                      Icons.edit,
                      color: AppTheme.secondaryColor,
                      size: 20,
                    ),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    onPressed: () => _deleteProject(index),
                    icon: const Icon(
                      Icons.delete,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                    tooltip: 'Delete',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceXs),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 16,
                color: AppTheme.grayColor,
              ),
              const SizedBox(width: AppTheme.spaceXs),
              Text(
                _formatDateRange(project.startDate, project.endDate),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.grayColor,
                    ),
              ),
            ],
          ),
          if (project.description.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              project.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          if (project.technologies.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Wrap(
              spacing: AppTheme.spaceXs,
              runSpacing: AppTheme.spaceXs,
              children: project.technologies
                  .map((tech) => Chip(
                        label: Text(
                          tech,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                          ),
                        ),
                        backgroundColor:
                            AppTheme.secondaryColor.withValues(alpha: 0.1),
                        side: BorderSide(
                            color:
                                AppTheme.secondaryColor.withValues(alpha: 0.3)),
                      ))
                  .toList(),
            ),
          ],
          if (project.projectUrl != null && project.projectUrl!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Row(
              children: [
                const Icon(
                  Icons.link,
                  size: 16,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: AppTheme.spaceXs),
                Expanded(
                  child: Text(
                    project.projectUrl!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          decoration: TextDecoration.underline,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateRange(DateTime startDate, DateTime? endDate) {
    final start = '${startDate.month}/${startDate.year}';
    final end =
        endDate != null ? '${endDate.month}/${endDate.year}' : 'Ongoing';
    return '$start - $end';
  }

  void _addProject() {
    _showProjectDialog();
  }

  void _editProject(ProjectModel project, int index) {
    _showProjectDialog(project: project, index: index);
  }

  void _deleteProject(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: const Text('Are you sure you want to delete this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _projects.removeAt(index);
              });
              widget.onProjectsChanged(_projects);
              Navigator.pop(context);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showProjectDialog({ProjectModel? project, int? index}) {
    final titleController = TextEditingController(text: project?.title ?? '');
    final descriptionController =
        TextEditingController(text: project?.description ?? '');
    final urlController =
        TextEditingController(text: project?.projectUrl ?? '');
    final technologiesController = TextEditingController(
      text: project?.technologies.join(', ') ?? '',
    );

    DateTime startDate = project?.startDate ?? DateTime.now();
    DateTime? endDate = project?.endDate;
    bool isOngoing = endDate == null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            project == null ? 'Add Project' : 'Edit Project',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModernTextField(
                  controller: titleController,
                  label: 'Project Title',
                  icon: Icons.folder,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter project title';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppTheme.spaceMd),

                ModernTextField(
                  controller: descriptionController,
                  label: 'Description',
                  icon: Icons.description,
                  maxLines: 3,
                ),

                const SizedBox(height: AppTheme.spaceMd),

                ModernTextField(
                  controller: technologiesController,
                  label: 'Technologies',
                  icon: Icons.code,
                  hintText: 'e.g., Flutter, Firebase, Node.js',
                ),

                const SizedBox(height: AppTheme.spaceMd),

                ModernTextField(
                  controller: urlController,
                  label: 'Project URL',
                  icon: Icons.link,
                  hintText: 'https://github.com/username/project',
                ),

                const SizedBox(height: AppTheme.spaceMd),

                // Date pickers would go here
                // For now, using simple text display
                Text('Start Date: ${startDate.month}/${startDate.year}'),
                if (!isOngoing && endDate != null)
                  Text('End Date: ${endDate!.month}/${endDate!.year}'),

                CheckboxListTile(
                  title: const Text('Ongoing Project'),
                  value: isOngoing,
                  onChanged: (value) {
                    setDialogState(() {
                      isOngoing = value ?? false;
                      if (isOngoing) {
                        endDate = null;
                      } else {
                        endDate = DateTime.now();
                      }
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ModernButton(
              text: 'Save',
              onPressed: () {
                if (titleController.text.trim().isNotEmpty) {
                  final technologies = technologiesController.text
                      .split(',')
                      .map((tech) => tech.trim())
                      .where((tech) => tech.isNotEmpty)
                      .toList();

                  final newProject = ProjectModel(
                    id: project?.id ??
                        'proj_${DateTime.now().millisecondsSinceEpoch}',
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    technologies: technologies,
                    startDate: startDate,
                    endDate: isOngoing ? null : endDate,
                    projectUrl: urlController.text.trim().isEmpty
                        ? null
                        : urlController.text.trim(),
                  );

                  setState(() {
                    if (index != null) {
                      _projects[index] = newProject;
                    } else {
                      _projects.add(newProject);
                    }
                  });

                  widget.onProjectsChanged(_projects);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
