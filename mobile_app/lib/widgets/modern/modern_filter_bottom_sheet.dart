import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/search_models.dart';
import 'advanced_filter_widgets.dart';

/// Modern enhanced filter bottom sheet with advanced UI components
class ModernFilterBottomSheet extends StatefulWidget {
  final Map<String, List<SearchFilter>> availableFilters;
  final Function(SearchFilter) onFilterToggle;
  final VoidCallback onClearAll;
  final VoidCallback onApply;
  final RangeValues semesterRange;
  final RangeValues cgpaRange;
  final Function(RangeValues) onSemesterRangeChanged;
  final Function(RangeValues) onCgpaRangeChanged;

  const ModernFilterBottomSheet({
    super.key,
    required this.availableFilters,
    required this.onFilterToggle,
    required this.onClearAll,
    required this.onApply,
    required this.semesterRange,
    required this.cgpaRange,
    required this.onSemesterRangeChanged,
    required this.onCgpaRangeChanged,
  });

  @override
  State<ModernFilterBottomSheet> createState() =>
      _ModernFilterBottomSheetState();
}

class _ModernFilterBottomSheetState extends State<ModernFilterBottomSheet> {
  late RangeValues _semesterRange;
  late RangeValues _cgpaRange;

  @override
  void initState() {
    super.initState();
    _semesterRange = widget.semesterRange;
    _cgpaRange = widget.cgpaRange;
  }

  int get _totalActiveFilters {
    return widget.availableFilters.values
        .expand((filters) => filters)
        .where((filter) => filter.isSelected)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Range filters
                  _buildRangeFilters(),

                  const SizedBox(height: AppTheme.spaceLg),

                  // Role filters
                  if (widget.availableFilters['role']?.isNotEmpty == true)
                    _buildRoleFilters(),

                  const SizedBox(height: AppTheme.spaceLg),

                  // Department filters
                  if (widget.availableFilters['department']?.isNotEmpty == true)
                    _buildDepartmentFilters(),

                  const SizedBox(height: AppTheme.spaceLg),

                  // Skills filters
                  if (widget.availableFilters['skills']?.isNotEmpty == true)
                    _buildSkillsFilters(),

                  const SizedBox(height: AppTheme.spaceLg),

                  // Program filters
                  if (widget.availableFilters['program']?.isNotEmpty == true)
                    _buildProgramFilters(),

                  const SizedBox(height: 100), // Space for bottom buttons
                ],
              ),
            ),
          ),

          // Bottom action buttons
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLg),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Title and close
          Row(
            children: [
              const Icon(
                Icons.tune_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filter Results',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryColor,
                      ),
                    ),
                    if (_totalActiveFilters > 0)
                      Text(
                        '$_totalActiveFilters active filters',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeFilters() {
    return Column(
      children: [
        // Semester range
        ModernRangeSlider(
          title: 'Semester Range',
          currentRange: _semesterRange,
          min: 1,
          max: 8,
          divisions: 7,
          icon: Icons.calendar_today_rounded,
          labelFormatter: (value) => 'Sem ${value.round()}',
          onChanged: (range) {
            setState(() {
              _semesterRange = range;
            });
            widget.onSemesterRangeChanged(range);
          },
        ),

        const SizedBox(height: AppTheme.spaceMd),

        // CGPA range
        ModernRangeSlider(
          title: 'CGPA Range',
          currentRange: _cgpaRange,
          min: 0.0,
          max: 4.0,
          divisions: 40,
          icon: Icons.grade_rounded,
          labelFormatter: (value) => value.toStringAsFixed(1),
          onChanged: (range) {
            setState(() {
              _cgpaRange = range;
            });
            widget.onCgpaRangeChanged(range);
          },
        ),
      ],
    );
  }

  Widget _buildRoleFilters() {
    return ModernToggleSwitches(
      title: 'User Roles',
      filters: widget.availableFilters['role'] ?? [],
      onToggle: widget.onFilterToggle,
      icon: Icons.people_rounded,
    );
  }

  Widget _buildDepartmentFilters() {
    return ModernMultiSelectChips(
      title: 'Departments',
      filters: widget.availableFilters['department'] ?? [],
      onToggle: widget.onFilterToggle,
      icon: Icons.school_rounded,
      chipColor: Colors.blue,
    );
  }

  Widget _buildSkillsFilters() {
    return ModernMultiSelectChips(
      title: 'Skills',
      filters: widget.availableFilters['skills'] ?? [],
      onToggle: widget.onFilterToggle,
      icon: Icons.star_rounded,
      chipColor: Colors.orange,
    );
  }

  Widget _buildProgramFilters() {
    return ModernMultiSelectChips(
      title: 'Programs',
      filters: widget.availableFilters['program'] ?? [],
      onToggle: widget.onFilterToggle,
      icon: Icons.book_rounded,
      chipColor: Colors.green,
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Clear all button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _totalActiveFilters > 0
                    ? () {
                        widget.onClearAll();
                        setState(() {
                          _semesterRange = const RangeValues(1, 8);
                          _cgpaRange = const RangeValues(0, 4);
                        });
                      }
                    : null,
                icon: const Icon(Icons.clear_all_rounded),
                label: const Text('Clear All'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                  side: BorderSide(
                    color: _totalActiveFilters > 0
                        ? AppTheme.errorColor
                        : AppTheme.textSecondaryColor.withValues(alpha: 0.3),
                  ),
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppTheme.spaceMd),

            // Apply button
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  widget.onApply();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(_totalActiveFilters > 0
                    ? 'Apply ($_totalActiveFilters)'
                    : 'Apply Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: AppTheme.spaceMd),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
