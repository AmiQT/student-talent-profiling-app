import 'package:flutter/material.dart';
import '../../../models/talent_model.dart';
import '../../../utils/app_theme.dart';
import 'talent_quiz_questions.dart';

class TalentQuizResultScreen extends StatefulWidget {
  final TalentQuizResultModel quizResult;

  const TalentQuizResultScreen({super.key, required this.quizResult});

  @override
  State<TalentQuizResultScreen> createState() => _TalentQuizResultScreenState();
}

class _TalentQuizResultScreenState extends State<TalentQuizResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topTalents = widget.quizResult.topTalents;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spaceMd),
          child: Column(
            children: [
              const SizedBox(height: AppTheme.spaceLg),

              // Success animation
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spaceLg),

              Text(
                'Tahniah! 🎉',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),

              const SizedBox(height: AppTheme.spaceSm),

              Text(
                'Kami telah mengenal pasti bakat anda',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppTheme.spaceXl),

              // Top 3 Talents
              Text(
                'Top 3 Bakat Anda',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: AppTheme.spaceMd),

              ...topTalents.asMap().entries.map((entry) {
                final index = entry.key;
                final talent = entry.value;
                final info = categoryInfo[talent];
                final score = widget.quizResult.categoryScores[talent] ?? 0;
                final maxScore = _getMaxScoreForCategory(talent);

                return _buildTalentCard(
                  context,
                  rank: index + 1,
                  icon: info?['icon'] ?? '🌟',
                  name: info?['name'] ?? talent,
                  score: score,
                  maxScore: maxScore,
                  colorHex: info?['color'] ?? '#3B82F6',
                );
              }),

              const SizedBox(height: AppTheme.spaceLg),

              // All scores
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceMd),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skor Lengkap',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMd),
                    ...widget.quizResult.categoryScores.entries.map((entry) {
                      final info = categoryInfo[entry.key];
                      final maxScore = _getMaxScoreForCategory(entry.key);
                      return _buildScoreRow(
                        context,
                        icon: info?['icon'] ?? '📊',
                        name: info?['name'] ?? entry.key,
                        score: entry.value,
                        maxScore: maxScore,
                      );
                    }),
                  ],
                ),
              ),

              const SizedBox(height: AppTheme.spaceXl),

              // Action buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text('Kembali ke Dashboard'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spaceMd),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Navigate to edit skills/hobbies
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit Bakat Saya'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spaceLg),
            ],
          ),
        ),
      ),
    );
  }

  int _getMaxScoreForCategory(String category) {
    // Count questions for this category and multiply by max score (5)
    final count =
        talentQuizQuestions.where((q) => q.category == category).length;
    return count * 5;
  }

  Widget _buildTalentCard(
    BuildContext context, {
    required int rank,
    required String icon,
    required String name,
    required int score,
    required int maxScore,
    required String colorHex,
  }) {
    final theme = Theme.of(context);
    final color = _hexToColor(colorHex);
    final percentage = maxScore > 0 ? (score / maxScore) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: rank == 1
                  ? Colors.amber
                  : rank == 2
                      ? Colors.grey[400]
                      : Colors.orange[300],
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceMd),

          // Icon
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: AppTheme.spaceMd),

          // Name and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percentage,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),

          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Text(
              '$score/$maxScore',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(
    BuildContext context, {
    required String icon,
    required String name,
    required int score,
    required int maxScore,
  }) {
    final theme = Theme.of(context);
    final percentage = maxScore > 0 ? (score / maxScore) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSm),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              name,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 4,
                backgroundColor:
                    theme.colorScheme.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Text(
            '$score/$maxScore',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  }
}
