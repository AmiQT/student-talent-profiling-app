import 'package:flutter/material.dart';
import '../../models/report_model.dart';
import '../../models/showcase_models.dart';
import '../../models/user_model.dart';
import '../../services/content_moderation_service.dart';
import '../../utils/error_handler.dart';

class ReportDialog extends StatefulWidget {
  final ShowcasePostModel? post;
  final CommentModel? comment;
  final UserModel? reportedUser;
  final UserModel currentUser;

  const ReportDialog({
    super.key,
    this.post,
    this.comment,
    this.reportedUser,
    required this.currentUser,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final ContentModerationService _moderationService = ContentModerationService();
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();
  
  ReportType _selectedType = ReportType.inappropriateContent;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.report, color: Colors.red[600]),
          const SizedBox(width: 8),
          const Text('Report Content'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Help us understand what\'s happening with this ${_getContentTypeName()}.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            
            // Report type selection
            const Text(
              'What\'s the issue?',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            
            RadioGroup<ReportType>(
              groupValue: _selectedType,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedType = value;
                });
              },
              child: Column(
                children: ReportType.values
                    .map(
                      (type) => RadioListTile<ReportType>(
                        title: Text(_getReportTypeDisplayName(type)),
                        subtitle: Text(_getReportTypeDescription(type)),
                        value: type,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Reason field
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Brief reason *',
                hintText: 'Please provide a brief reason for reporting',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              maxLength: 200,
            ),
            
            const SizedBox(height: 16),
            
            // Additional details field
            TextField(
              controller: _detailsController,
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                hintText: 'Any additional context that might help us review this report',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            
            const SizedBox(height: 16),
            
            // Warning text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                border: Border.all(color: Colors.orange[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'False reports may result in restrictions on your account.',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }

  String _getContentTypeName() {
    if (widget.post != null) return 'post';
    if (widget.comment != null) return 'comment';
    if (widget.reportedUser != null) return 'user';
    return 'content';
  }

  String _getReportTypeDisplayName(ReportType type) {
    switch (type) {
      case ReportType.spam:
        return 'Spam';
      case ReportType.harassment:
        return 'Harassment or bullying';
      case ReportType.inappropriateContent:
        return 'Inappropriate content';
      case ReportType.falseInformation:
        return 'False information';
      case ReportType.copyright:
        return 'Copyright violation';
      case ReportType.other:
        return 'Other';
    }
  }

  String _getReportTypeDescription(ReportType type) {
    switch (type) {
      case ReportType.spam:
        return 'Unwanted commercial content or repetitive posts';
      case ReportType.harassment:
        return 'Bullying, threats, or targeted harassment';
      case ReportType.inappropriateContent:
        return 'Content that violates community guidelines';
      case ReportType.falseInformation:
        return 'Misleading or false information';
      case ReportType.copyright:
        return 'Unauthorized use of copyrighted material';
      case ReportType.other:
        return 'Something else that concerns you';
    }
  }

  Future<void> _submitReport() async {
    if (_reasonController.text.trim().isEmpty) {
      ErrorHandler.showErrorSnackBar(context, 'Please provide a reason for reporting');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      String contentId = '';
      String contentPreview = '';
      String reportedUserId = '';
      String reportedUserName = '';
      ReportedContentType contentType = ReportedContentType.post;

      if (widget.post != null) {
        contentId = widget.post!.id;
        contentPreview = widget.post!.content.length > 100 
            ? '${widget.post!.content.substring(0, 100)}...'
            : widget.post!.content;
        reportedUserId = widget.post!.userId;
        reportedUserName = widget.post!.userName;
        contentType = ReportedContentType.post;
      } else if (widget.comment != null) {
        contentId = widget.comment!.id;
        contentPreview = widget.comment!.content.length > 100
            ? '${widget.comment!.content.substring(0, 100)}...'
            : widget.comment!.content;
        reportedUserId = widget.comment!.userId;
        reportedUserName = widget.comment!.userName;
        contentType = ReportedContentType.comment;
      } else if (widget.reportedUser != null) {
        contentId = widget.reportedUser!.uid;
        contentPreview = 'User: ${widget.reportedUser!.name}';
        reportedUserId = widget.reportedUser!.uid;
        reportedUserName = widget.reportedUser!.name;
        contentType = ReportedContentType.user;
      }

      await _moderationService.submitReport(
        reporterId: widget.currentUser.uid,
        reporterName: widget.currentUser.name,
        reportedUserId: reportedUserId,
        reportedUserName: reportedUserName,
        contentType: contentType,
        contentId: contentId,
        contentPreview: contentPreview,
        type: _selectedType,
        reason: _reasonController.text.trim(),
        additionalDetails: _detailsController.text.trim().isNotEmpty 
            ? _detailsController.text.trim() 
            : null,
      );

      if (mounted) {
        Navigator.pop(context);
        ErrorHandler.showSuccessSnackBar(
          context,
          'Report submitted successfully. Thank you for helping keep our community safe.',
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showErrorSnackBar(
          context,
          'Failed to submit report: ${e.toString()}',
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
}
