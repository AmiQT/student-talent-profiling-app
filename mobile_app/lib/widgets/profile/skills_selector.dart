import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class SkillsSelector extends StatefulWidget {
  final List<String> selectedSkills;
  final Function(List<String>) onSkillsChanged;

  const SkillsSelector({
    super.key,
    required this.selectedSkills,
    required this.onSkillsChanged,
  });

  @override
  State<SkillsSelector> createState() => _SkillsSelectorState();
}

class _SkillsSelectorState extends State<SkillsSelector> {
  final TextEditingController _customSkillController = TextEditingController();
  late List<String> _selectedSkills;

  // Predefined skills categories
  static const Map<String, List<String>> _skillCategories = {
    'Programming': [
      'Flutter',
      'Dart',
      'Java',
      'Python',
      'JavaScript',
      'TypeScript',
      'C++',
      'C#',
      'Swift',
      'Kotlin',
      'React',
      'Vue.js',
      'Angular',
      'Node.js',
      'PHP',
      'Ruby',
      'Go',
      'Rust',
      'HTML',
      'CSS'
    ],
    'Design': [
      'UI/UX Design',
      'Graphic Design',
      'Adobe Photoshop',
      'Adobe Illustrator',
      'Figma',
      'Sketch',
      'Adobe XD',
      'Canva',
      'InDesign',
      'After Effects',
      'Blender',
      '3D Modeling',
      'Animation',
      'Video Editing'
    ],
    'Data & Analytics': [
      'Data Analysis',
      'Machine Learning',
      'Data Science',
      'SQL',
      'Power BI',
      'Tableau',
      'Excel',
      'R',
      'MATLAB',
      'Statistics',
      'Big Data',
      'Data Visualization',
      'Business Intelligence'
    ],
    'Business': [
      'Project Management',
      'Leadership',
      'Communication',
      'Teamwork',
      'Problem Solving',
      'Critical Thinking',
      'Public Speaking',
      'Presentation',
      'Marketing',
      'Sales',
      'Customer Service',
      'Strategic Planning',
      'Business Analysis'
    ],
    'Technical': [
      'Database Management',
      'Cloud Computing',
      'AWS',
      'Azure',
      'Google Cloud',
      'DevOps',
      'Docker',
      'Kubernetes',
      'Git',
      'Linux',
      'Windows Server',
      'Network Administration',
      'Cybersecurity',
      'System Administration'
    ],
    'Creative': [
      'Writing',
      'Content Creation',
      'Photography',
      'Music Production',
      'Creative Writing',
      'Copywriting',
      'Social Media',
      'Blogging',
      'Storytelling',
      'Brand Development',
      'Creative Direction'
    ]
  };

  @override
  void initState() {
    super.initState();
    _selectedSkills = List.from(widget.selectedSkills);
  }

  @override
  void dispose() {
    _customSkillController.dispose();
    super.dispose();
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
            children: [
              const Icon(
                Icons.star,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Text(
                'Skills',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spaceSm),

          Text(
            'Select Your Skills',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.grayColor,
                ),
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Selected Skills Display
          if (_selectedSkills.isNotEmpty) ...[
            Text(
              'Selected Skills (${_selectedSkills.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Wrap(
              spacing: AppTheme.spaceXs,
              runSpacing: AppTheme.spaceXs,
              children: _selectedSkills
                  .map((skill) => _buildSelectedSkillChip(skill))
                  .toList(),
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],

          // Add Custom Skill
          _buildAddCustomSkillSection(),

          const SizedBox(height: AppTheme.spaceMd),

          // Skill Categories
          Text(
            'Skill Categories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),

          const SizedBox(height: AppTheme.spaceSm),

          // Categories List
          ..._skillCategories.entries.map(
              (category) => _buildSkillCategory(category.key, category.value)),
        ],
      ),
    );
  }

  Widget _buildSelectedSkillChip(String skill) {
    return Chip(
      label: Text(
        skill,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: AppTheme.primaryColor,
      deleteIcon: const Icon(
        Icons.close,
        color: Colors.white,
        size: 18,
      ),
      onDeleted: () {
        setState(() {
          _selectedSkills.remove(skill);
        });
        widget.onSkillsChanged(_selectedSkills);
      },
    );
  }

  Widget _buildAddCustomSkillSection() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: AppTheme.lightGrayColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.lightGrayColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _customSkillController,
              decoration: const InputDecoration(
                hintText: 'Add custom skill',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
              ),
              onSubmitted: _addCustomSkill,
            ),
          ),
          IconButton(
            onPressed: () => _addCustomSkill(_customSkillController.text),
            icon: const Icon(
              Icons.add_circle,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCategory(String categoryName, List<String> skills) {
    return ExpansionTile(
      title: Text(
        categoryName,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
      ),
      leading: Icon(
        _getCategoryIcon(categoryName),
        color: AppTheme.primaryColor,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
          child: Wrap(
            spacing: AppTheme.spaceXs,
            runSpacing: AppTheme.spaceXs,
            children: skills.map((skill) => _buildSkillChip(skill)).toList(),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
      ],
    );
  }

  Widget _buildSkillChip(String skill) {
    final isSelected = _selectedSkills.contains(skill);

    return FilterChip(
      label: Text(
        skill,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            if (!_selectedSkills.contains(skill)) {
              _selectedSkills.add(skill);
            }
          } else {
            _selectedSkills.remove(skill);
          }
        });
        widget.onSkillsChanged(_selectedSkills);
      },
      backgroundColor: Colors.white,
      selectedColor: AppTheme.primaryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.primaryColor : AppTheme.lightGrayColor,
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName) {
      case 'Programming':
        return Icons.code;
      case 'Design':
        return Icons.palette;
      case 'Data & Analytics':
        return Icons.analytics;
      case 'Business':
        return Icons.business;
      case 'Technical':
        return Icons.settings;
      case 'Creative':
        return Icons.brush;
      default:
        return Icons.category;
    }
  }

  void _addCustomSkill(String skill) {
    final trimmedSkill = skill.trim();
    if (trimmedSkill.isNotEmpty && !_selectedSkills.contains(trimmedSkill)) {
      setState(() {
        _selectedSkills.add(trimmedSkill);
        _customSkillController.clear();
      });
      widget.onSkillsChanged(_selectedSkills);
    }
  }
}
