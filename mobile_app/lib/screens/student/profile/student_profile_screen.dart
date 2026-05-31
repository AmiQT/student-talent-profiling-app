import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../../services/supabase_auth_service.dart';
import '../../../services/profile_service.dart';
import '../../../config/supabase_config.dart';
import '../../../models/profile_model.dart';
import '../../../models/achievement_model.dart';

import '../../../widgets/common/skeleton_widgets.dart';
import 'package:share_plus/share_plus.dart';
import '../achievements/achievements_screen.dart';
import '../../settings/settings_screen.dart';
import '../../auth/comprehensive_profile_setup_screen.dart';
import '../../profile/comprehensive_edit_profile_screen.dart';
// import '../../../models/user_model.dart';
import '../../../widgets/modern/bento_card.dart';
import '../talent/talent_quiz_screen.dart';
import '../talent/talent_quiz_result_screen.dart';

import '../../../utils/app_theme.dart';

class StudentProfileScreen extends StatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  ProfileModel? _profile;
  bool _isLoading = true;
  bool _isUploadingHeader = false;
  // UserRole _userRole = UserRole.student; // Unused

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  ImageProvider _getProfileImage(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      // Return default asset image
      return const AssetImage('assets/images/default_profile.png');
    } else if (imageUrl.startsWith('data:image')) {
      // Handle base64 images
      final base64String = imageUrl.split(',')[1];
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } else if (imageUrl.startsWith('http')) {
      // Handle network images with cache-busting
      final cacheBuster = DateTime.now().millisecondsSinceEpoch;
      final separator = imageUrl.contains('?') ? '&' : '?';
      final urlWithCacheBuster = '$imageUrl${separator}v=$cacheBuster';
      return NetworkImage(urlWithCacheBuster);
    } else if (imageUrl.startsWith('/') || imageUrl.contains('cache')) {
      // Handle local file images
      return FileImage(File(imageUrl));
    } else {
      // Default fallback for invalid URLs
      return const AssetImage('assets/images/default_profile.png');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh profile when returning to this screen
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);
      final profileService =
          Provider.of<ProfileService>(context, listen: false);

      final userId = authService.currentUserId;
      // final userRole = authService.currentUser?.role ?? UserRole.student;
      // debugPrint(
      //     'StudentProfileScreen: User role detected: $userRole'); // Debug
      if (userId != null) {
        final profile = await profileService.getProfileByUserId(userId);
        setState(() {
          _profile = profile;
          // _userRole = userRole;
          _isLoading = false;
        });
        // debugPrint('StudentProfileScreen: Role set to $_userRole'); // Debug
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _migrateProfile() async {
    try {
      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);
      final userId = authService.currentUserId;

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user authenticated')),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Migrating profile...'),
            ],
          ),
        ),
      );

      // Search for profiles with this userId in the data (old structure)
      final oldProfilesQuery =
          await SupabaseConfig.from('profiles').select().eq('userId', userId);

      if (oldProfilesQuery.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No old profile data found to migrate'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Migrate the first profile found
      final doc = oldProfilesQuery.first;
      final data = doc;
      final oldDocId = doc['id'];

      // Delete old document and create new one with userId as document ID
      await SupabaseConfig.from('profiles').delete().eq('id', oldDocId);
      await SupabaseConfig.from('profiles').insert(data);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile migrated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload profile
      _loadProfile();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(height: 60),
              SkeletonProfileHeader(),
              SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    SkeletonPostCard(),
                    SkeletonPostCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_profile == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: theme.appBarTheme.backgroundColor,
          foregroundColor: theme.appBarTheme.foregroundColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.api, color: Colors.orange),
              tooltip: 'Backend Test',
              onPressed: () {
                // Backend test functionality removed - app now uses backend by default
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('App is now using backend APIs!')),
                );
              },
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off,
                  size: 64,
                  color: theme.textTheme.bodyMedium?.color,
                ),
                const SizedBox(height: 16),
                Text(
                  'No profile found',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.headlineMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Your profile may need to be migrated to the new format.',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _migrateProfile,
                  icon: const Icon(Icons.sync),
                  label: const Text('Migrate Profile'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const ComprehensiveProfileSetupScreen(),
                      ),
                    );
                  },
                  child: const Text('Create New Profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final profile = _profile!;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(color: theme.appBarTheme.foregroundColor),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        centerTitle: true,
        elevation: 0.5,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ComprehensiveEditProfileScreen(
                    profile: profile,
                  ),
                ),
              );
              if (result != null && result is ProfileModel) {
                setState(() {
                  _profile = result;
                });
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                        content: Text('Profile updated successfully!')),
                  );
                }
              }
            },
            tooltip: 'Edit Profile',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              _shareProfile(context);
            },
            tooltip: 'Share Profile',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Column(
          children: [
            // 1. Bento Header (Avatar, Name, Edit)
            _buildBentoHeader(profile, theme),

            // 2. Bento Grid Layout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Row 1: Stats & Completeness
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats Card (2/3 width)
                      Expanded(
                        flex: 2,
                        child: BentoCard(
                          title: 'Impact',
                          icon: Icons.insights_rounded,
                          height: 140, // Fixed height for alignment
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildCompactStat(
                                  'Views', '1.2k', Icons.visibility_rounded),
                              _buildVerticalDivider(),
                              _buildCompactStat(
                                  'Likes', '304', Icons.favorite_rounded),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Completeness Card (1/3 width)
                      Expanded(
                        flex: 1,
                        child: BentoCard(
                          height: 140,
                          onTap: () => _navigateToEditProfile(profile),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value:
                                        profile.calculateCompleteness() / 100,
                                    backgroundColor:
                                        theme.brightness == Brightness.dark
                                            ? Colors.white10
                                            : Colors.black12,
                                    color: AppTheme.primaryColor,
                                  ),
                                  Text(
                                    '${profile.calculateCompleteness().toInt()}%',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Profile',
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 2: Bio (Full width)
                  BentoCard(
                    title: 'About Me',
                    icon: Icons.person_outline_rounded,
                    child: Text(
                      profile.bio?.isNotEmpty == true
                          ? profile.bio!
                          : 'Tell us about yourself...',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.8),
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Talent DNA Card
                  BentoCard(
                    title: 'Talent DNA',
                    icon: Icons.auto_awesome,
                    onTap: () async {
                      if (profile.talentProfile?.quizResults != null) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TalentQuizResultScreen(
                              quizResult: profile.talentProfile!.quizResults!,
                            ),
                          ),
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TalentQuizScreen(),
                          ),
                        );
                      }
                      _loadProfile();
                    },
                    child: profile.talentProfile?.quizResults != null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      theme.primaryColor.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Text(
                                  '🏆',
                                  style: TextStyle(fontSize: 24),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                profile.talentProfile!.quizResults!
                                        .primaryTalent ??
                                    'Unknown',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Top Talent',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Discover Your Hidden Talents',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Start Quiz',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(Icons.arrow_forward,
                                        size: 14, color: Colors.white),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),

                  // Row 3: Skills & Academic
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Skills (Flexible)
                      Expanded(
                        child: BentoCard(
                          title: 'Skills',
                          icon: Icons.psychology_outlined,
                          height: 220,
                          onTap: profile.skills.isEmpty
                              ? () => _navigateToEditProfile(profile)
                              : null,
                          child: profile.skills.isNotEmpty
                              ? Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: profile.skills
                                      .take(4)
                                      .map((skill) => Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: theme.primaryColor
                                                  .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                  color: theme.primaryColor
                                                      .withValues(alpha: 0.2)),
                                            ),
                                            child: Text(
                                              skill,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: theme.primaryColor),
                                            ),
                                          ))
                                      .toList(),
                                )
                              : const Center(
                                  child: Icon(Icons.add_circle_outline,
                                      color: Colors.grey),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Academic + Kokurikulum Info Combined (Flexible)
                      Expanded(
                        child: BentoCard(
                          title: 'Academic & Koku',
                          icon: Icons.balance_rounded,
                          height: 220,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Academic vs Koku Scores side by side
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  // Academic Score
                                  Column(
                                    children: [
                                      Icon(Icons.school_rounded,
                                          size: 20, color: Colors.blue[400]),
                                      const SizedBox(height: 4),
                                      Text(
                                        profile.academicInfo?.cgpa
                                                ?.toStringAsFixed(2) ??
                                            '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                      const Text('CGPA',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                  // VS divider
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text('VS',
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey)),
                                  ),
                                  // Kokurikulum Score
                                  Column(
                                    children: [
                                      Icon(Icons.sports_soccer_rounded,
                                          size: 20, color: Colors.green[400]),
                                      const SizedBox(height: 4),
                                      Text(
                                        profile.academicInfo?.kokurikulumScore
                                                ?.toStringAsFixed(0) ??
                                            '-',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                      const Text('Koku',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Balance Status Indicator
                              Builder(
                                builder: (context) {
                                  final balanceMetrics =
                                      profile.academicInfo?.getBalanceMetrics();
                                  final status =
                                      balanceMetrics?['balanceStatus'] ?? 'N/A';
                                  Color statusColor;
                                  IconData statusIcon;

                                  switch (status) {
                                    case 'Seimbang':
                                      statusColor = Colors.green;
                                      statusIcon = Icons.check_circle;
                                      break;
                                    case 'Fokus Akademik':
                                      statusColor = Colors.blue;
                                      statusIcon = Icons.school;
                                      break;
                                    case 'Fokus Kokurikulum':
                                      statusColor = Colors.orange;
                                      statusIcon = Icons.sports;
                                      break;
                                    default:
                                      statusColor = Colors.grey;
                                      statusIcon = Icons.help_outline;
                                  }

                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: statusColor.withValues(
                                              alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(statusIcon,
                                            size: 14, color: statusColor),
                                        const SizedBox(width: 4),
                                        Text(
                                          status,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: statusColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              // Semester & Program info
                              Text(
                                'Sem ${profile.academicInfo?.currentSemester ?? '-'} • ${profile.academicInfo?.program ?? 'Program'}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 9, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 4: Experience & Projects
                  Row(
                    children: [
                      // Experience
                      Expanded(
                        child: BentoCard(
                          title: 'Experience',
                          icon: Icons.work_outline_rounded,
                          height: 140,
                          onTap: () {
                            if (profile.experiences.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ExperienceDetailPage(
                                    experience: profile.experiences
                                        .map((e) => {
                                              'title': e.title,
                                              'desc':
                                                  '${e.company} • ${e.startDate.year} - ${e.isCurrentPosition ? 'Present' : e.endDate?.year ?? ''}'
                                            })
                                        .toList(),
                                  ),
                                ),
                              );
                            } else {
                              // Navigate to edit profile to add experience
                              _navigateToEditProfile(profile);
                            }
                          },
                          child: profile.experiences.isNotEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${profile.experiences.length}',
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const Text('Roles',
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                  ],
                                )
                              : const Center(
                                  child: Icon(Icons.add_circle_outline,
                                      color: Colors.grey),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Projects
                      Expanded(
                        child: BentoCard(
                          title: 'Projects',
                          icon: Icons.rocket_launch_outlined,
                          height: 140,
                          onTap: () {
                            if (profile.projects.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProjectDetailPage(
                                    projects: profile.projects
                                        .map((p) => {
                                              'title': p.title,
                                              'desc': p.description
                                            })
                                        .toList(),
                                  ),
                                ),
                              );
                            } else {
                              // Navigate to edit profile to add projects
                              _navigateToEditProfile(profile);
                            }
                          },
                          child: profile.projects.isNotEmpty
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${profile.projects.length}',
                                      style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const Text('Projects',
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.grey)),
                                  ],
                                )
                              : const Center(
                                  child: Icon(Icons.add_circle_outline,
                                      color: Colors.grey),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Row 5: Badges / Achievements (Full width generic container for now)
                  BentoCard(
                    title: 'Badges & Achievements',
                    icon: Icons.military_tech_outlined,
                    child: SizedBox(
                      height: 60,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: (profile.achievements.take(5).toList())
                            .map((ach) => Padding(
                                  padding: const EdgeInsets.only(right: 12),
                                  child: Tooltip(
                                    message: ach.title,
                                    child: CircleAvatar(
                                      backgroundColor:
                                          Colors.amber.withValues(alpha: 0.2),
                                      child: const Icon(Icons.emoji_events,
                                          color: Colors.amber, size: 20),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Row 5: Contact Info
                  if (profile.phoneNumber != null || profile.email != null)
                    BentoCard(
                      title: 'Contact',
                      icon: Icons.contact_mail_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (profile.phoneNumber != null)
                            _buildContactRow(Icons.phone_iphone_rounded,
                                profile.phoneNumber!),
                          const SizedBox(height: 8),
                          if (profile.email != null)
                            _buildContactRow(
                                Icons.email_outlined, profile.email!),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Helper Methods ---

  Future<void> _navigateToEditProfile(ProfileModel profile) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComprehensiveEditProfileScreen(profile: profile),
      ),
    );
    if (result != null && result is ProfileModel) {
      setState(() {
        _profile = result;
      });
    }
  }

  Future<void> _pickAndUploadHeader() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    if (!mounted) return;
    setState(() => _isUploadingHeader = true);

    try {
      final profileService =
          Provider.of<ProfileService>(context, listen: false);
      final userId = Provider.of<SupabaseAuthService>(context, listen: false)
          .currentUserId;

      if (userId == null || _profile == null) throw Exception('User not found');

      // Read bytes directly from XFile (bypasses dart:io File issues on Windows)
      final bytes = await pickedFile.readAsBytes();
      final fileName = pickedFile.name;

      // Upload image using bytes
      final imageUrl =
          await profileService.uploadHeaderImageBytes(bytes, fileName, userId);

      if (imageUrl != null) {
        // Update profile with new header URL
        final updatedProfile = _profile!.copyWith(backgroundImageUrl: imageUrl);

        // Save profile update
        await profileService.saveProfile(updatedProfile);

        if (mounted) {
          setState(() {
            _profile = updatedProfile;
            _isUploadingHeader = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Header updated successfully!')),
          );
        }
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingHeader = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error updating header: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildBentoHeader(ProfileModel profile, ThemeData theme) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // Background Gradient or Image
              GestureDetector(
                onTap: _pickAndUploadHeader, // Allow tapping to change
                child: Container(
                  height: 170,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    image: profile.backgroundImageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(profile.backgroundImageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    gradient: profile.backgroundImageUrl == null
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.primaryColor.withValues(alpha: 0.8),
                              Colors.purple.shade800,
                            ],
                          )
                        : null,
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30)),
                  ),
                  child: _isUploadingHeader
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : null,
                ),
              ),

              // Edit Header Button (Top Right)
              Positioned(
                top: 16,
                right: 16,
                child: InkWell(
                  onTap: _pickAndUploadHeader,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    child:
                        const Icon(Icons.edit, color: Colors.white, size: 18),
                  ),
                ),
              ),

              // Avatar (Positioned to overlap)
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.scaffoldBackgroundColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _getProfileImage(profile.profileImageUrl),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Name
        Text(
          profile.fullName,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        // Headline
        if (profile.headline != null || profile.academicInfo != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              profile.headline ??
                  '${profile.academicInfo?.program ?? "Student"} @ UTHM',
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactStat(String label, String value, IconData icon,
      {bool isLarge = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isLarge ? 28 : 20, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: isLarge ? 24 : 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
        height: 30, width: 1, color: Colors.grey.withValues(alpha: 0.2));
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    );
  }

  void _shareProfile(BuildContext context) {
    // For demo, just share a string
    Share.share('Check out my profile!');
  }
}

class AboutDetailPage extends StatelessWidget {
  final String about;
  const AboutDetailPage({required this.about, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About Details')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(about, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class ExperienceDetailPage extends StatelessWidget {
  final List<Map<String, String>> experience;
  const ExperienceDetailPage({required this.experience, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Experience Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: experience
            .map((item) => ListTile(
                  title: Text(item['title'] ?? ''),
                  subtitle: Text(item['desc'] ?? ''),
                ))
            .toList(),
      ),
    );
  }
}

class ProjectDetailPage extends StatelessWidget {
  final List<Map<String, String>> projects;
  const ProjectDetailPage({required this.projects, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: projects
            .map((item) => ListTile(
                  title: Text(item['title'] ?? ''),
                  subtitle: Text(item['desc'] ?? ''),
                ))
            .toList(),
      ),
    );
  }
}

class AchievementsDetailPage extends StatelessWidget {
  final List<Map<String, dynamic>> achievements;
  const AchievementsDetailPage({required this.achievements, super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements Details')),
      body: achievements.isEmpty
          ? const Center(
              child: Text(
                'No achievements yet.\nAdd some achievements to showcase your talents!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                final isVerified = achievement['status'] == 'Verified';
                final achievementModel =
                    achievement['achievement'] as AchievementModel?;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                achievement['title'] ?? '',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isVerified ? Colors.green : Colors.orange,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                achievement['status'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          achievement['desc'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${achievement['points'] ?? '0'} points',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber[600],
                              ),
                            ),
                            const Spacer(),
                            if (achievementModel != null && !isVerified)
                              IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const AchievementsScreen(),
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class EditProfilePage extends StatefulWidget {
  final String name;
  final String year;
  final String headline;
  final String about;
  final List<Map<String, String>> experience;
  final List<Map<String, String>> projects;
  final List<Map<String, String>> achievements;
  final double gpa;
  final double coCurriculum;
  final String profileImage;
  const EditProfilePage(
      {required this.name,
      required this.year,
      required this.headline,
      required this.about,
      required this.experience,
      required this.projects,
      required this.achievements,
      required this.gpa,
      required this.coCurriculum,
      required this.profileImage,
      super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late TextEditingController _nameController;
  late TextEditingController _yearController;
  late TextEditingController _headlineController;
  late TextEditingController _aboutController;
  late TextEditingController _gpaController;
  late TextEditingController _coCurriculumController;
  late String _profileImage;
  List<Map<String, String>> _experience = [];
  List<Map<String, String>> _projects = [];
  List<Map<String, String>> _achievements = [];
  final ImagePicker _picker = ImagePicker();
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.name);
    _yearController = TextEditingController(text: widget.year);
    _headlineController = TextEditingController(text: widget.headline);
    _aboutController = TextEditingController(text: widget.about);
    _gpaController = TextEditingController(text: widget.gpa.toString());
    _coCurriculumController =
        TextEditingController(text: widget.coCurriculum.toString());
    _profileImage = widget.profileImage;
    _experience = List<Map<String, String>>.from(widget.experience);
    _projects = List<Map<String, String>>.from(widget.projects);
    _achievements = List<Map<String, String>>.from(widget.achievements);
  }

  ImageProvider _getEditProfileImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return const AssetImage('assets/images/default_profile.png');
    } else if (imageUrl.startsWith('data:image')) {
      // Handle base64 images
      final base64String = imageUrl.split(',')[1];
      final bytes = base64Decode(base64String);
      return MemoryImage(bytes);
    } else if (imageUrl.startsWith('http')) {
      // Handle network images
      return NetworkImage(imageUrl);
    } else if (imageUrl.startsWith('/') || imageUrl.contains('cache')) {
      // Handle local file images
      return FileImage(File(imageUrl));
    } else {
      // Default fallback
      return const AssetImage('assets/images/default_profile.png');
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (image != null) {
      try {
        debugPrint('ProfileScreen: Image picked from path: ${image.path}');

        // Convert image to base64 for free storage
        final bytes = await image.readAsBytes();
        final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';

        debugPrint(
            'ProfileScreen: Image converted to base64, length: ${base64String.length}');

        setState(() {
          _profileImage = base64String;
        });

        debugPrint('ProfileScreen: Profile image updated successfully');
      } catch (e) {
        debugPrint('ProfileScreen: Error processing image: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error processing image: $e')),
          );
        }
      }
    }
  }

  void _editList(List<Map<String, String>> list, String title,
      Function(List<Map<String, String>>) onSave) {
    TextEditingController titleController = TextEditingController();
    TextEditingController descController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('Add $title',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                    TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: 'Title')),
                    TextField(
                        controller: descController,
                        decoration:
                            const InputDecoration(labelText: 'Description')),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        if (titleController.text.isNotEmpty) {
                          setState(() {
                            list.add({
                              'title': titleController.text,
                              'desc': descController.text
                            });
                          });
                          onSave(list);
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: _getEditProfileImage(_profileImage),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 20, color: Colors.blue),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: _yearController,
                decoration: const InputDecoration(labelText: 'Year')),
            TextField(
                controller: _headlineController,
                decoration: const InputDecoration(labelText: 'Headline')),
            TextField(
                controller: _aboutController,
                decoration: const InputDecoration(labelText: 'About'),
                maxLines: 3),
            TextField(
                controller: _gpaController,
                decoration: const InputDecoration(labelText: 'GPA'),
                keyboardType: TextInputType.number),
            TextField(
                controller: _coCurriculumController,
                decoration: const InputDecoration(labelText: 'Co-curriculum'),
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Experience',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _editList(_experience, 'Experience',
                        (list) => setState(() => _experience = list))),
              ],
            ),
            ..._experience.map((item) => ListTile(
                title: Text(item['title'] ?? ''),
                subtitle: Text(item['desc'] ?? ''))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Projects',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _editList(_projects, 'Project',
                        (list) => setState(() => _projects = list))),
              ],
            ),
            ..._projects.map((item) => ListTile(
                title: Text(item['title'] ?? ''),
                subtitle: Text(item['desc'] ?? ''))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Achievements',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () => _editList(_achievements, 'Achievement',
                        (list) => setState(() => _achievements = list))),
              ],
            ),
            ..._achievements.map((item) => ListTile(
                title: Text(item['title'] ?? ''),
                subtitle: Text(item['desc'] ?? ''))),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'name': _nameController.text,
                  'year': _yearController.text,
                  'headline': _headlineController.text,
                  'about': _aboutController.text,
                  'experience': _experience,
                  'projects': _projects,
                  'achievements': _achievements,
                  'gpa': double.tryParse(_gpaController.text) ?? 0.0,
                  'coCurriculum':
                      double.tryParse(_coCurriculumController.text) ?? 0.0,
                  'profileImage': _profileImage,
                });
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class MetricDetailPage extends StatelessWidget {
  const MetricDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance Metric Details')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How is your performance measured?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 12),
            Text(
                'Your performance metric is a combination of your GPA (60%) and your co-curriculum score (40%).',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 12),
            Text(
                'A balanced GPA and active co-curriculum participation will result in a higher performance score.',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 12),
            Text(
                'GPA is measured out of 4.00.\nCo-curriculum is measured out of 100.\nThe final score is calculated as:\n\nPerformance = (GPA / 4.0) * 0.6 + (Co-curriculum / 100) * 0.4',
                style: TextStyle(fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
