import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/supabase_auth_service.dart';
import '../services/talent_service.dart';
import '../services/profile_service.dart';
import '../utils/app_theme.dart';
import '../screens/student/talent/talent_quiz_screen.dart';

/// Widget untuk display talent recommendations dan discover banner
class TalentRecommendationsWidget extends StatefulWidget {
  final bool showDiscoverBanner;
  final bool showSimilarStudents;

  const TalentRecommendationsWidget({
    super.key,
    this.showDiscoverBanner = true,
    this.showSimilarStudents = true,
  });

  @override
  State<TalentRecommendationsWidget> createState() =>
      _TalentRecommendationsWidgetState();
}

class _TalentRecommendationsWidgetState
    extends State<TalentRecommendationsWidget> {
  bool _isLoading = true;
  bool _hasCompletedQuiz = false;
  Map<String, dynamic>? _recommendations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);
      final userId = authService.currentUserId;

      if (userId == null) {
        // debugPrint('⚠️ TalentRecommendationsWidget: No userId found');
        return;
      }
      // debugPrint(
      //     '🔍 TalentRecommendationsWidget: Checking quiz for user $userId');

      // Use ProfileService as PRIMARY source if available (more reliable via Supabase direct)
      final profileService =
          Provider.of<ProfileService>(context, listen: false);
      final profile = await profileService.getProfileByUserId(userId);

      bool completed = false;
      if (profile?.talentProfile?.quizResults != null) {
        // debugPrint(
        //     '✅ TalentRecommendationsWidget: Found result in ProfileService');
        completed = true;
      } else {
        // debugPrint(
        //     '⚠️ TalentRecommendationsWidget: No result in ProfileService, checking TalentService...');
        // Fallback to TalentService (old way)
        final talentService = TalentService();
        final quizResults = await talentService.getQuizResults(userId);
        if (quizResults != null) {
          // debugPrint(
          //     '✅ TalentRecommendationsWidget: Found result in TalentService');
          completed = true;
        } else {
          // debugPrint(
          //     '❌ TalentRecommendationsWidget: No result in TalentService either');
        }
      }

      _hasCompletedQuiz = completed;

      final talentService = TalentService();
      // Get recommendations
      try {
        _recommendations = await talentService.getRecommendations(userId);
      } catch (e) {
        // Ignore recommendation errors
        debugPrint(
            '⚠️ TalentRecommendationsWidget: Error fetching recommendations: $e');
      }
    } catch (e) {
      debugPrint('❌ TalentRecommendationsWidget: Error initializing: $e');
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(
        height: 150,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Discover Your Talents Banner (if quiz not taken)
        if (widget.showDiscoverBanner && !_hasCompletedQuiz)
          _buildDiscoverBanner(context),

        // Similar Students Section
        if (widget.showSimilarStudents &&
            _recommendations != null &&
            (_recommendations!['similar_students'] as List?)?.isNotEmpty ==
                true)
          _buildSimilarStudentsSection(context),
      ],
    );
  }

  Widget _buildDiscoverBanner(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Text(
                  '✨',
                  style: TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: AppTheme.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover Your Talents!',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jawab quiz 2 minit untuk kenalpasti bakat tersembunyi anda',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TalentQuizScreen(),
                  ),
                ).then((_) => _loadRecommendations());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Mula Quiz',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimilarStudentsSection(BuildContext context) {
    final theme = Theme.of(context);
    final similarStudents =
        _recommendations!['similar_students'] as List? ?? [];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('👥', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text(
                    'Pelajar Dengan Minat Sama',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {
                  // Navigate to full similar students list
                },
                child: const Text('Lihat Semua'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: similarStudents.length,
              itemBuilder: (context, index) {
                final student = similarStudents[index];
                return _buildStudentCard(context, student);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context, Map<String, dynamic> student) {
    final theme = Theme.of(context);
    final commonInterests =
        (student['common_interests'] as List?)?.take(2) ?? [];

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: AppTheme.spaceSm),
      padding: const EdgeInsets.all(AppTheme.spaceSm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            backgroundImage: student['profile_image_url'] != null
                ? NetworkImage(student['profile_image_url'])
                : null,
            child: student['profile_image_url'] == null
                ? Text(
                    (student['full_name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 8),
          // Name
          Text(
            student['full_name'] ?? 'Unknown',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          // Common interests
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 2,
            children: commonInterests.map<Widget>((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getCategoryEmoji(interest.toString()),
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _getCategoryEmoji(String category) {
    const emojis = {
      'performingArts': '🎭',
      'visualArts': '🎨',
      'sports': '⚽',
      'languageLiterature': '📚',
      'technicalHobbies': '🔧',
      'communitySocial': '🌱',
      'communication': '💬',
      'leadership': '👑',
      'teamwork': '🤝',
    };
    return emojis[category] ?? '⭐';
  }
}
