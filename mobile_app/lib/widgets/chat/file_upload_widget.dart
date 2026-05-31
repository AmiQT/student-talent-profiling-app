import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/app_theme.dart';

/// Widget for uploading files to chat (images, PDFs, audio, video)
class FileUploadWidget extends StatefulWidget {
  final Function(List<File>) onFilesSelected;
  final bool enabled;

  const FileUploadWidget({
    super.key,
    required this.onFilesSelected,
    this.enabled = true,
  });

  @override
  State<FileUploadWidget> createState() => _FileUploadWidgetState();
}

class _FileUploadWidgetState extends State<FileUploadWidget> {
  final ImagePicker _picker = ImagePicker();
  final List<File> _selectedFiles = [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Selected files preview
        if (_selectedFiles.isNotEmpty) _buildFilePreview(),

        // Upload buttons
        _buildUploadButtons(),
      ],
    );
  }

  Widget _buildFilePreview() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _selectedFiles.length,
        itemBuilder: (context, index) {
          final file = _selectedFiles[index];
          return _buildFilePreviewItem(file, index);
        },
      ),
    );
  }

  Widget _buildFilePreviewItem(File file, int index) {
    final fileName = file.path.split('/').last;
    final isImage = _isImageFile(fileName);

    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Stack(
        children: [
          // File content
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isImage
                ? Image.file(
                    file,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  )
                : _buildFileIcon(fileName),
          ),

          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeFile(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileIcon(String fileName) {
    IconData icon;
    Color color;

    if (fileName.toLowerCase().endsWith('.pdf')) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (fileName.toLowerCase().endsWith('.mp3') ||
        fileName.toLowerCase().endsWith('.wav')) {
      icon = Icons.audiotrack;
      color = Colors.orange;
    } else if (fileName.toLowerCase().endsWith('.mp4') ||
        fileName.toLowerCase().endsWith('.mov')) {
      icon = Icons.videocam;
      color = Colors.blue;
    } else {
      icon = Icons.insert_drive_file;
      color = Colors.grey;
    }

    return SizedBox(
      width: 80,
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 4),
          Text(
            fileName.length > 10 ? '${fileName.substring(0, 7)}...' : fileName,
            style: const TextStyle(fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButtons() {
    return Row(
      children: [
        // Camera button
        IconButton(
          onPressed: widget.enabled ? _pickImageFromCamera : null,
          icon: Icon(
            Icons.camera_alt,
            color: widget.enabled ? AppTheme.primaryColor : Colors.grey,
          ),
          tooltip: 'Take Photo',
        ),

        // Gallery button
        IconButton(
          onPressed: widget.enabled ? _pickImageFromGallery : null,
          icon: Icon(
            Icons.photo_library,
            color: widget.enabled ? AppTheme.primaryColor : Colors.grey,
          ),
          tooltip: 'Choose Image',
        ),

        // File picker button
        IconButton(
          onPressed: widget.enabled ? _pickFile : null,
          icon: Icon(
            Icons.attach_file,
            color: widget.enabled ? AppTheme.primaryColor : Colors.grey,
          ),
          tooltip: 'Attach File',
        ),

        // Clear all button
        if (_selectedFiles.isNotEmpty)
          IconButton(
            onPressed: _clearAllFiles,
            icon: const Icon(
              Icons.clear_all,
              color: Colors.red,
            ),
            tooltip: 'Clear All',
          ),
      ],
    );
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        _addFile(File(image.path));
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      for (final image in images) {
        _addFile(File(image.path));
      }
    } catch (e) {
      _showError('Failed to pick images: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'txt',
          'mp3',
          'wav',
          'mp4',
          'mov'
        ],
        allowMultiple: true,
      );

      if (result != null) {
        for (final file in result.files) {
          if (file.path != null) {
            _addFile(File(file.path!));
          }
        }
      }
    } catch (e) {
      _showError('Failed to pick files: $e');
    }
  }

  void _addFile(File file) {
    if (_selectedFiles.length >= 5) {
      _showError('Maximum 5 files allowed');
      return;
    }

    setState(() {
      _selectedFiles.add(file);
    });

    widget.onFilesSelected(_selectedFiles);
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });

    widget.onFilesSelected(_selectedFiles);
  }

  void _clearAllFiles() {
    setState(() {
      _selectedFiles.clear();
    });

    widget.onFilesSelected(_selectedFiles);
  }

  bool _isImageFile(String fileName) {
    final extension = fileName.toLowerCase();
    return extension.endsWith('.jpg') ||
        extension.endsWith('.jpeg') ||
        extension.endsWith('.png') ||
        extension.endsWith('.gif') ||
        extension.endsWith('.webp');
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
