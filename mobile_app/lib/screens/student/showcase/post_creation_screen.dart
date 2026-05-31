// dart:io removed - not compatible with Flutter Web
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../models/showcase_models.dart';
import '../../../models/post_creation_models.dart';
import '../../../models/user_model.dart';
import '../../../models/profile_model.dart';
import '../../../services/media_upload_manager.dart';
import '../../../services/supabase_auth_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/content_moderation_service.dart';
import '../../../services/showcase_service.dart';

class PostCreationScreen extends StatefulWidget {
  final PostDraft? draft;
  final PostTemplate? template;
  final ShowcasePostModel? editingPost;
  final VoidCallback?
      onPostCreated; // Callback when post is successfully created

  const PostCreationScreen({
    super.key,
    this.draft,
    this.template,
    this.editingPost,
    this.onPostCreated,
  });

  @override
  State<PostCreationScreen> createState() => _PostCreationScreenState();
}

class _PostCreationScreenState extends State<PostCreationScreen>
    with TickerProviderStateMixin {
  // Controllers and managers
  final TextEditingController _contentController = TextEditingController();
  final MediaUploadManager _uploadManager = MediaUploadManager();
  final ImagePicker _imagePicker = ImagePicker();
  final ProfileService _profileService = ProfileService();

  // Animation controllers
  late AnimationController _uploadAnimationController;
  late AnimationController _successAnimationController;

  // State variables
  String? _uploadSessionId;
  final List<XFile> _selectedMedia = [];
  final Map<String, Uint8List> _mediaBytes = {}; // Cache for display
  PostCategory _selectedCategory = PostCategory.general;
  PostPrivacy _selectedPrivacy = PostPrivacy.public;
  List<String> _tags = [];
  final List<MentionModel> _mentions = [];
  String? _location;
  bool _isUploading = false;
  bool _hasUnsavedChanges = false;
  String? _error;
  Timer? _autoSaveTimer;

  // User data
  UserModel? _currentUser;
  ProfileModel? _currentProfile;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _initializeFromDraftOrTemplate();
    _setupAutoSave();
    _contentController.addListener(_onContentChanged);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _uploadAnimationController.dispose();
    _successAnimationController.dispose();
    _autoSaveTimer?.cancel();
    if (_uploadSessionId != null) {
      _uploadManager.cleanupSession(_uploadSessionId!);
    }
    super.dispose();
  }

  void _initializeAnimations() {
    _uploadAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _successAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
  }

  Future<void> _loadUserData() async {
    try {
      final authService =
          Provider.of<SupabaseAuthService>(context, listen: false);
      _currentUser = authService.currentUser;

      // If currentUser is null, try to initialize AuthService again
      if (_currentUser == null) {
        debugPrint(
            'PostCreation: Current user is null, reinitializing AuthService...');
        await authService.initialize();
        _currentUser = authService.currentUser;
      }

      if (_currentUser != null) {
        debugPrint(
            'PostCreation: Loading profile for user: ${_currentUser!.name}');
        _currentProfile =
            await _profileService.getProfileByUserId(_currentUser!.uid);
      } else {
        debugPrint(
            'PostCreation: Warning - Current user is still null after initialization');
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  void _initializeFromDraftOrTemplate() {
    if (widget.editingPost != null) {
      // Initialize for editing mode
      _contentController.text = widget.editingPost!.content;
      _selectedCategory = widget.editingPost!.category;
      _selectedPrivacy = widget.editingPost!.privacy;
      _tags = List.from(widget.editingPost!.tags);
      _location = widget.editingPost!.location;
      // Note: Media files will need to be handled separately for editing
    } else if (widget.draft != null) {
      _contentController.text = widget.draft!.content;
      _selectedCategory = widget.draft!.category;
      _selectedPrivacy = widget.draft!.privacy;
      _tags = List.from(widget.draft!.tags);
      _location = widget.draft!.location;
      // Load media files from paths if needed
    } else if (widget.template != null) {
      _contentController.text = widget.template!.content;
      _selectedCategory = widget.template!.category;
      _tags = List.from(widget.template!.suggestedTags);
    } else {
      // Try to load saved draft
      _loadSavedDraft();
    }
  }

  Future<void> _loadSavedDraft() async {
    try {
      if (_currentUser == null) return;

      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'draft_${_currentUser!.uid}';
      final draftJson = prefs.getString(draftKey);

      if (draftJson != null) {
        final draftData = jsonDecode(draftJson) as Map<String, dynamic>;
        final content = draftData['content'] as String? ?? '';

        if (content.isNotEmpty) {
          // Show dialog asking if user wants to restore draft
          if (mounted) {
            final shouldRestore = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Restore Draft'),
                content: const Text(
                    'You have a saved draft. Would you like to restore it?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Discard'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Restore'),
                  ),
                ],
              ),
            );

            if (shouldRestore == true) {
              _contentController.text = content;
              _selectedCategory = PostCategory.values.firstWhere(
                (cat) => cat.toString() == draftData['category'],
                orElse: () => PostCategory.general,
              );
              _selectedPrivacy = PostPrivacy.values.firstWhere(
                (priv) => priv.toString() == draftData['privacy'],
                orElse: () => PostPrivacy.public,
              );
              _tags = List<String>.from(draftData['tags'] ?? []);
              _location = draftData['location'] as String?;

              setState(() {
                _hasUnsavedChanges = true;
              });
            } else {
              // Clear the draft if user chooses to discard
              await prefs.remove(draftKey);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading saved draft: $e');
    }
  }

  Future<void> _clearSavedDraft() async {
    try {
      if (_currentUser == null) return;

      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'draft_${_currentUser!.uid}';
      await prefs.remove(draftKey);
      debugPrint('Saved draft cleared');
    } catch (e) {
      debugPrint('Error clearing saved draft: $e');
    }
  }

  void _setupAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasUnsavedChanges && !_isUploading) {
        _saveDraft();
      }
    });
  }

  void _onContentChanged() {
    setState(() {
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _saveDraft() async {
    try {
      if (_currentUser == null) {
        debugPrint('Cannot save draft: no current user');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final draftKey = 'draft_${_currentUser!.uid}';

      final draftData = {
        'content': _contentController.text,
        'category': _selectedCategory.toString(),
        'privacy': _selectedPrivacy.toString(),
        'tags': _tags,
        'location': _location,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await prefs.setString(draftKey, jsonEncode(draftData));

      setState(() {
        _hasUnsavedChanges = false;
      });

      debugPrint('Draft saved successfully');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft saved'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving draft: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save draft: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final navigator = Navigator.of(context);
          final shouldPop = await _onWillPop();
          if (shouldPop) {
            if (mounted) {
              navigator.pop();
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: _buildAppBar(),
        body: _buildBody(),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        widget.editingPost != null ? 'Edit Post' : 'Create Post',
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () async {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
      actions: [
        if (_hasUnsavedChanges)
          TextButton(
            onPressed: _saveDraft,
            child: const Text('Save Draft'),
          ),
        TextButton(
          onPressed: _canPost() ? _savePost : null,
          child: Text(
            widget.editingPost != null ? 'Update' : 'Post',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _canPost() ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info header
          _buildUserHeader(),
          const SizedBox(height: 16),

          // Content input
          _buildContentInput(),
          const SizedBox(height: 16),

          // Media preview
          if (_selectedMedia.isNotEmpty) ...[
            _buildMediaPreview(),
            const SizedBox(height: 16),
          ],

          // Upload progress
          if (_isUploading) ...[
            _buildUploadProgress(),
            const SizedBox(height: 16),
          ],

          // Category and privacy selectors
          _buildCategoryAndPrivacy(),
          const SizedBox(height: 16),

          // Tags input
          _buildTagsInput(),
          const SizedBox(height: 16),

          // Location input
          _buildLocationInput(),
          const SizedBox(height: 16),

          // Post preview
          if (_canPreview()) ...[
            _buildPostPreview(),
            const SizedBox(height: 16),
          ],

          // Error display
          if (_error != null) ...[
            _buildErrorDisplay(),
            const SizedBox(height: 16),
          ],

          // Templates
          _buildTemplateSelector(),

          const SizedBox(height: 100), // Bottom padding for FAB
        ],
      ),
    );
  }

  ImageProvider<Object>? _profileImageProvider(String? url) {
    if (url == null || url.trim().isEmpty || url == 'file:///') return null;
    try {
      if (url.startsWith('data:image')) {
        final base64String = url.split(',')[1];
        return MemoryImage(base64Decode(base64String)) as ImageProvider<Object>;
      }
      // Only use NetworkImage for http/https URLs (web-compatible)
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return NetworkImage(url) as ImageProvider<Object>;
      }
      // Local paths don't work on web, return null to show fallback avatar
    } catch (e) {
      debugPrint('PostCreation: Invalid profile image URL: $url ($e)');
    }
    return null;
  }

  Widget _buildUserHeader() {
    if (_currentUser == null) {
      debugPrint(
          'PostCreation: _buildUserHeader called but _currentUser is null');
      return const SizedBox.shrink();
    }

    debugPrint('PostCreation: Building user header for: ${_currentUser!.name}');

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage:
              _profileImageProvider(_currentProfile?.profileImageUrl),
          backgroundColor:
              Theme.of(context).primaryColor.withValues(alpha: 0.1),
          child: (_currentProfile?.profileImageUrl == null ||
                  _currentProfile!.profileImageUrl!.trim().isEmpty)
              ? Text(
                  _currentUser!.name[0].toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentUser!.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                _currentUser!.role.toString().split('.').last.toUpperCase(),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContentInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          TextField(
            controller: _contentController,
            maxLines: null,
            minLines: 4,
            decoration: const InputDecoration(
              hintText: 'What would you like to showcase?',
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(16),
            ),
            style: const TextStyle(fontSize: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_contentController.text.length}/2000',
                  style: TextStyle(
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color
                        ?.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.photo_library, size: 20),
                      onPressed: _pickImages,
                      tooltip: 'Add Photos',
                    ),
                    IconButton(
                      icon: const Icon(Icons.videocam, size: 20),
                      onPressed: _pickVideo,
                      tooltip: 'Add Video',
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt, size: 20),
                      onPressed: _takePhoto,
                      tooltip: 'Take Photo',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Media (${_selectedMedia.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedMedia.clear();
                    _error = null; // Clear any previous errors
                  });
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedMedia.length,
              onReorder: _reorderMedia,
              itemBuilder: (context, index) {
                final file = _selectedMedia[index];
                return _buildMediaThumbnail(file, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaThumbnail(XFile file, int index) {
    final isVideo = file.path.toLowerCase().contains('.mp4') ||
        file.path.toLowerCase().contains('.mov');
    final bytes = _mediaBytes[file.path];

    return Container(
      key: ValueKey(file.path),
      margin: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: isVideo
                  ? Container(
                      color: Colors.black,
                      child: const Icon(
                        Icons.play_circle_fill,
                        color: Colors.white,
                        size: 40,
                      ),
                    )
                  : bytes != null
                      ? Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                        )
                      : const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeMedia(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
          if (isVideo)
            const Positioned(
              bottom: 4,
              left: 4,
              child: Icon(
                Icons.videocam,
                color: Colors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadProgress() {
    if (_uploadSessionId == null) return const SizedBox.shrink();

    return StreamBuilder<PostCreationState>(
      stream: _uploadManager.getUploadStateStream(_uploadSessionId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final state = snapshot.data!;
        return Container(
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_upload, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Text(
                    'Uploading...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text('${(state.uploadProgress * 100).toInt()}%'),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: state.uploadProgress,
                backgroundColor: Colors.blue[100],
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 8),
              Text(
                'Uploading ${state.selectedMedia.length} file(s)...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryAndPrivacy() {
    return Row(
      children: [
        Expanded(
          child: _buildCategorySelector(),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPrivacySelector(),
        ),
      ],
    );
  }

  Widget _buildCategorySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PostCategory>(
          value: _selectedCategory,
          isExpanded: true,
          hint: const Text('Category'),
          items: PostCategory.values.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Text(_getCategoryDisplayName(category)),
            );
          }).toList(),
          onChanged: (category) {
            if (category != null) {
              setState(() {
                _selectedCategory = category;
                _hasUnsavedChanges = true;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildPrivacySelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PostPrivacy>(
          value: _selectedPrivacy,
          isExpanded: true,
          hint: const Text('Privacy'),
          items: PostPrivacy.values.map((privacy) {
            return DropdownMenuItem(
              value: privacy,
              child: Row(
                children: [
                  Icon(_getPrivacyIcon(privacy), size: 16),
                  const SizedBox(width: 8),
                  Text(_getPrivacyDisplayName(privacy)),
                ],
              ),
            );
          }).toList(),
          onChanged: (privacy) {
            if (privacy != null) {
              setState(() {
                _selectedPrivacy = privacy;
                _hasUnsavedChanges = true;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildTagsInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tags',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._tags.map((tag) => Chip(
                    label: Text('#$tag'),
                    onDeleted: () => _removeTag(tag),
                    backgroundColor: Colors.blue[50],
                  )),
              ActionChip(
                label: const Text('+ Add Tag'),
                onPressed: _showAddTagDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ListTile(
        leading: const Icon(Icons.location_on),
        title: Text(_location ?? 'Add location'),
        trailing: _location != null
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() => _location = null),
              )
            : const Icon(Icons.chevron_right),
        onTap: _showLocationPicker,
      ),
    );
  }

  Widget _buildPostPreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Preview',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // This would show a preview of the post
          Text(
            _contentController.text.isNotEmpty
                ? _contentController.text
                : 'Your post content will appear here...',
            style: TextStyle(
              color: _contentController.text.isNotEmpty
                  ? Colors.black87
                  : Colors.grey[500],
            ),
          ),
          if (_selectedMedia.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${_selectedMedia.length} media file(s) attached',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorDisplay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _error = null;
                _isUploading = false; // Reset upload state if needed
              });
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplateSelector() {
    final templates = PostTemplate.getDefaultTemplates();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Templates',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(template.title),
                    onPressed: () => _applyTemplate(template),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saveDraft,
                child: const Text('Save Draft'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _canPost() ? _savePost : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Media picker methods
  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();
      if (images.isNotEmpty) {
        for (final image in images) {
          final bytes = await image.readAsBytes();
          _mediaBytes[image.path] = bytes;
        }
        setState(() {
          _selectedMedia.addAll(images);
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      _showError('Error picking images: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video =
          await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        // For videos, we don't need to load bytes for preview (just show icon)
        setState(() {
          _selectedMedia.add(video);
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      _showError('Error picking video: $e');
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo =
          await _imagePicker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        _mediaBytes[photo.path] = bytes;
        setState(() {
          _selectedMedia.add(photo);
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      _showError('Error taking photo: $e');
    }
  }

  void _reorderMedia(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final file = _selectedMedia.removeAt(oldIndex);
      _selectedMedia.insert(newIndex, file);
      _hasUnsavedChanges = true;
    });
  }

  void _removeMedia(int index) {
    setState(() {
      final removed = _selectedMedia.removeAt(index);
      _mediaBytes.remove(removed.path); // Clean up cached bytes
      _hasUnsavedChanges = true;
    });
  }

  // Helper methods
  String _getCategoryDisplayName(PostCategory category) {
    switch (category) {
      case PostCategory.academic:
        return 'Academic';
      case PostCategory.creative:
        return 'Creative';
      case PostCategory.technical:
        return 'Technical';
      case PostCategory.sports:
        return 'Sports';
      case PostCategory.volunteer:
        return 'Volunteer';
      case PostCategory.achievement:
        return 'Achievement';
      case PostCategory.project:
        return 'Project';
      case PostCategory.general:
        return 'General';
    }
  }

  IconData _getPrivacyIcon(PostPrivacy privacy) {
    switch (privacy) {
      case PostPrivacy.public:
        return Icons.public;
      case PostPrivacy.department:
        return Icons.business;
      case PostPrivacy.friends:
        return Icons.people;
    }
  }

  String _getPrivacyDisplayName(PostPrivacy privacy) {
    switch (privacy) {
      case PostPrivacy.public:
        return 'Public';
      case PostPrivacy.department:
        return 'Department';
      case PostPrivacy.friends:
        return 'Friends';
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _hasUnsavedChanges = true;
    });
  }

  void _showAddTagDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String newTag = '';
        return AlertDialog(
          title: const Text('Add Tag'),
          content: TextField(
            onChanged: (value) => newTag = value,
            decoration: const InputDecoration(
              hintText: 'Enter tag name',
              prefixText: '#',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (newTag.isNotEmpty && !_tags.contains(newTag)) {
                  setState(() {
                    _tags.add(newTag);
                    _hasUnsavedChanges = true;
                  });
                }
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationPicker() {
    showDialog(
      context: context,
      builder: (context) {
        String newLocation = _location ?? '';
        return AlertDialog(
          title: const Text('Add Location'),
          content: TextField(
            onChanged: (value) => newLocation = value,
            decoration: const InputDecoration(
              hintText: 'Enter location',
            ),
            controller: TextEditingController(text: _location),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _location = newLocation.isNotEmpty ? newLocation : null;
                  _hasUnsavedChanges = true;
                });
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _applyTemplate(PostTemplate template) {
    setState(() {
      _contentController.text = template.content;
      _selectedCategory = template.category;
      _tags = List.from(template.suggestedTags);
      _hasUnsavedChanges = true;
    });
  }

  Future<bool> _showContentWarnings(List<String> warnings) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[600]),
                const SizedBox(width: 8),
                const Text('Content Warning'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'We noticed some potential issues with your content:'),
                const SizedBox(height: 12),
                ...warnings.map((warning) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(warning)),
                        ],
                      ),
                    )),
                const SizedBox(height: 12),
                const Text('Would you like to continue posting anyway?'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Edit Content'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // Core functionality methods
  bool _canPost() {
    return (_contentController.text.trim().isNotEmpty ||
            _selectedMedia.isNotEmpty) &&
        !_isUploading &&
        _currentUser != null;
  }

  bool _canPreview() {
    return _contentController.text.trim().isNotEmpty ||
        _selectedMedia.isNotEmpty;
  }

  Future<void> _savePost() async {
    if (!_canPost()) return;

    // Validate content before posting
    final moderationService = ContentModerationService();
    final validation = moderationService.validateContentDetailed(
      content: _contentController.text.trim(),
      mediaUrls: _selectedMedia.map((f) => f.path).toList(),
    );

    if (!validation['isValid']) {
      setState(() {
        _error =
            'Content validation failed: ${validation['issues'].join(', ')}';
      });
      return;
    }

    // Show warnings if any
    if (validation['warnings'].isNotEmpty) {
      final shouldContinue = await _showContentWarnings(validation['warnings']);
      if (!shouldContinue) return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      _uploadSessionId = _uploadManager.startUploadSession();
      _uploadAnimationController.forward();

      debugPrint('PostCreation: Creating post with user data:');
      debugPrint('  - User ID: ${_currentUser!.uid}');
      debugPrint('  - User Name: ${_currentUser!.name}');
      debugPrint(
          '  - User Role: ${_currentUser!.role.toString().split('.').last}');
      debugPrint('  - User Department: ${_currentUser!.department}');

      if (widget.editingPost != null) {
        // Update existing post
        await _updateExistingPost();
      } else {
        // Create new post
        final result = await _uploadManager.uploadPostWithXFiles(
          sessionId: _uploadSessionId!,
          userId: _currentUser!.uid,
          userName: _currentUser!.name,
          userProfileImage: _currentProfile?.profileImageUrl,
          userRole: _currentUser!.role.toString().split('.').last,
          userDepartment: _currentUser!.department,
          userHeadline: _currentProfile?.headline,
          content: _contentController.text.trim(),
          mediaFiles: _selectedMedia,
          category: _selectedCategory,
          privacy: _selectedPrivacy,
          tags: _tags,
          mentions: _mentions,
          location: _location,
        );

        if (result.success) {
          debugPrint(
              'PostCreation: Post created successfully! Post ID: ${result.postId}');

          // Clear saved draft on successful post creation
          await _clearSavedDraft();
          _successAnimationController.forward();
          _showSuccessDialog(result.postId!);
        } else {
          debugPrint('PostCreation: Post creation failed: ${result.error}');
          _showError(result.error ?? 'Failed to create post');
        }
      }
    } catch (e) {
      _showError('Error creating post: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
      _uploadAnimationController.reverse();
    }
  }

  Future<void> _updateExistingPost() async {
    try {
      final showcaseService = ShowcaseService();

      // Create updated post data
      final updatedData = {
        'content': _contentController.text.trim(),
        'category': _selectedCategory.toString().split('.').last,
        'privacy': _selectedPrivacy.toString().split('.').last,
        'tags': _tags,
        'location': _location,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Update the post in Firestore
      await showcaseService.updatePost(widget.editingPost!.id, updatedData);

      // Show success message
      _successAnimationController.forward();
      _showSuccessDialog(widget.editingPost!.id, isUpdate: true);
    } catch (e) {
      _showError('Failed to update post: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _error = message;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.white,
          onPressed: () => setState(() => _error = null),
        ),
      ),
    );
  }

  void _showSuccessDialog(String postId, {bool isUpdate = false}) {
    // Capture the PARENT context BEFORE showing dialog
    final parentNavigator = Navigator.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            Text(isUpdate ? 'Post Updated!' : 'Post Created!'),
          ],
        ),
        content: Text(isUpdate
            ? 'Your post has been successfully updated.'
            : 'Your post has been successfully created and shared.'),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('PostCreation: Done button pressed, returning true');
              Navigator.pop(dialogContext); // Close dialog using dialog context
              parentNavigator
                  .pop(true); // Close creation screen using parent context
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint(
                  'PostCreation: View Post button pressed, returning true');
              Navigator.pop(dialogContext); // Close dialog using dialog context
              parentNavigator
                  .pop(true); // Close creation screen using parent context
            },
            child: const Text('View Post'),
          ),
        ],
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
            'You have unsaved changes. Do you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _saveDraft();
              if (mounted) {
                navigator.pop(true);
              }
            },
            child: const Text('Save Draft'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
