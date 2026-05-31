import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class InterestsSelector extends StatefulWidget {
  final List<String> selectedInterests;
  final Function(List<String>) onInterestsChanged;

  const InterestsSelector({
    super.key,
    required this.selectedInterests,
    required this.onInterestsChanged,
  });

  @override
  State<InterestsSelector> createState() => _InterestsSelectorState();
}

class _InterestsSelectorState extends State<InterestsSelector> {
  final TextEditingController _customInterestController =
      TextEditingController();
  late List<String> _selectedInterests;

  // Predefined interests categories
  static const Map<String, List<String>> _interestCategories = {
    'Technology': [
      'Artificial Intelligence',
      'Machine Learning',
      'Blockchain',
      'IoT',
      'Cybersecurity',
      'Cloud Computing',
      'Mobile Development',
      'Web Development',
      'Game Development',
      'Robotics',
      'Virtual Reality',
      'Augmented Reality',
      'Data Science',
      'Software Engineering',
      'DevOps'
    ],
    'Creative Arts': [
      'Photography',
      'Digital Art',
      'Graphic Design',
      'Music Production',
      'Video Editing',
      'Animation',
      'Creative Writing',
      'Painting',
      'Drawing',
      'Sculpture',
      'Fashion Design',
      'Interior Design',
      'Film Making',
      'Theater',
      'Dance'
    ],
    'Sports & Fitness': [
      'Football',
      'Basketball',
      'Badminton',
      'Tennis',
      'Swimming',
      'Running',
      'Cycling',
      'Gym',
      'Yoga',
      'Martial Arts',
      'Rock Climbing',
      'Hiking',
      'Volleyball',
      'Table Tennis',
      'Fitness Training',
      'CrossFit'
    ],
    'Academic & Research': [
      'Research',
      'Academic Writing',
      'Mathematics',
      'Physics',
      'Chemistry',
      'Biology',
      'Psychology',
      'Philosophy',
      'History',
      'Literature',
      'Economics',
      'Political Science',
      'Sociology',
      'Anthropology',
      'Environmental Science'
    ],
    'Business & Entrepreneurship': [
      'Entrepreneurship',
      'Startup',
      'Business Development',
      'Marketing',
      'Sales',
      'Finance',
      'Investment',
      'E-commerce',
      'Digital Marketing',
      'Social Media Marketing',
      'Brand Management',
      'Project Management',
      'Leadership',
      'Innovation',
      'Strategy'
    ],
    'Social & Community': [
      'Volunteering',
      'Community Service',
      'Social Work',
      'Teaching',
      'Mentoring',
      'Public Speaking',
      'Debate',
      'Student Organizations',
      'Cultural Activities',
      'Environmental Conservation',
      'Charity Work',
      'Event Organization',
      'Networking',
      'Social Impact'
    ],
    'Hobbies & Lifestyle': [
      'Reading',
      'Cooking',
      'Baking',
      'Gardening',
      'Travel',
      'Languages',
      'Board Games',
      'Video Games',
      'Collecting',
      'DIY Projects',
      'Crafts',
      'Knitting',
      'Woodworking',
      'Astronomy',
      'Nature',
      'Pets'
    ],
    'Entertainment': [
      'Movies',
      'TV Series',
      'Anime',
      'K-Pop',
      'Music',
      'Concerts',
      'Festivals',
      'Stand-up Comedy',
      'Podcasts',
      'YouTube',
      'Streaming',
      'Gaming',
      'Esports',
      'Social Media',
      'Memes'
    ]
  };

  @override
  void initState() {
    super.initState();
    _selectedInterests = List.from(widget.selectedInterests);
  }

  @override
  void dispose() {
    _customInterestController.dispose();
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
                Icons.favorite,
                color: AppTheme.secondaryColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Text(
                'Interests',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.secondaryColor,
                    ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spaceSm),

          Text(
            'Select Your Interests',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.grayColor,
                ),
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Selected Interests Display
          if (_selectedInterests.isNotEmpty) ...[
            Text(
              'Selected Interests (${_selectedInterests.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            Wrap(
              spacing: AppTheme.spaceXs,
              runSpacing: AppTheme.spaceXs,
              children: _selectedInterests
                  .map((interest) => _buildSelectedInterestChip(interest))
                  .toList(),
            ),
            const SizedBox(height: AppTheme.spaceMd),
          ],

          // Add Custom Interest
          _buildAddCustomInterestSection(),

          const SizedBox(height: AppTheme.spaceMd),

          // Interest Categories
          Text(
            'Interest Categories',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),

          const SizedBox(height: AppTheme.spaceSm),

          // Categories List
          ..._interestCategories.entries.map((category) =>
              _buildInterestCategory(category.key, category.value)),
        ],
      ),
    );
  }

  Widget _buildSelectedInterestChip(String interest) {
    return Chip(
      label: Text(
        interest,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: AppTheme.secondaryColor,
      deleteIcon: const Icon(
        Icons.close,
        color: Colors.white,
        size: 18,
      ),
      onDeleted: () {
        setState(() {
          _selectedInterests.remove(interest);
        });
        widget.onInterestsChanged(_selectedInterests);
      },
    );
  }

  Widget _buildAddCustomInterestSection() {
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
              controller: _customInterestController,
              decoration: const InputDecoration(
                hintText: 'Add custom interest',
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: AppTheme.spaceSm),
              ),
              onSubmitted: _addCustomInterest,
            ),
          ),
          IconButton(
            onPressed: () => _addCustomInterest(_customInterestController.text),
            icon: const Icon(
              Icons.add_circle,
              color: AppTheme.secondaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestCategory(String categoryName, List<String> interests) {
    return ExpansionTile(
      title: Text(
        categoryName,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryColor,
            ),
      ),
      leading: Icon(
        _getCategoryIcon(categoryName),
        color: AppTheme.secondaryColor,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd),
          child: Wrap(
            spacing: AppTheme.spaceXs,
            runSpacing: AppTheme.spaceXs,
            children: interests
                .map((interest) => _buildInterestChip(interest))
                .toList(),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSm),
      ],
    );
  }

  Widget _buildInterestChip(String interest) {
    final isSelected = _selectedInterests.contains(interest);

    return FilterChip(
      label: Text(
        interest,
        style: TextStyle(
          color: isSelected ? Colors.white : AppTheme.secondaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            if (!_selectedInterests.contains(interest)) {
              _selectedInterests.add(interest);
            }
          } else {
            _selectedInterests.remove(interest);
          }
        });
        widget.onInterestsChanged(_selectedInterests);
      },
      backgroundColor: Colors.white,
      selectedColor: AppTheme.secondaryColor,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.secondaryColor : AppTheme.lightGrayColor,
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    switch (categoryName) {
      case 'Technology':
        return Icons.computer;
      case 'Creative Arts':
        return Icons.palette;
      case 'Sports & Fitness':
        return Icons.sports;
      case 'Academic & Research':
        return Icons.school;
      case 'Business & Entrepreneurship':
        return Icons.business;
      case 'Social & Community':
        return Icons.people;
      case 'Hobbies & Lifestyle':
        return Icons.interests;
      case 'Entertainment':
        return Icons.movie;
      default:
        return Icons.category;
    }
  }

  void _addCustomInterest(String interest) {
    final trimmedInterest = interest.trim();
    if (trimmedInterest.isNotEmpty &&
        !_selectedInterests.contains(trimmedInterest)) {
      setState(() {
        _selectedInterests.add(trimmedInterest);
        _customInterestController.clear();
      });
      widget.onInterestsChanged(_selectedInterests);
    }
  }
}
