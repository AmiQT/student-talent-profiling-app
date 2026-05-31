import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/profile_service.dart';
import '../../models/user_model.dart';
import '../../models/profile_model.dart';
import '../../models/academic_info_model.dart';
import '../../models/experience_model.dart';
import '../../models/project_model.dart';
import '../student/enhanced_student_dashboard.dart';
import '../lecturer/lecturer_dashboard.dart';

class ComprehensiveProfileSetupScreen extends StatefulWidget {
  const ComprehensiveProfileSetupScreen({super.key});

  @override
  State<ComprehensiveProfileSetupScreen> createState() =>
      _ComprehensiveProfileSetupScreenState();
}

class _ComprehensiveProfileSetupScreenState
    extends State<ComprehensiveProfileSetupScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form keys for each step
  final List<GlobalKey<FormState>> _formKeys =
      List.generate(6, (index) => GlobalKey<FormState>());

  // Controllers for basic information
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();

  // Academic information controllers
  final _studentIdController = TextEditingController();
  final _cgpaController = TextEditingController();
  final _totalCreditsController = TextEditingController();
  final _completedCreditsController = TextEditingController();
  final _specializationController = TextEditingController();

  // Selected values
  String _selectedDepartment = '';
  String _selectedProgram = '';
  String _selectedFaculty = 'FSKTM (Fakulti Sains Komputer dan Teknologi Maklumat)';
  String _selectedCourse = '';
  int _selectedSemester = 1;
  DateTime? _enrollmentDate;
  DateTime? _expectedGraduation;

  // Skills and interests
  final List<String> _selectedSkills = [];
  final List<String> _selectedInterests = [];
  final List<String> _selectedMinors = [];

  // Experience and projects
  final List<ExperienceModel> _experiences = [];
  final List<ProjectModel> _projects = [];

  UserModel? _currentUser;
  String? _existingProfileId; // Track existing profile ID for updates

  final List<String> _steps = [
    'Basic Info',
    'Academic Info',
    'Skills',
    'Interests',
    'Experience',
    'Projects'
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);
    setState(() {
      _currentUser = authService.currentUser;
    });

    // Load existing profile data if available
    if (_currentUser != null) {
      await _loadExistingProfile();
    }
  }

  Future<void> _loadExistingProfile() async {
    try {
      final profileService =
          Provider.of<ProfileService>(context, listen: false);
      final existingProfile =
          await profileService.getProfileByUserId(_currentUser!.uid);

      if (existingProfile != null) {
        debugPrint('ComprehensiveProfileSetup: Loading existing profile data');
        setState(() {
          // Load basic information
          _fullNameController.text = existingProfile.fullName;
          _phoneController.text = existingProfile.phoneNumber ?? '';
          _addressController.text = existingProfile.address ?? '';
          _bioController.text = existingProfile.bio ?? '';

          // Load academic information
          if (existingProfile.academicInfo != null) {
            _studentIdController.text = existingProfile.academicInfo!.studentId;
            _selectedFaculty = 'FSKTM (Fakulti Sains Komputer dan Teknologi Maklumat)';
            _selectedCourse = existingProfile.academicInfo!.program;
            _selectedDepartment = existingProfile.academicInfo!.department;
            _selectedProgram = existingProfile.academicInfo!.program;
            _selectedSemester = existingProfile.academicInfo!.currentSemester;
            _cgpaController.text =
                existingProfile.academicInfo!.cgpa?.toString() ?? '';
            _totalCreditsController.text =
                existingProfile.academicInfo!.totalCredits?.toString() ?? '';
            _completedCreditsController.text =
                existingProfile.academicInfo!.completedCredits?.toString() ??
                    '';
            _specializationController.text =
                existingProfile.academicInfo!.specialization ?? '';
            _enrollmentDate = existingProfile.academicInfo!.enrollmentDate;
            _expectedGraduation =
                existingProfile.academicInfo!.expectedGraduation;
          }

          // Load skills and interests
          _selectedSkills.clear();
          _selectedSkills.addAll(existingProfile.skills);
          _selectedInterests.clear();
          _selectedInterests.addAll(existingProfile.interests);

          // Load experiences and projects
          _experiences.clear();
          _experiences.addAll(existingProfile.experiences);
          _projects.clear();
          _projects.addAll(existingProfile.projects);

          // Store existing profile ID for updates
          _existingProfileId = existingProfile.id;
        });
        debugPrint(
            'ComprehensiveProfileSetup: Existing profile data loaded successfully');
      } else {
        debugPrint(
            'ComprehensiveProfileSetup: No existing profile found, starting fresh');
      }
    } catch (e) {
      debugPrint(
          'ComprehensiveProfileSetup: Error loading existing profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _steps.asMap().entries.map((entry) {
                    int index = entry.key;
                    String step = entry.value;
                    bool isActive = index == _currentStep;
                    bool isCompleted = index < _currentStep;

                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isCompleted
                                  ? Colors.green
                                  : isActive
                                      ? Colors.blue
                                      : Colors.grey[300],
                            ),
                            child: Center(
                              child: isCompleted
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 16)
                                  : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: isActive
                                            ? Colors.white
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            step,
                            style: TextStyle(
                              fontSize: 10,
                              color: isActive ? Colors.blue : Colors.grey[600],
                              fontWeight: isActive
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (_currentStep + 1) / _steps.length,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[800]!),
                ),
              ],
            ),
          ),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              children: [
                _buildBasicInfoStep(),
                _buildAcademicInfoStep(),
                _buildSkillsStep(),
                _buildInterestsStep(),
                _buildExperienceStep(),
                _buildProjectsStep(),
              ],
            ),
          ),

          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_currentStep == _steps.length - 1
                            ? 'Complete Profile'
                            : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeys[0],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Basic Information',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Let\'s start with your basic information',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bioController,
              decoration: const InputDecoration(
                labelText: 'Bio / About Yourself',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.info),
                hintText:
                    'Tell us about yourself, your goals, and aspirations...',
              ),
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcademicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: IntrinsicHeight(
        child: Form(
          key: _formKeys[1],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Academic Information',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your academic details and current status',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Student ID
              TextFormField(
                controller: _studentIdController,
                decoration: const InputDecoration(
                  labelText: 'Student ID *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                  hintText: 'e.g., CI2330060',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your student ID';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Course dropdown (FSKTM courses only)
              DropdownButtonFormField<String>(
                initialValue: _selectedCourse.isEmpty ? null : _selectedCourse,
                decoration: const InputDecoration(
                  labelText: 'Program / Course *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                isExpanded: true,
                menuMaxHeight: 300,
                items: const [
                  DropdownMenuItem(
                    value: 'Information Technology (BIT)',
                    child: Text(
                      'Information Technology (BIT)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Web Technology (BIW)',
                    child: Text(
                      'Web Technology (BIW)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Security (BIS)',
                    child: Text(
                      'Security (BIS)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Programming (BIP)',
                    child: Text(
                      'Programming (BIP)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Multimedia (BIM)',
                    child: Text(
                      'Multimedia (BIM)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedCourse = value ?? '';
                    // Auto-set program and department based on course
                    _selectedProgram = value ?? '';
                    _selectedDepartment = _getDepartmentFromCourse(value ?? '');
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Sila pilih program anda';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Current Semester
              SizedBox(
                width: double.infinity,
                child: DropdownButtonFormField<int>(
                  initialValue: _selectedSemester,
                  decoration: const InputDecoration(
                    labelText: 'Current Semester *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.timeline),
                  ),
                  isExpanded: true,
                  items: List.generate(8, (index) => index + 1)
                      .map((semester) => DropdownMenuItem(
                            value: semester,
                            child: Text('Semester $semester'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSemester = value ?? 1;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select your current semester';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // CGPA (Optional)
              TextFormField(
                controller: _cgpaController,
                decoration: const InputDecoration(
                  labelText: 'CGPA (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.grade),
                  hintText: 'e.g., 3.75',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),

              // Total Credits
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalCreditsController,
                      decoration: const InputDecoration(
                        labelText: 'Total Credits',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _completedCreditsController,
                      decoration: const InputDecoration(
                        labelText: 'Completed Credits',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.assignment_turned_in),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Specialization
              TextFormField(
                controller: _specializationController,
                decoration: const InputDecoration(
                  labelText: 'Specialization (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.star),
                  hintText: 'e.g., Artificial Intelligence, Web Development',
                ),
              ),
              const SizedBox(height: 16),

              // Enrollment Date
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _enrollmentDate ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) {
                    setState(() {
                      _enrollmentDate = date;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Enrollment Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _enrollmentDate != null
                        ? '${_enrollmentDate!.day}/${_enrollmentDate!.month}/${_enrollmentDate!.year}'
                        : 'Select enrollment date',
                    style: TextStyle(
                      color: _enrollmentDate != null
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Expected Graduation
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _expectedGraduation ??
                        DateTime.now().add(const Duration(days: 365 * 2)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) {
                    setState(() {
                      _expectedGraduation = date;
                    });
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expected Graduation (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                  child: Text(
                    _expectedGraduation != null
                        ? '${_expectedGraduation!.day}/${_expectedGraduation!.month}/${_expectedGraduation!.year}'
                        : 'Select expected graduation date',
                    style: TextStyle(
                      color: _expectedGraduation != null
                          ? Colors.black
                          : Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

  Widget _buildSkillsStep() {
    final availableSkills = [
      'Flutter',
      'Dart',
      'Java',
      'Python',
      'JavaScript',
      'TypeScript',
      'React',
      'Angular',
      'Vue.js',
      'Node.js',
      'Express.js',
      'MongoDB',
      'MySQL',
      'PostgreSQL',
      'Firebase',
      'AWS',
      'Docker',
      'Kubernetes',
      'Git',
      'GitHub',
      'GitLab',
      'Figma',
      'Adobe XD',
      'Photoshop',
      'Machine Learning',
      'Data Science',
      'AI',
      'Deep Learning',
      'Cybersecurity',
      'Network Security',
      'Web Security',
      'Mobile Development',
      'Web Development',
      'Backend Development',
      'Frontend Development',
      'Full Stack Development',
      'DevOps',
      'UI/UX Design',
      'Graphic Design',
      'Project Management',
      'Agile',
      'Scrum',
      'Leadership',
      'Communication',
      'Problem Solving'
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeys[2],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Skills & Technologies',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select your skills and technologies you\'re proficient in',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'Selected Skills:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_selectedSkills.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No skills selected yet. Choose from the options below.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedSkills
                    .map((skill) => Chip(
                          label: Text(skill),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _selectedSkills.remove(skill);
                            });
                          },
                          backgroundColor: Colors.blue[100],
                        ))
                    .toList(),
              ),
            const SizedBox(height: 24),
            const Text(
              'Available Skills:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableSkills
                  .where((skill) => !_selectedSkills.contains(skill))
                  .map((skill) => ActionChip(
                        label: Text(skill),
                        onPressed: () {
                          setState(() {
                            _selectedSkills.add(skill);
                          });
                        },
                        backgroundColor: Colors.grey[200],
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Add Custom Skill:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Custom skill',
                      border: OutlineInputBorder(),
                      hintText: 'Enter a skill not listed above',
                    ),
                    onFieldSubmitted: (value) {
                      if (value.trim().isNotEmpty &&
                          !_selectedSkills.contains(value.trim())) {
                        setState(() {
                          _selectedSkills.add(value.trim());
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    // Add custom skill logic handled by onFieldSubmitted
                  },
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestsStep() {
    final availableInterests = [
      'Web Development',
      'Mobile App Development',
      'Game Development',
      'Artificial Intelligence',
      'Machine Learning',
      'Data Science',
      'Cybersecurity',
      'Cloud Computing',
      'DevOps',
      'Blockchain',
      'Internet of Things (IoT)',
      'Augmented Reality',
      'Virtual Reality',
      'UI/UX Design',
      'Graphic Design',
      'Digital Marketing',
      'Project Management',
      'Entrepreneurship',
      'Startup',
      'Open Source',
      'Research',
      'Teaching',
      'Mentoring',
      'Competitive Programming',
      'Hackathons',
      'Tech Conferences',
      'Photography',
      'Video Editing',
      'Content Creation',
      'Music',
      'Sports',
      'Travel',
      'Reading',
      'Writing',
      'Volunteering',
      'Community Service',
      'Environmental Conservation'
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeys[3],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interests & Hobbies',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'What are you passionate about? Select your interests and hobbies',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'Selected Interests:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_selectedInterests.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No interests selected yet. Choose from the options below.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedInterests
                    .map((interest) => Chip(
                          label: Text(interest),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _selectedInterests.remove(interest);
                            });
                          },
                          backgroundColor: Colors.green[100],
                        ))
                    .toList(),
              ),
            const SizedBox(height: 24),
            const Text(
              'Available Interests:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: availableInterests
                  .where((interest) => !_selectedInterests.contains(interest))
                  .map((interest) => ActionChip(
                        label: Text(interest),
                        onPressed: () {
                          setState(() {
                            _selectedInterests.add(interest);
                          });
                        },
                        backgroundColor: Colors.grey[200],
                      ))
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Add Custom Interest:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Custom interest',
                      border: OutlineInputBorder(),
                      hintText: 'Enter an interest not listed above',
                    ),
                    onFieldSubmitted: (value) {
                      if (value.trim().isNotEmpty &&
                          !_selectedInterests.contains(value.trim())) {
                        setState(() {
                          _selectedInterests.add(value.trim());
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    // Add custom interest logic handled by onFieldSubmitted
                  },
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExperienceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeys[4],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Work Experience',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your work experience, internships, or part-time jobs (Optional)',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_experiences.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.work_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No experience added yet',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You can skip this step and add experience later from your profile.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _experiences
                    .map((exp) => Card(
                          child: ListTile(
                            title: Text(exp.title),
                            subtitle: Text(exp.company),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  _experiences.remove(exp);
                                });
                              },
                            ),
                          ),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _showAddExperienceDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Experience'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKeys[5],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Projects & Portfolio',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Showcase your projects, assignments, or personal work (Optional)',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            if (_projects.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.folder_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No projects added yet',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You can skip this step and add projects later from your profile.',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Column(
                children: _projects
                    .map((project) => Card(
                          child: ListTile(
                            title: Text(project.title),
                            subtitle: Text(project.description),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  _projects.remove(project);
                                });
                              },
                            ),
                          ),
                        ))
                    .toList(),
              ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () => _showAddProjectDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Add Project'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      if (_formKeys[_currentStep].currentState?.validate() ?? false) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _completeProfile();
    }
  }

  Future<void> _completeProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_currentUser == null) {
        throw Exception('User not found');
      }

      // Create academic info
      final academicInfo = AcademicInfoModel(
        studentId: _studentIdController.text.trim(),
        program: _selectedProgram,
        department: _selectedDepartment,
        faculty: _selectedFaculty,
        currentSemester: _selectedSemester,
        cgpa: _cgpaController.text.trim().isEmpty
            ? null
            : double.tryParse(_cgpaController.text.trim()),
        totalCredits: _totalCreditsController.text.trim().isEmpty
            ? null
            : int.tryParse(_totalCreditsController.text.trim()),
        completedCredits: _completedCreditsController.text.trim().isEmpty
            ? null
            : int.tryParse(_completedCreditsController.text.trim()),
        enrollmentDate: _enrollmentDate ?? DateTime.now(),
        expectedGraduation: _expectedGraduation,
        specialization: _specializationController.text.trim().isEmpty
            ? null
            : _specializationController.text.trim(),
        minors: _selectedMinors,
      );

      // Get services first
      final profileService =
          Provider.of<ProfileService>(context, listen: false);
      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);

      // Create or update profile
      final profileId = _existingProfileId ?? 'profile_${_currentUser!.uid}';
      final now = DateTime.now();

      // Get creation date for existing profiles
      DateTime createdAt = now;
      if (_existingProfileId != null) {
        final existingProfile =
            await profileService.getProfileByUserId(_currentUser!.uid);
        createdAt = existingProfile?.createdAt ?? now;
      }

      final profile = ProfileModel(
        id: profileId,
        userId: _currentUser!.uid,
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
        academicInfo: academicInfo,
        skills: _selectedSkills,
        interests: _selectedInterests,
        experiences: _experiences,
        projects: _projects,
        isProfileComplete: true,
        completedSections: [
          'basic',
          'academic',
          'skills',
          'interests',
          'experience',
          'projects'
        ],
        createdAt: createdAt,
        updatedAt: now,
      );

      // Save profile

      await profileService.saveProfile(profile);

      // Update user profile completion status
      await authService.updateUserProfile({
        'profileCompleted': true,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      // Navigate to appropriate dashboard
      _navigateToDashboard(_currentUser!.role);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: ${e.toString()}'),
            backgroundColor: Colors.red,
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

  void _navigateToDashboard(UserRole role) {
    Widget dashboard;
    switch (role) {
      case UserRole.admin:
        // Admin uses same interface as students
        dashboard = const EnhancedStudentDashboard();
        break;
      case UserRole.lecturer:
        dashboard = const LecturerDashboard();
        break;
      case UserRole.student:
        dashboard = const EnhancedStudentDashboard();
        break;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => dashboard),
      (route) => false,
    );
  }

  // Show Add Experience Dialog
  void _showAddExperienceDialog() {
    final titleController = TextEditingController();
    final companyController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool isCurrentPosition = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Experience'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Job Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: companyController,
                  decoration: const InputDecoration(
                    labelText: 'Company *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Current Position'),
                  value: isCurrentPosition,
                  onChanged: (value) {
                    setState(() {
                      isCurrentPosition = value ?? false;
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
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty &&
                    companyController.text.trim().isNotEmpty) {
                  final experience = ExperienceModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    company: companyController.text.trim(),
                    description: descriptionController.text.trim(),
                    startDate: startDate ?? DateTime.now(),
                    endDate: isCurrentPosition ? null : endDate,
                    isCurrentPosition: isCurrentPosition,
                    location: locationController.text.trim().isEmpty
                        ? null
                        : locationController.text.trim(),
                    skills: [],
                  );

                  this.setState(() {
                    _experiences.add(experience);
                  });

                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  // Show Add Project Dialog
  void _showAddProjectDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final projectUrlController = TextEditingController();
    final githubUrlController = TextEditingController();
    final categoryController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool isOngoing = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Project Title *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., Web App, Mobile App, AI/ML',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: projectUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Project URL',
                    border: OutlineInputBorder(),
                    hintText: 'https://...',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: githubUrlController,
                  decoration: const InputDecoration(
                    labelText: 'GitHub URL',
                    border: OutlineInputBorder(),
                    hintText: 'https://github.com/...',
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Ongoing Project'),
                  value: isOngoing,
                  onChanged: (value) {
                    setState(() {
                      isOngoing = value ?? false;
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
            ElevatedButton(
              onPressed: () {
                if (titleController.text.trim().isNotEmpty &&
                    descriptionController.text.trim().isNotEmpty) {
                  final project = ProjectModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    startDate: startDate ?? DateTime.now(),
                    endDate: isOngoing ? null : endDate,
                    isOngoing: isOngoing,
                    projectUrl: projectUrlController.text.trim().isEmpty
                        ? null
                        : projectUrlController.text.trim(),
                    githubUrl: githubUrlController.text.trim().isEmpty
                        ? null
                        : githubUrlController.text.trim(),
                    category: categoryController.text.trim().isEmpty
                        ? null
                        : categoryController.text.trim(),
                    technologies: [],
                    images: [],
                  );

                  this.setState(() {
                    _projects.add(project);
                  });

                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    _studentIdController.dispose();
    _cgpaController.dispose();
    _totalCreditsController.dispose();
    _completedCreditsController.dispose();
    _specializationController.dispose();
    super.dispose();
  }
}
