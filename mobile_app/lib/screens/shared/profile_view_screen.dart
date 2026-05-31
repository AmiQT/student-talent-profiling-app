import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/profile_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../models/profile_model.dart';
import '../../models/user_model.dart';
import '../../models/search_models.dart';
import '../../utils/app_theme.dart';
import '../auth/comprehensive_profile_setup_screen.dart';

class ProfileViewScreen extends StatefulWidget {
  final String userId;
  final bool isViewOnly;
  final SearchResult? searchResult; // Optional: if coming from search

  const ProfileViewScreen({
    super.key,
    required this.userId,
    this.isViewOnly = true,
    this.searchResult,
  });

  @override
  State<ProfileViewScreen> createState() => _ProfileViewScreenState();
}

class _ProfileViewScreenState extends State<ProfileViewScreen> {
  ProfileModel? _profile;
  UserModel? _user;
  bool _isLoading = true;
  bool _isCurrentUser = false;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      debugPrint(
          'ProfileViewScreen: Loading profile data for userId: ${widget.userId}');

      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);
      final profileService =
          Provider.of<ProfileService>(context, listen: false);

      // Check if this is the current user's profile
      _isCurrentUser = authService.currentUserId == widget.userId;
      debugPrint('ProfileViewScreen: Is current user: $_isCurrentUser');

      // Load user data first
      UserModel? user;
      if (widget.searchResult != null) {
        user = widget.searchResult!.user;
        debugPrint(
            'ProfileViewScreen: Using user from search result: ${user.name}');
      } else {
        debugPrint('ProfileViewScreen: Fetching user data from auth service');
        user = await authService.getUserData(widget.userId);
      }

      debugPrint('ProfileViewScreen: User loaded: ${user?.name ?? 'null'}');

      // Load profile data
      ProfileModel? profile;
      try {
        debugPrint('ProfileViewScreen: Attempting to load profile');
        profile = await profileService.getProfileByUserId(widget.userId);
        debugPrint(
            'ProfileViewScreen: Profile loaded: ${profile?.fullName ?? 'null'}');

        // Additional debugging - check if profile from search result exists
        if (widget.searchResult?.profile != null) {
          debugPrint(
              'ProfileViewScreen: Search result has profile: ${widget.searchResult!.profile!.fullName}');
          debugPrint(
              'ProfileViewScreen: Search profile userId: ${widget.searchResult!.profile!.userId}');
          debugPrint('ProfileViewScreen: Current userId: ${widget.userId}');

          // If we have a profile from search but not from service, there might be a sync issue
          if (profile == null) {
            debugPrint(
                'ProfileViewScreen: WARNING - Search has profile but service doesn\'t find it!');
            debugPrint(
                'ProfileViewScreen: Using profile from search result as fallback');
            profile = widget.searchResult!.profile;
          }
        }
      } catch (e) {
        debugPrint('ProfileViewScreen: Error loading profile: $e');
        // Profile might not exist yet, that's okay
        profile = null;

        // Check if we can use profile from search result as fallback
        if (widget.searchResult?.profile != null) {
          debugPrint(
              'ProfileViewScreen: Using profile from search result as fallback after error');
          profile = widget.searchResult!.profile;
        }
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _user = user;
          _isLoading = false;
        });
        debugPrint(
            'ProfileViewScreen: State updated - Profile: ${_profile != null}, User: ${_user != null}');
      }
    } catch (e) {
      debugPrint('ProfileViewScreen: Error in _loadProfileData: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
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
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Profile'),
          backgroundColor: theme.appBarTheme.backgroundColor,
          foregroundColor: theme.appBarTheme.foregroundColor,
          elevation: 0.5,
        ),
        body: Center(
          child: Text(
            'User not found',
            style: TextStyle(
              fontSize: 18,
              color: theme.textTheme.bodyLarge?.color ?? Colors.grey,
            ),
          ),
        ),
      );
    }

    // If profile is null but user exists, show basic user info with message
    if (_profile == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(_user!.name),
          backgroundColor: theme.appBarTheme.backgroundColor,
          foregroundColor: theme.appBarTheme.foregroundColor,
          elevation: 0.5,
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  child: Text(
                    _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : 'U',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _user!.name,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.headlineMedium?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getRoleColor(_user!.role).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getRoleDisplayName(_user!.role),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _getRoleColor(_user!.role),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _user!.email,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 32),
                Icon(
                  Icons.info_outline,
                  size: 48,
                  color: theme.textTheme.bodyMedium?.color,
                ),
                const SizedBox(height: 16),
                Text(
                  'Profile not set up yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isCurrentUser
                      ? 'Complete your profile to showcase your skills and experience'
                      : 'This user hasn\'t completed their profile yet',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_isCurrentUser) ...[
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to comprehensive profile setup screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const ComprehensiveProfileSetupScreen(),
                        ),
                      );
                    },
                    child: const Text('Complete Profile'),
                  ),
                  const SizedBox(height: 16),
                  // Debug button to check database directly
                  OutlinedButton(
                    onPressed: () async {
                      final profileService =
                          Provider.of<ProfileService>(context, listen: false);

                      try {
                        // Try to get profile by direct document ID
                        await profileService
                            .getProfileById('profile_${widget.userId}');
                        // Try to get all profiles and find this user
                        final allProfiles =
                            await profileService.getAllProfiles();
                        final userProfile = allProfiles
                            .where((p) => p.userId == widget.userId)
                            .toList();

                        if (userProfile.isNotEmpty && mounted) {
                          setState(() {
                            _profile = userProfile.first;
                            _isLoading = false;
                          });
                          return;
                        }
                      } catch (e) {
                        debugPrint('Error checking profiles: $e');
                      }
                    },
                    child: const Text('Debug: Check Database'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _profile!.fullName,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: theme.appBarTheme.foregroundColor,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isCurrentUser && !widget.isViewOnly) ...[
            IconButton(
              icon: Icon(
                Icons.message_rounded,
                color: theme.primaryColor,
              ),
              onPressed: () {
                // Messaging feature placeholder - to be implemented in future version
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Messaging feature coming soon!'),
                    backgroundColor: theme.colorScheme.primary,
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                color: theme.textTheme.bodyMedium?.color,
              ),
              onPressed: () => _showMoreOptionsMenu(),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // Profile Header
            _buildProfileHeader(),

            const SizedBox(height: 24),

            // Profile Sections
            _buildProfileSections(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final theme = Theme.of(context);
    final completeness = _calculateProfileCompleteness();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.grey[800]?.withValues(alpha: 0.9)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cover Photo Area (LinkedIn-style)
          Container(
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.primaryColor.withValues(alpha: 0.8),
                  theme.primaryColor.withValues(alpha: 0.6),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLg),
                topRight: Radius.circular(AppTheme.radiusLg),
              ),
            ),
          ),

          // Profile Content
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: Column(
              children: [
                // Profile Picture positioned over cover
                Transform.translate(
                  offset: const Offset(0, -60),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.cardColor,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadowColor.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 50,
                          backgroundImage: _profile!.profileImageUrl != null &&
                                  _profile!.profileImageUrl!.isNotEmpty
                              ? (Uri.tryParse(_profile!.profileImageUrl!)
                                          ?.hasAbsolutePath ==
                                      true
                                  ? NetworkImage(_profile!.profileImageUrl!)
                                  : null)
                              : null,
                          backgroundColor:
                              theme.primaryColor.withValues(alpha: 0.1),
                          child: _profile!.profileImageUrl == null ||
                                  _profile!.profileImageUrl!.isEmpty
                              ? Text(
                                  _profile!.fullName.isNotEmpty
                                      ? _profile!.fullName[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryColor,
                                  ),
                                )
                              : null,
                        ),
                      ),

                      const SizedBox(height: AppTheme.spaceMd),

                      // Name and Title
                      Text(
                        _profile!.fullName,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.headlineMedium?.color,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppTheme.spaceXs),

                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMd,
                          vertical: AppTheme.spaceXs,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _getRoleColor(_user!.role).withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusFull),
                          border: Border.all(
                            color: _getRoleColor(_user!.role)
                                .withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _getRoleDisplayName(_user!.role),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _getRoleColor(_user!.role),
                          ),
                        ),
                      ),

                      // Headline
                      if (_profile!.headline != null &&
                          _profile!.headline!.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.spaceSm),
                        Text(
                          _profile!.headline!,
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.textTheme.bodyMedium?.color,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Profile Stats and Completeness
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Column(
                    children: [
                      // Profile Completeness Card
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spaceMd),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? Colors.grey[800]?.withValues(alpha: 0.8)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                            color: theme.colorScheme.outline
                                .withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                value: completeness / 100,
                                strokeWidth: 3,
                                backgroundColor: theme
                                    .textTheme.bodyMedium?.color
                                    ?.withValues(alpha: 0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getCompletenessColor(completeness),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spaceSm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${completeness.round()}% Complete',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                Text(
                                  'Profile Strength',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodyMedium?.color,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Quick Info Chips
                      const SizedBox(height: AppTheme.spaceMd),
                      Wrap(
                        spacing: AppTheme.spaceXs,
                        runSpacing: AppTheme.spaceXs,
                        alignment: WrapAlignment.center,
                        children: [
                          _buildInfoChip(Icons.email_rounded, _user!.email),
                          if (_profile!.academicInfo?.department != null)
                            _buildInfoChip(Icons.school_rounded,
                                _profile!.academicInfo!.department),
                          if (_profile!.skills.isNotEmpty)
                            _buildInfoChip(Icons.star_rounded,
                                '${_profile!.skills.length} Skills'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.grey[800]?.withValues(alpha: 0.8)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: theme.brightness == Brightness.dark
                ? Colors.white
                : theme.primaryColor,
          ),
          const SizedBox(width: AppTheme.spaceXs),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodyMedium?.color,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSections() {
    return Column(
      children: [
        // Academic Information
        if (_profile!.academicInfo != null) _buildAcademicSection(),

        // Skills
        if (_profile!.skills.isNotEmpty) _buildSkillsSection(),

        // Interests
        if (_profile!.interests.isNotEmpty) _buildInterestsSection(),

        // Experience
        if (_profile!.experiences.isNotEmpty) _buildExperienceSection(),

        // Projects
        if (_profile!.projects.isNotEmpty) _buildProjectsSection(),

        // Achievements
        if (_profile!.achievements.isNotEmpty) _buildAchievementsSection(),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildAcademicSection() {
    final academic = _profile!.academicInfo!;
    return _buildSection(
      title: 'Academic Information',
      icon: Icons.school,
      child: Column(
        children: [
          _buildInfoRow('Program', academic.program),
          _buildInfoRow('Department', academic.department),
          _buildInfoRow('Semester', academic.currentSemester.toString()),
          if (academic.cgpa != null)
            _buildInfoRow('CGPA', academic.cgpa!.toStringAsFixed(2)),
          _buildInfoRow('Student ID', academic.studentId),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    final theme = Theme.of(context);
    return _buildSection(
      title: 'Skills',
      icon: Icons.psychology_rounded,
      child: Wrap(
        spacing: AppTheme.spaceXs,
        runSpacing: AppTheme.spaceXs,
        children: _profile!.skills
            .map((skill) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm,
                    vertical: AppTheme.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[700]?.withValues(alpha: 0.8)
                        : theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? (Colors.grey[500] ?? Colors.grey)
                              .withValues(alpha: 0.5)
                          : theme.primaryColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        size: 14,
                        color: theme.brightness == Brightness.dark
                            ? Colors.grey[300]
                            : theme.primaryColor,
                      ),
                      const SizedBox(width: AppTheme.spaceXs),
                      Text(
                        skill,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : theme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildInterestsSection() {
    final theme = Theme.of(context);
    final interestColor = theme.colorScheme.secondary;
    return _buildSection(
      title: 'Interests',
      icon: Icons.favorite_rounded,
      child: Wrap(
        spacing: AppTheme.spaceXs,
        runSpacing: AppTheme.spaceXs,
        children: _profile!.interests
            .map((interest) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm,
                    vertical: AppTheme.spaceXs,
                  ),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[700]?.withValues(alpha: 0.8)
                        : interestColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? (Colors.grey[500] ?? Colors.grey)
                              .withValues(alpha: 0.5)
                          : interestColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        size: 14,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : interestColor,
                      ),
                      const SizedBox(width: AppTheme.spaceXs),
                      Text(
                        interest,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : interestColor,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildExperienceSection() {
    final theme = Theme.of(context);
    return _buildSection(
      title: 'Experience',
      icon: Icons.work,
      child: Column(
        children: _profile!.experiences
            .map((exp) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[800]?.withValues(alpha: 0.8)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exp.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      if (exp.company.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          exp.company,
                          style: TextStyle(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white70
                                : theme.textTheme.bodyMedium?.color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      if (exp.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          exp.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.brightness == Brightness.dark
                                ? Colors.white70
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildProjectsSection() {
    final theme = Theme.of(context);
    return _buildSection(
      title: 'Projects',
      icon: Icons.code,
      child: Column(
        children: _profile!.projects
            .map((project) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[800]?.withValues(alpha: 0.8)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      if (project.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          project.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.brightness == Brightness.dark
                                ? Colors.white70
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                      if (project.technologies.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: project.technologies
                              .map((tech) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: theme.primaryColor
                                            .withValues(alpha: 0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      tech,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            theme.brightness == Brightness.dark
                                                ? Colors.white
                                                : theme.primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildAchievementsSection() {
    final theme = Theme.of(context);
    return _buildSection(
      title: 'Achievements',
      icon: Icons.emoji_events,
      child: Column(
        children: _profile!.achievements
            .map((achievement) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[800]?.withValues(alpha: 0.8)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.outline.withValues(alpha: 0.4),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadowColor.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.emoji_events,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              achievement.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: theme.brightness == Brightness.dark
                                    ? Colors.white
                                    : theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            if (achievement.description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                achievement.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.brightness == Brightness.dark
                                      ? Colors.white70
                                      : theme.textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMd,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.grey[800]?.withValues(alpha: 0.9)
            : theme.cardColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusLg),
                topRight: Radius.circular(AppTheme.radiusLg),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppTheme.spaceXs),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Icon(
                    icon,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : theme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceSm),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.textTheme.headlineSmall?.color,
                  ),
                ),
              ],
            ),
          ),

          // Section Content
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLg),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: theme.brightness == Brightness.dark
                    ? Colors.white70
                    : theme.textTheme.bodyMedium?.color,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color: theme.brightness == Brightness.dark
                    ? Colors.white
                    : theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateProfileCompleteness() {
    int totalFields = 10;
    int completedFields = 0;

    if (_profile!.fullName.isNotEmpty) completedFields++;
    if (_profile!.bio != null && _profile!.bio!.isNotEmpty) completedFields++;
    if (_profile!.headline != null && _profile!.headline!.isNotEmpty) {
      completedFields++;
    }
    if (_profile!.profileImageUrl != null &&
        _profile!.profileImageUrl!.isNotEmpty) {
      completedFields++;
    }
    if (_profile!.skills.isNotEmpty) completedFields++;
    if (_profile!.interests.isNotEmpty) completedFields++;
    if (_profile!.experiences.isNotEmpty) completedFields++;
    if (_profile!.projects.isNotEmpty) completedFields++;
    if (_profile!.achievements.isNotEmpty) completedFields++;
    if (_profile!.academicInfo != null) completedFields++;

    return (completedFields / totalFields) * 100;
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.student:
        return Colors.blue;
      case UserRole.lecturer:
        return Colors.green;
      case UserRole.admin:
        return Colors.red;
    }
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.lecturer:
        return 'Lecturer';
      case UserRole.admin:
        return 'Admin';
    }
  }

  Color _getCompletenessColor(double completeness) {
    if (completeness >= 80) return Colors.green;
    if (completeness >= 50) return Colors.orange;
    return Colors.red;
  }

  void _showMoreOptionsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.report_outlined),
              title: const Text('Report Profile'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: const Text('Block User'),
              onTap: () {
                Navigator.pop(context);
                _showBlockDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share Profile'),
              onTap: () {
                Navigator.pop(context);
                _shareProfile();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Profile'),
        content: const Text(
            'Are you sure you want to report this profile for inappropriate content?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profile reported successfully'),
                  backgroundColor: AppTheme.successColor,
                ),
              );
            },
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block User'),
        content: const Text(
            'Are you sure you want to block this user? You won\'t see their content anymore.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('User blocked successfully'),
                  backgroundColor: AppTheme.warningColor,
                ),
              );
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _shareProfile() {
    // Implement profile sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile sharing feature coming soon!'),
        backgroundColor: AppTheme.infoColor,
      ),
    );
  }
}
