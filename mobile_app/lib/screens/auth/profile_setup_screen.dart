import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/profile_service.dart';
import '../../models/user_model.dart';
import '../../models/profile_model.dart';
import '../../models/academic_info_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../student/student_dashboard.dart';
import '../student/enhanced_student_dashboard.dart';
import '../lecturer/lecturer_dashboard.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();

  String _selectedDepartment = '';
  String _selectedProgram = '';
  int _selectedSemester = 1;
  final List<String> _selectedSkills = [];
  final List<String> _selectedInterests = [];

  bool _isLoading = false;
  UserModel? _currentUser;

  final List<String> _departments = [
    'Computer Science',
    'Information Technology',
    'Software Engineering',
    'Data Science',
    'Cybersecurity',
    'Artificial Intelligence',
  ];

  final List<String> _programs = [
    'Bachelor of Computer Science',
    'Bachelor of Information Technology',
    'Bachelor of Software Engineering',
    'Bachelor of Data Science',
    'Bachelor of Cybersecurity',
    'Bachelor of Artificial Intelligence',
  ];

  final List<String> _availableSkills = [
    'Flutter',
    'Dart',
    'Firebase',
    'UI/UX Design',
    'JavaScript',
    'Python',
    'Java',
    'C++',
    'React',
    'Node.js',
    'MongoDB',
    'MySQL',
    'Git',
    'Docker',
    'AWS',
    'Machine Learning',
    'Data Analysis',
    'Web Development',
    'Mobile Development',
  ];

  final List<String> _availableInterests = [
    'Mobile Development',
    'Web Development',
    'AI/ML',
    'Data Science',
    'Cybersecurity',
    'Cloud Computing',
    'Game Development',
    'UI/UX',
    'DevOps',
    'Blockchain',
    'IoT',
    'Computer Vision',
    'NLP',
    'Software Engineering',
    'Database Management',
    'Networking',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _studentIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);
    _currentUser = authService.currentUser;

    if (_currentUser != null) {
      _fullNameController.text = _currentUser!.name;
      _studentIdController.text = _currentUser!.studentId ?? '';
    }
  }

  void _addSkill(String skill) {
    if (!_selectedSkills.contains(skill)) {
      setState(() {
        _selectedSkills.add(skill);
      });
    }
  }

  void _removeSkill(String skill) {
    setState(() {
      _selectedSkills.remove(skill);
    });
  }

  void _addInterest(String interest) {
    if (!_selectedInterests.contains(interest)) {
      setState(() {
        _selectedInterests.add(interest);
      });
    }
  }

  void _removeInterest(String interest) {
    setState(() {
      _selectedInterests.remove(interest);
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);
      final profileService =
          Provider.of<ProfileService>(context, listen: false);

      final user = authService.currentUser;
      if (user == null) {
        throw Exception('User not found');
      }

      // Create academic info
      final academicInfo = AcademicInfoModel(
        studentId: _studentIdController.text.trim(),
        program: _selectedProgram,
        department: _selectedDepartment,
        faculty:
            'Faculty of Computer Science and Information Technology', // Default
        currentSemester: _selectedSemester,
        enrollmentDate: DateTime.now(),
      );

      // Create profile model
      final profile = ProfileModel(
        id: 'profile_${user.uid}',
        userId: user.uid,
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
        profileImageUrl: '',
        academicInfo: academicInfo,
        skills: _selectedSkills,
        interests: _selectedInterests,
        isProfileComplete: true,
        completedSections: ['basic', 'academic'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save profile to Firestore
      await profileService.saveProfile(profile);

      // Update user profile completion status
      await authService.updateUserProfile({
        'profileCompleted': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Navigate to appropriate dashboard based on role
      if (mounted) {
        _navigateToDashboard(user.role);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToDashboard(UserRole role) {
    Widget dashboard;
    switch (role) {
      case UserRole.student:
        dashboard = const StudentDashboard();
        break;
      case UserRole.lecturer:
        dashboard = const LecturerDashboard();
        break;
      case UserRole.admin:
        // Admin uses same interface as students
        dashboard = const EnhancedStudentDashboard();
        break;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => dashboard),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Message
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.person_add,
                        color: Colors.blue.shade600,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Welcome to UTHM Talent Profiling!',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please complete your profile to get started with showcasing your talents and achievements.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Personal Information Section
                _buildSectionTitle('Personal Information'),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _fullNameController,
                  labelText: 'Full Name',
                  hintText: 'Enter your full name',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                if (_currentUser?.role == UserRole.student) ...[
                  CustomTextField(
                    controller: _studentIdController,
                    labelText: 'Student ID',
                    hintText: 'Enter your student ID (e.g., A123456)',
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your student ID';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Department and Program
                DropdownButtonFormField<String>(
                  initialValue: _selectedDepartment.isNotEmpty
                      ? _selectedDepartment
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Department *',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: _departments.map((dept) {
                    return DropdownMenuItem(
                      value: dept,
                      child: Text(dept),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedDepartment = value ?? '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your department';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                DropdownButtonFormField<String>(
                  initialValue: _selectedProgram.isNotEmpty ? _selectedProgram : null,
                  decoration: const InputDecoration(
                    labelText: 'Program *',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: _programs.map((program) {
                    return DropdownMenuItem(
                      value: program,
                      child: Text(program),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProgram = value ?? '';
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your program';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                if (_currentUser?.role == UserRole.student) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _selectedSemester,
                    decoration: const InputDecoration(
                      labelText: 'Current Semester *',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items:
                        List.generate(8, (index) => index + 1).map((semester) {
                      return DropdownMenuItem(
                        value: semester,
                        child: Text('Semester $semester'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSemester = value ?? 1;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Contact Information
                _buildSectionTitle('Contact Information'),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _phoneController,
                  labelText: 'Phone Number',
                  hintText: 'Enter your phone number',
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _addressController,
                  labelText: 'Address',
                  hintText: 'Enter your address',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                CustomTextField(
                  controller: _bioController,
                  labelText: 'Bio',
                  hintText: 'Tell us about yourself...',
                  maxLines: 3,
                ),
                const SizedBox(height: 24),

                // Skills Section
                _buildSectionTitle('Skills'),
                const SizedBox(height: 16),

                _buildChipSelector(
                  title: 'Select your skills',
                  selectedItems: _selectedSkills,
                  availableItems: _availableSkills,
                  onAdd: _addSkill,
                  onRemove: _removeSkill,
                ),
                const SizedBox(height: 24),

                // Interests Section
                _buildSectionTitle('Interests'),
                const SizedBox(height: 16),

                _buildChipSelector(
                  title: 'Select your interests',
                  selectedItems: _selectedInterests,
                  availableItems: _availableInterests,
                  onAdd: _addInterest,
                  onRemove: _removeInterest,
                ),
                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: CustomButton(
                    text: _isLoading ? 'Saving Profile...' : 'Complete Profile',
                    onPressed: _isLoading ? null : _saveProfile,
                    isLoading: _isLoading,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildChipSelector({
    required String title,
    required List<String> selectedItems,
    required List<String> availableItems,
    required Function(String) onAdd,
    required Function(String) onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),

        // Selected items
        if (selectedItems.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedItems.map((item) {
              return Chip(
                label: Text(item),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => onRemove(item),
                backgroundColor: Colors.blue.shade100,
                deleteIconColor: Colors.blue.shade700,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],

        // Available items
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Available ${title.toLowerCase()}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: availableItems
                    .where((item) => !selectedItems.contains(item))
                    .map((item) {
                  return ActionChip(
                    label: Text(
                      item,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => onAdd(item),
                    backgroundColor: Colors.grey.shade100,
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
