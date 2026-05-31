import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/language_service.dart';
import '../../utils/app_theme.dart';

class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return ListTile(
          leading: Container(
            padding: const EdgeInsets.all(AppTheme.spaceXs),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              Icons.language_rounded,
              color: AppTheme.primaryColor,
              size: 20,
            ),
          ),
          title: Text(
            'Language',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          subtitle: Text(
            languageService.currentLanguageDisplayName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.grey,
          ),
          onTap: () => _showLanguageDialog(context, languageService),
        );
      },
    );
  }

  void _showLanguageDialog(
      BuildContext context, LanguageService languageService) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text(
            'Select Language',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: RadioGroup<String>(
            groupValue: languageService.currentLanguageCode,
            onChanged: (value) {
              if (value == null) return;
              _changeLanguage(context, languageService, value);
              Navigator.of(dialogContext).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: LanguageService.supportedLocales.map((locale) {
                final isSelected =
                    languageService.currentLanguageCode == locale.languageCode;
                final displayName = LanguageService.getLanguageDisplayName(
                  locale.languageCode,
                );

                return RadioListTile<String>(
                  value: locale.languageCode,
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppTheme.primaryColor : null,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppTheme.primaryColor,
                  selected: isSelected,
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
        );
      },
    );
  }

  void _changeLanguage(BuildContext context, LanguageService languageService,
      String languageCode) {
    languageService.changeLanguage(languageCode).then((_) {
      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Language changed to ${LanguageService.getLanguageDisplayName(languageCode)}',
            ),
            backgroundColor: AppTheme.successColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }).catchError((error) {
      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error changing language: $error'),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }
}

/// Alternative compact language selector for headers or toolbars
class CompactLanguageSelector extends StatelessWidget {
  const CompactLanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageService>(
      builder: (context, languageService, child) {
        return PopupMenuButton<String>(
          icon: const Icon(Icons.language_rounded),
          tooltip: 'Language',
          onSelected: (languageCode) {
            languageService.changeLanguage(languageCode);
          },
          itemBuilder: (context) {
            return LanguageService.supportedLocales.map((locale) {
              final isSelected =
                  languageService.currentLanguageCode == locale.languageCode;
              final displayName =
                  LanguageService.getLanguageDisplayName(locale.languageCode);

              return PopupMenuItem<String>(
                value: locale.languageCode,
                child: Row(
                  children: [
                    if (isSelected)
                      const Icon(
                        Icons.check_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      )
                    else
                      const SizedBox(width: 20),
                    const SizedBox(width: AppTheme.spaceXs),
                    Text(
                      displayName,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? AppTheme.primaryColor : null,
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
        );
      },
    );
  }
}
