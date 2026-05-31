import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../services/supabase_auth_service.dart';
import '../../../services/achievement_service.dart';
import '../../../models/user_model.dart';
import '../../../models/achievement_model.dart';
import '../../../widgets/custom_text_field.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _currentUser;
  bool _showAddDialog = false;
  bool _isGridView = false;
  AchievementModel? _editingAchievement;
  late AnimationController _animationController;
  late Animation<double> _animation;

  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _organizationController = TextEditingController();

  AchievementType _selectedType = AchievementType.academic;
  DateTime? _selectedDate;
  File? _selectedCertificate;
  File? _selectedImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _organizationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _showAddAchievementDialog() {
    _resetForm();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _buildAddEditSheet(),
      ),
    ).whenComplete(() {
      setState(() {
        _showAddDialog = false;
        _editingAchievement = null;
      });
    });
    setState(() {
      _showAddDialog = true;
      _editingAchievement = null;
    });
  }

  void _showEditAchievementDialog(AchievementModel achievement) {
    _editingAchievement = achievement;
    _titleController.text = achievement.title;
    _descriptionController.text = achievement.description;
    _organizationController.text = achievement.organization ?? '';
    _selectedType = achievement.type;
    _selectedDate = achievement.dateAchieved;

    setState(() {
      _showAddDialog = true;
    });
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _organizationController.clear();
    _selectedType = AchievementType.academic;
    _selectedDate = null;
    _selectedCertificate = null;
    _selectedImage = null;
  }

  Future<void> _pickCertificate() async {
    // Remove: try {
    // Remove: FilePickerResult? result = await FilePicker.platform.pickFiles(
    // Remove: type: FileType.custom,
    // Remove: allowedExtensions: ['pdf', 'doc', 'docx'],
    // Remove: );

    // Remove: if (result != null) {
    // Remove: setState(() {
    // Remove: _selectedCertificate = File(result.files.single.path!);
    // Remove: });
    // Remove: }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveAchievement() async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentUser == null) return;

    try {
      final achievementService =
          Provider.of<AchievementService>(context, listen: false);

      String? certificateUrl = _editingAchievement?.certificateUrl;
      String? imageUrl = _editingAchievement?.imageUrl;

      // Upload new certificate if selected
      if (_selectedCertificate != null) {
        certificateUrl = await achievementService.uploadCertificate(
          _currentUser!.id,
          _selectedCertificate!,
        );
      }

      // Upload new image if selected
      if (_selectedImage != null) {
        imageUrl = await achievementService.uploadAchievementImage(
          _currentUser!.id,
          _selectedImage!,
        );
      }

      final achievement = AchievementModel(
        id: _editingAchievement?.id ?? '',
        userId: _currentUser!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        organization: _organizationController.text.trim().isEmpty
            ? null
            : _organizationController.text.trim(),
        dateAchieved: _selectedDate,
        certificateUrl: certificateUrl,
        imageUrl: imageUrl,
        points: achievementService.getDefaultPoints(_selectedType),
        isVerified: false,
        verifiedBy: null,
        verifiedAt: null,
        createdAt: _editingAchievement?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_editingAchievement != null) {
        await achievementService.updateAchievement(achievement);
      } else {
        await achievementService.createAchievement(achievement);
      }

      setState(() {
        _showAddDialog = false;
      });

      _resetForm();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editingAchievement != null
                ? 'Achievement updated successfully!'
                : 'Achievement added successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving achievement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);
    final achievementService =
        Provider.of<AchievementService>(context, listen: false);
    final userId = authService.currentUser?.id;
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Achievements'),
            actions: [
              Tooltip(
                message: _isGridView ? 'Show as list' : 'Show as grid',
                child: IconButton(
                  icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                      _animationController.reset();
                      _animationController.forward();
                    });
                  },
                ),
              ),
              Tooltip(
                message: 'Add achievement',
                child: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showAddAchievementDialog,
                ),
              ),
            ],
          ),
          body: userId == null
              ? const Center(child: Text('No user found.'))
              : StreamBuilder<List<AchievementModel>>(
                  stream: achievementService.streamAchievementsByUserId(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final achievements = snapshot.data ?? [];
                    if (achievements.isEmpty) {
                      return _buildEmptyState();
                    }
                    return _isGridView
                        ? _buildAchievementsGridWithData(achievements)
                        : _buildAchievementsListWithData(achievements);
                  },
                ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: "achievements_add_fab",
            onPressed: _showAddAchievementDialog,
            tooltip: 'Add Achievement',
            icon: const Icon(Icons.add),
            label: const Text('Add Achievement'),
          ),
        ),
        if (_showAddDialog) _buildAddEditSheet(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text('No achievements yet. Add your first achievement!',
          style: TextStyle(fontSize: 16, color: Colors.grey)),
    );
  }

  Widget _buildAchievementsListWithData(List<AchievementModel> achievements) {
    return FadeTransition(
      opacity: _animation,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ExpansionTile(
              leading: Semantics(
                label: 'Achievement icon',
                child: const Icon(Icons.emoji_events,
                    color: Colors.amber, size: 32),
              ),
              title: Text(
                achievement.title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              initiallyExpanded: false,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    achievement.description,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAchievementsGridWithData(List<AchievementModel> achievements) {
    return FadeTransition(
      opacity: _animation,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        itemCount: achievements.length,
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showEditAchievementDialog(achievement),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _getTypeColor(achievement.type)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getTypeIcon(achievement.type),
                        color: _getTypeColor(achievement.type),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      achievement.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTypeDisplayName(achievement.type),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _getTypeColor(achievement.type),
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      achievement.description,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    _buildVerificationBadge(achievement.isVerified),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVerificationBadge(bool isVerified) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isVerified
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVerified ? Icons.verified : Icons.pending,
            size: 16,
            color: isVerified ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            isVerified ? 'Verified' : 'Pending',
            style: TextStyle(
              color: isVerified ? Colors.green : Colors.orange,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(AchievementType type) {
    switch (type) {
      case AchievementType.academic:
        return Colors.blue;
      case AchievementType.competition:
        return Colors.purple;
      case AchievementType.leadership:
        return Colors.green;
      case AchievementType.skill:
        return Colors.orange;
      case AchievementType.other:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(AchievementType type) {
    switch (type) {
      case AchievementType.academic:
        return Icons.school;
      case AchievementType.competition:
        return Icons.emoji_events;
      case AchievementType.leadership:
        return Icons.people;
      case AchievementType.skill:
        return Icons.psychology;
      case AchievementType.other:
        return Icons.star;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getTypeDisplayName(AchievementType type) {
    switch (type) {
      case AchievementType.academic:
        return 'Academic';
      case AchievementType.competition:
        return 'Competition';
      case AchievementType.leadership:
        return 'Leadership';
      case AchievementType.skill:
        return 'Skill';
      case AchievementType.other:
        return 'Other';
    }
  }

  Widget _buildAddEditSheet() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Row(
                    children: [
                      Icon(Icons.emoji_events,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        _editingAchievement != null
                            ? 'Edit Achievement'
                            : 'Add Achievement',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  CustomTextField(
                    controller: _titleController,
                    labelText: 'Title',
                    hintText: "e.g. Dean's List, Hackathon Winner",
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _descriptionController,
                    labelText: 'Description',
                    hintText: 'Describe your achievement',
                    maxLines: 2,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AchievementType>(
                    initialValue: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: AchievementType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getTypeDisplayName(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: _organizationController,
                    labelText: 'Organization',
                    hintText: 'e.g. University, Company (optional)',
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Date Achieved'),
                    subtitle: Text(_selectedDate != null
                        ? _formatDate(_selectedDate!)
                        : 'Select date'),
                    trailing: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _selectDate,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Certificate'),
                          onPressed: _pickCertificate,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.image),
                          label: const Text('Image'),
                          onPressed: _pickImage,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedCertificate != null ||
                      _selectedImage != null) ...[
                    const SizedBox(height: 8),
                    if (_selectedCertificate != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(
                          'Certificate: ${_selectedCertificate!.path.split('/').last}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    if (_selectedImage != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading:
                            const Icon(Icons.check_circle, color: Colors.blue),
                        title: Text(
                          'Image: ${_selectedImage!.path.split('/').last}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _resetForm();
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _saveAchievement,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                            _editingAchievement != null ? 'Update' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
