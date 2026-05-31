import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../services/supabase_auth_service.dart';
import '../../../services/talent_service.dart';
import '../../../utils/app_theme.dart';
import 'talent_quiz_questions.dart';
import 'talent_quiz_result_screen.dart';

class TalentQuizScreen extends StatefulWidget {
  const TalentQuizScreen({super.key});

  @override
  State<TalentQuizScreen> createState() => _TalentQuizScreenState();
}

class _TalentQuizScreenState extends State<TalentQuizScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final Map<String, Map<String, dynamic>> _answers = {};
  bool _isSubmitting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _selectAnswer(QuizOption option) {
    HapticFeedback.lightImpact();
    final question = talentQuizQuestions[_currentIndex];

    setState(() {
      _answers[question.id] = {
        'answer': option.text,
        'category': question.category,
        'score': option.score,
      };
    });
  }

  void _goToNext() {
    if (_currentIndex < talentQuizQuestions.length - 1) {
      _animationController.reset();
      setState(() {
        _currentIndex++;
      });
      _animationController.forward();
    }
  }

  void _goToPrevious() {
    if (_currentIndex > 0) {
      _animationController.reset();
      setState(() {
        _currentIndex--;
      });
      _animationController.forward();
    }
  }

  Future<void> _submitQuiz() async {
    if (_answers.length < talentQuizQuestions.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sila jawab semua soalan (${_answers.length}/${talentQuizQuestions.length})',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;

      if (userId == null) throw Exception('User not logged in');

      final talentService = TalentService();
      final answersForApi = _answers.entries
          .map((e) => {
                'question_id': e.key,
                'answer': e.value['answer'],
                'category': e.value['category'],
                'score': e.value['score'],
              })
          .toList();

      final result =
          await talentService.submitQuizResults(userId, answersForApi);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TalentQuizResultScreen(quizResult: result),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = talentQuizQuestions[_currentIndex];
    final catInfo = categoryInfo[question.category];
    final isLastQuestion = _currentIndex == talentQuizQuestions.length - 1;
    final hasAnsweredCurrent = _answers.containsKey(question.id);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
          onPressed: () => _showExitDialog(),
        ),
        title: Text(
          'Descobri Bakat Anda',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMd,
                vertical: AppTheme.spaceSm,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Soalan ${_currentIndex + 1}/${talentQuizQuestions.length}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            catInfo?['icon'] ?? '📝',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            catInfo?['name'] ?? 'Category',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (_currentIndex + 1) / talentQuizQuestions.length,
                      minHeight: 8,
                      backgroundColor:
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                      valueColor:
                          AlwaysStoppedAnimation(theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
            ),

            // Question card
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMd),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Question text
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spaceLg),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withValues(alpha: 0.1),
                              theme.colorScheme.secondary
                                  .withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusLg),
                          border: Border.all(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          question.question,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppTheme.spaceLg),

                      // Options
                      ...question.options.asMap().entries.map((entry) {
                        final index = entry.key;
                        final option = entry.value;
                        final isSelected =
                            _answers[question.id]?['answer'] == option.text;

                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppTheme.spaceSm),
                          child: InkWell(
                            onTap: () => _selectAnswer(option),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(AppTheme.spaceMd),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.surface,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outline
                                          .withValues(alpha: 0.3),
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? Colors.white
                                          : theme.colorScheme.primary
                                              .withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        String.fromCharCode(
                                            65 + index), // A, B, C
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spaceMd),
                                  Expanded(
                                    child: Text(
                                      option.text,
                                      style:
                                          theme.textTheme.bodyLarge?.copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : theme.colorScheme.onSurface,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceMd),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Previous button
                  if (_currentIndex > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _goToPrevious,
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Sebelum'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                          ),
                        ),
                      ),
                    ),

                  if (_currentIndex > 0)
                    const SizedBox(width: AppTheme.spaceMd),

                  // Next/Submit button
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: isLastQuestion
                          ? (hasAnsweredCurrent ? _submitQuiz : null)
                          : (hasAnsweredCurrent ? _goToNext : null),
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(isLastQuestion
                              ? Icons.check_circle
                              : Icons.arrow_forward),
                      label: Text(isLastQuestion ? 'Hantar' : 'Seterusnya'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
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

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar Quiz?'),
        content: const Text(
          'Progress quiz anda tidak akan disimpan. Adakah anda pasti?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
