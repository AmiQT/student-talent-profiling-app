import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../config/cloudinary_config.dart';
import '../../models/profile_model.dart';
import '../../models/academic_info_model.dart';
import '../../models/experience_model.dart';
import '../../models/project_model.dart';
import '../../services/profile_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/modern/modern_text_field.dart';
import '../../widgets/modern/modern_button.dart';
import '../../widgets/profile/skills_selector.dart';
import '../../widgets/profile/interests_selector.dart';
import '../../widgets/profile/experience_editor.dart';
import '../../widgets/profile/projects_editor.dart';

class ComprehensiveEditProfileScreen extends StatefulWidget {
  final ProfileModel profile;

  const ComprehensiveEditProfileScreen({
    super.key,
    required this.profile,
  });

  @override
  State<ComprehensiveEditProfileScreen> createState() =>
      _ComprehensiveEditProfileScreenState();
}

class _ComprehensiveEditProfileScreenState
    extends State<ComprehensiveEditProfileScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers for basic info
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _bioController;
  late TextEditingController _headlineController;

  // Academic info controllers
  late TextEditingController _studentIdController;
  late TextEditingController _programController;
  late TextEditingController _departmentController;
  late TextEditingController _facultyController;
  late TextEditingController _cgpaController;

  // Profile data
  String? _profileImageUrl;
  List<String> _selectedSkills = [];
  List<String> _selectedInterests = [];
  List<ExperienceModel> _experiences = [];
  List<ProjectModel> _projects = [];
  int _currentSemester = 1;

  final ImagePicker _picker = ImagePicker();

  ImageProvider? _getProfileImageProvider(String? imageUrl) {
    if (imageUrl == null || imageUrl.trim().isEmpty || imageUrl == 'file:///') {
      return null;
    } else if (imageUrl.startsWith('data:image')) {
      // Handle base64 images
      final base64String = imageUrl.split(',')[1];
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } else if (imageUrl.startsWith('http') &&
        Uri.tryParse(imageUrl)?.hasAbsolutePath == true) {
      // Handle valid network images with cache-busting
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final separator = imageUrl.contains('?') ? '&' : '?';
      return NetworkImage('$imageUrl${separator}v=$cacheBuster');
    } else if (imageUrl.startsWith('/') || imageUrl.contains('cache')) {
      // Handle local file images (fallback)
      return FileImage(File(imageUrl));
    } else {
      // Invalid URL, return null to show fallback
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeControllers();
    _loadProfileData();
  }

  void _initializeControllers() {
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _bioController = TextEditingController();
    _headlineController = TextEditingController();
    _studentIdController = TextEditingController();
    _programController = TextEditingController();
    _departmentController = TextEditingController();
    _facultyController = TextEditingController();
    _cgpaController = TextEditingController();
  }

  void _loadProfileData() {
    final profile = widget.profile;

    // Basic info
    _fullNameController.text = profile.fullName;
    _phoneController.text = profile.phoneNumber ?? '';
    _addressController.text = profile.address ?? '';
    _bioController.text = profile.bio ?? '';
    _headlineController.text = profile.headline ?? '';
    _profileImageUrl = profile.profileImageUrl;

    // Academic info
    if (profile.academicInfo != null) {
      _studentIdController.text = profile.academicInfo!.studentId;
      _programController.text = profile.academicInfo!.program;
      _departmentController.text = profile.academicInfo!.department;
      _facultyController.text = profile.academicInfo!.faculty;
      _currentSemester = profile.academicInfo!.currentSemester;
      _cgpaController.text = profile.academicInfo!.cgpa?.toString() ?? '';
    }

    // Skills and interests
    _selectedSkills = List.from(profile.skills);
    _selectedInterests = List.from(profile.interests);

    // Experiences and projects
    _experiences = List.from(profile.experiences);
    _projects = List.from(profile.projects);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _headlineController.dispose();
    _studentIdController.dispose();
    _programController.dispose();
    _departmentController.dispose();
    _facultyController.dispose();
    _cgpaController.dispose();
    super.dispose();
  }

  /// Get department from selected course
  String _getDepartmentFromCourse(String course) {
    switch (course) {
      case 'Information Technology (BIT)':
        return 'Information Technology';
      case 'Web Technology (BIW)':
        return 'Software Engineering';
      case 'Security (BIS)':
        return 'Information Systems';
      case 'Programming (BIP)':
        return 'Computer Science';
      case 'Multimedia (BIM)':
        return 'Multimedia Technology';
      default:
        return 'Information Technology';
    }
  }

  /// Validate and return valid course value for dropdown
  String? _getValidCourseValue(String currentValue) {
    const validCourses = [
      'Information Technology (BIT)',
      'Web Technology (BIW)',
      'Security (BIS)',
      'Programming (BIP)',
      'Multimedia (BIM)',
    ];

    if (currentValue.isEmpty) return null;
    if (validCourses.contains(currentValue)) return currentValue;

    // Try to match old values to new courses
    final lowerValue = currentValue.toLowerCase();
    if (lowerValue.contains('information technology') ||
        lowerValue.contains('bit')) {
      return 'Information Technology (BIT)';
    } else if (lowerValue.contains('web') || lowerValue.contains('biw')) {
      return 'Web Technology (BIW)';
    } else if (lowerValue.contains('security') || lowerValue.contains('bis')) {
      return 'Security (BIS)';
    } else if (lowerValue.contains('programming') ||
        lowerValue.contains('bip') ||
        lowerValue.contains('computer science') ||
        lowerValue.contains('software')) {
      return 'Programming (BIP)';
    } else if (lowerValue.contains('multimedia') ||
        lowerValue.contains('bim')) {
      return 'Multimedia (BIM)';
    }

    // Default to null if no match (user must select)
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: 'Basic'),
            Tab(icon: Icon(Icons.school), text: 'Academic'),
            Tab(icon: Icon(Icons.star), text: 'Skills & Interests'),
            Tab(icon: Icon(Icons.work), text: 'Experience'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildBasicInfoTab(),
            _buildAcademicInfoTab(),
            _buildSkillsAndInterestsTab(),
            _buildExperienceTab(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image Section
          Center(
            child: _buildProfileImageSection(),
          ),

          const SizedBox(height: AppTheme.spaceLg),

          // Basic Information
          Text(
            'Basic Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppTheme.primaryColor,
                ),
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Full Name Label
          Text(
            'Full Name',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          ModernTextField(
            controller: _fullNameController,
            label: 'Full Name',
            icon: Icons.person,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter full name';
              }
              return null;
            },
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Headline Label
          Text(
            'Headline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          ModernTextField(
            controller: _headlineController,
            label: 'Headline',
            icon: Icons.title,
            hintText: 'e.g., Computer Science Student',
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Phone Number Label
          Text(
            'Phone Number',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          ModernTextField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Address Label
          Text(
            'Address',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          ModernTextField(
            controller: _addressController,
            label: 'Address',
            icon: Icons.location_on,
            maxLines: 2,
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Bio Label
          Text(
            'Bio',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXs),
          ModernTextField(
            controller: _bioController,
            label: 'Bio',
            icon: Icons.description,
            maxLines: 4,
            hintText: 'Tell us about yourself',
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primaryColor,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            CircleAvatar(
              radius: 57,
              backgroundColor: AppTheme.lightGrayColor,
              backgroundImage: _getProfileImageProvider(_profileImageUrl),
              child: _getProfileImageProvider(_profileImageUrl) == null
                  ? const Icon(
                      Icons.person,
                      size: 50,
                      color: AppTheme.grayColor,
                    )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Academic Information',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : AppTheme.primaryColor,
                ),
          ),

          const SizedBox(height: AppTheme.spaceMd),

          ModernTextField(
            controller: _studentIdController,
            label: 'Student ID',
            icon: Icons.badge,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter student ID';
              }
              return null;
            },
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Course/Program Dropdown
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.lightGrayColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school,
                        color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Program / Course',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSm),
                DropdownButtonFormField<String>(
                  initialValue: _getValidCourseValue(_programController.text),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'Information Technology (BIT)',
                      child: Text('Information Technology (BIT)'),
                    ),
                    DropdownMenuItem(
                      value: 'Web Technology (BIW)',
                      child: Text('Web Technology (BIW)'),
                    ),
                    DropdownMenuItem(
                      value: 'Security (BIS)',
                      child: Text('Security (BIS)'),
                    ),
                    DropdownMenuItem(
                      value: 'Programming (BIP)',
                      child: Text('Programming (BIP)'),
                    ),
                    DropdownMenuItem(
                      value: 'Multimedia (BIM)',
                      child: Text('Multimedia (BIM)'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _programController.text = value ?? '';
                      // Auto-set department based on course
                      _departmentController.text =
                          _getDepartmentFromCourse(value ?? '');
                      // Auto-set faculty to FSKTM
                      _facultyController.text =
                          'FSKTM (Fakulti Sains Komputer dan Teknologi Maklumat)';
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Semester Selector
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.3)
                    : AppTheme.lightGrayColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Semester',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black
                            : Colors.black87,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                DropdownButtonFormField<int>(
                  initialValue: _currentSemester,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: List.generate(8, (index) => index + 1)
                      .map((semester) => DropdownMenuItem(
                            value: semester,
                            child: Text('Semester $semester'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _currentSemester = value ?? 1;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spaceMd),

          ModernTextField(
            controller: _cgpaController,
            label: 'CGPA',
            icon: Icons.grade,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsAndInterestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skills Section
          SkillsSelector(
            selectedSkills: _selectedSkills,
            onSkillsChanged: (skills) {
              setState(() {
                _selectedSkills = skills;
              });
            },
          ),

          const SizedBox(height: AppTheme.spaceLg),

          // Interests Section
          InterestsSelector(
            selectedInterests: _selectedInterests,
            onInterestsChanged: (interests) {
              setState(() {
                _selectedInterests = interests;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        children: [
          // Experience Section
          ExperienceEditor(
            experiences: _experiences,
            onExperiencesChanged: (experiences) {
              setState(() {
                _experiences = experiences;
              });
            },
          ),

          const SizedBox(height: AppTheme.spaceLg),

          // Projects Section
          ProjectsEditor(
            projects: _projects,
            onProjectsChanged: (projects) {
              setState(() {
                _projects = projects;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ModernButton(
          text: 'Save Profile',
          onPressed: _isLoading ? null : _saveProfile,
          isLoading: _isLoading,
          icon: Icons.save,
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _isLoading = true;
        });

        try {
          // Upload image to Cloudinary with consistent public_id to overwrite old image
          final cloudinaryUrl = await CloudinaryConfig.uploadImage(
            filePath: image.path,
            userId: widget.profile.userId,
            folder: 'profile_images',
            publicId:
                'profile_${widget.profile.userId}', // Consistent ID for overwrite
            overwrite: true, // Overwrite existing image
          );

          setState(() {
            _profileImageUrl = cloudinaryUrl;
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image selected successfully'),
                backgroundColor: AppTheme.successColor,
              ),
            );
          }
        } catch (uploadError) {
          setState(() {
            _isLoading = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload image: $uploadError'),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error selecting image'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final profileService =
          Provider.of<ProfileService>(context, listen: false);

      // Create academic info
      final academicInfo = AcademicInfoModel(
        studentId: _studentIdController.text.trim(),
        program: _programController.text.trim(),
        department: _departmentController.text.trim(),
        faculty: _facultyController.text.trim(),
        currentSemester: _currentSemester,
        cgpa: double.tryParse(_cgpaController.text.trim()),
        enrollmentDate:
            widget.profile.academicInfo?.enrollmentDate ?? DateTime.now(),
      );

      // Create updated profile
      final updatedProfile = widget.profile.copyWith(
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        bio: _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        headline: _headlineController.text.trim().isEmpty
            ? null
            : _headlineController.text.trim(),
        profileImageUrl: _profileImageUrl,
        academicInfo: academicInfo,
        skills: _selectedSkills,
        interests: _selectedInterests,
        experiences: _experiences,
        projects: _projects,
        updatedAt: DateTime.now(),
      );

      // Save to Firestore
      await profileService.saveProfile(updatedProfile);

      // Clear image cache to force reload of new profile image
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );

        Navigator.pop(context, updatedProfile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
