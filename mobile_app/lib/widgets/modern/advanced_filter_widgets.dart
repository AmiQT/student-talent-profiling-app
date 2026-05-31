import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../models/search_models.dart';

/// Modern range slider for CGPA and semester filtering
class ModernRangeSlider extends StatefulWidget {
  final String title;
  final RangeValues currentRange;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) labelFormatter;
  final Function(RangeValues) onChanged;
  final IconData icon;

  const ModernRangeSlider({
    super.key,
    required this.title,
    required this.currentRange,
    required this.min,
    required this.max,
    required this.divisions,
    required this.labelFormatter,
    required this.onChanged,
    required this.icon,
  });

  @override
  State<ModernRangeSlider> createState() => _ModernRangeSliderState();
}

class _ModernRangeSliderState extends State<ModernRangeSlider> {
  late RangeValues _currentRange;

  @override
  void initState() {
    super.initState();
    _currentRange = widget.currentRange;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXs),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Range display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm,
                  vertical: AppTheme.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  widget.labelFormatter(_currentRange.start),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
              const Text(
                'to',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceSm,
                  vertical: AppTheme.spaceXs,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  widget.labelFormatter(_currentRange.end),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spaceSm),

          // Range slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              thumbColor: AppTheme.primaryColor,
              overlayColor: AppTheme.primaryColor.withValues(alpha: 0.2),
              valueIndicatorColor: AppTheme.primaryColor,
              valueIndicatorTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: RangeSlider(
              values: _currentRange,
              min: widget.min,
              max: widget.max,
              divisions: widget.divisions,
              labels: RangeLabels(
                widget.labelFormatter(_currentRange.start),
                widget.labelFormatter(_currentRange.end),
              ),
              onChanged: (values) {
                setState(() {
                  _currentRange = values;
                });
                widget.onChanged(values);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern multi-select chip widget for skills and departments
class ModernMultiSelectChips extends StatefulWidget {
  final String title;
  final List<SearchFilter> filters;
  final Function(SearchFilter) onToggle;
  final IconData icon;
  final Color chipColor;
  final int maxDisplayed;

  const ModernMultiSelectChips({
    super.key,
    required this.title,
    required this.filters,
    required this.onToggle,
    required this.icon,
    this.chipColor = AppTheme.primaryColor,
    this.maxDisplayed = 20,
  });

  @override
  State<ModernMultiSelectChips> createState() => _ModernMultiSelectChipsState();
}

class _ModernMultiSelectChipsState extends State<ModernMultiSelectChips> {
  bool _showAll = false;
  String _searchQuery = '';

  List<SearchFilter> get _filteredFilters {
    var filtered = widget.filters;
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((filter) =>
              filter.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return filtered;
  }

  List<SearchFilter> get _displayedFilters {
    final filtered = _filteredFilters;
    if (_showAll || filtered.length <= widget.maxDisplayed) {
      return filtered;
    }
    return filtered.take(widget.maxDisplayed).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.filters.where((f) => f.isSelected).length;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: selectedCount > 0
              ? widget.chipColor.withValues(alpha: 0.3)
              : AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with count
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXs),
                decoration: BoxDecoration(
                  color: widget.chipColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: widget.chipColor,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimaryColor,
                  ),
                ),
              ),
              if (selectedCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceXs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.chipColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    '$selectedCount',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Search field for filters
          if (widget.filters.length > 10)
            Container(
              margin: const EdgeInsets.only(bottom: AppTheme.spaceMd),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search ${widget.title.toLowerCase()}...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    borderSide: BorderSide(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    borderSide: const BorderSide(color: AppTheme.primaryColor),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceSm,
                    vertical: AppTheme.spaceXs,
                  ),
                  isDense: true,
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),

          // Chips
          Wrap(
            spacing: AppTheme.spaceXs,
            runSpacing: AppTheme.spaceXs,
            children: [
              ..._displayedFilters.map((filter) => _buildFilterChip(filter)),

              // Show more/less button
              if (_filteredFilters.length > widget.maxDisplayed)
                _buildShowMoreChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(SearchFilter filter) {
    return FilterChip(
      label: Text(
        filter.name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: filter.isSelected ? Colors.white : widget.chipColor,
        ),
      ),
      selected: filter.isSelected,
      onSelected: (_) {
        widget.onToggle(filter);
        setState(() {}); // Force rebuild to show updated state
      },
      backgroundColor: widget.chipColor.withValues(alpha: 0.1),
      selectedColor: widget.chipColor,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: filter.isSelected
            ? widget.chipColor
            : widget.chipColor.withValues(alpha: 0.3),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
    );
  }

  Widget _buildShowMoreChip() {
    final remainingCount = _filteredFilters.length - widget.maxDisplayed;

    return ActionChip(
      label: Text(
        _showAll ? 'Show Less' : 'Show $remainingCount More',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppTheme.textSecondaryColor,
        ),
      ),
      onPressed: () {
        setState(() {
          _showAll = !_showAll;
        });
      },
      backgroundColor: AppTheme.surfaceVariant,
      side: BorderSide(
        color: AppTheme.textSecondaryColor.withValues(alpha: 0.3),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
    );
  }
}

/// Modern toggle switches for role filters
class ModernToggleSwitches extends StatefulWidget {
  final String title;
  final List<SearchFilter> filters;
  final Function(SearchFilter) onToggle;
  final IconData icon;

  const ModernToggleSwitches({
    super.key,
    required this.title,
    required this.filters,
    required this.onToggle,
    required this.icon,
  });

  @override
  State<ModernToggleSwitches> createState() => _ModernToggleSwitchesState();
}

class _ModernToggleSwitchesState extends State<ModernToggleSwitches> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXs),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(width: AppTheme.spaceSm),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spaceMd),

          // Toggle switches
          ...widget.filters.map((filter) => _buildToggleItem(filter)),
        ],
      ),
    );
  }

  Widget _buildToggleItem(SearchFilter filter) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceXs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSm,
        vertical: AppTheme.spaceXs,
      ),
      decoration: BoxDecoration(
        color: filter.isSelected
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: filter.isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getRoleIcon(filter.id),
            size: 20,
            color: filter.isSelected
                ? AppTheme.primaryColor
                : AppTheme.textSecondaryColor,
          ),
          const SizedBox(width: AppTheme.spaceSm),
          Expanded(
            child: Text(
              filter.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight:
                    filter.isSelected ? FontWeight.w600 : FontWeight.w500,
                color: filter.isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textPrimaryColor,
              ),
            ),
          ),
          Switch(
            value: filter.isSelected,
            onChanged: (_) {
              widget.onToggle(filter);
              setState(() {}); // Force rebuild to show updated state
            },
            activeThumbColor: AppTheme.primaryColor,
            activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.3),
            inactiveThumbColor: AppTheme.textSecondaryColor,
            inactiveTrackColor:
                AppTheme.textSecondaryColor.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  IconData _getRoleIcon(String roleId) {
    switch (roleId.toLowerCase()) {
      case 'student':
        return Icons.school_rounded;
      case 'lecturer':
        return Icons.person_rounded;
      case 'admin':
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.person_rounded;
    }
  }
}
