import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/providers/hunt_provider.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';

/// Dialog for creating or editing a treasure hunt.
class CreateHuntDialog extends ConsumerStatefulWidget {
  const CreateHuntDialog({
    super.key,
    this.existingHunt,
  });

  /// If provided, the dialog will edit this hunt instead of creating a new one.
  final TreasureHunt? existingHunt;

  @override
  ConsumerState<CreateHuntDialog> createState() => _CreateHuntDialogState();
}

class _CreateHuntDialogState extends ConsumerState<CreateHuntDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagController = TextEditingController();

  final List<String> _tags = [];
  File? _coverImage;
  bool _isLoading = false;

  bool get _isEditing => widget.existingHunt != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.existingHunt!.name;
      _authorController.text = widget.existingHunt!.author ?? '';
      _descriptionController.text = widget.existingHunt!.description ?? '';
      _tags.addAll(widget.existingHunt!.tags);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(_isEditing ? 'Edit Hunt' : 'New Treasure Hunt'),
            centerTitle: true,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cover image picker
                  _buildCoverImagePicker(),
                  const SizedBox(height: 20),

                  // Hunt name
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Hunt Name *',
                      hintText: 'e.g., Beyond the Maps Edge',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a hunt name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Author
                  TextFormField(
                    controller: _authorController,
                    decoration: InputDecoration(
                      labelText: 'Author/Creator',
                      hintText: 'e.g., Justin Posey',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Brief description of the hunt...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      prefixIcon: const Icon(Icons.notes),
                    ),
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),

                  // Tags
                  _buildTagsSection(),
                  const SizedBox(height: 24),

                  // Submit button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isEditing ? 'Save Changes' : 'Create Hunt',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImagePicker() {
    Widget imageWidget;

    if (_coverImage != null) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          _coverImage!,
          width: double.infinity,
          height: 150,
          fit: BoxFit.cover,
        ),
      );
    } else if (_isEditing && widget.existingHunt!.coverImagePath != null) {
      final file = File(widget.existingHunt!.coverImagePath!);
      if (file.existsSync()) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: double.infinity,
            height: 150,
            fit: BoxFit.cover,
          ),
        );
      } else {
        imageWidget = _buildImagePlaceholder();
      }
    } else {
      imageWidget = _buildImagePlaceholder();
    }

    return GestureDetector(
      onTap: _pickCoverImage,
      child: Stack(
        alignment: Alignment.center,
        children: [
          imageWidget,
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 150,
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 40,
            color: AppTheme.gold.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Add Cover Image',
            style: TextStyle(
              color: AppTheme.gold.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tag input
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _tagController,
                decoration: InputDecoration(
                  labelText: 'Tags',
                  hintText: 'Add tags to organize hunts',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.tag),
                ),
                textCapitalization: TextCapitalization.words,
                onFieldSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addTag,
              icon: const Icon(Icons.add_circle, color: AppTheme.gold),
              tooltip: 'Add Tag',
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _tags.map((tag) {
              return Chip(
                label: Text(tag),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () => _removeTag(tag),
                backgroundColor: AppTheme.gold.withValues(alpha: 0.15),
                labelStyle: const TextStyle(color: AppTheme.gold),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _coverImage = File(result.files.single.path!);
      });
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isEditing) {
        // Update existing hunt
        final updatedHunt = widget.existingHunt!.copyWith(
          name: _nameController.text.trim(),
          author: _authorController.text.trim().isEmpty
              ? null
              : _authorController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          tags: _tags,
        );

        await ref.read(huntProvider.notifier).updateHunt(
              updatedHunt,
              newCoverImage: _coverImage,
            );

        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        // Create new hunt
        final hunt = await ref.read(huntProvider.notifier).createHunt(
              name: _nameController.text.trim(),
              author: _authorController.text.trim().isEmpty
                  ? null
                  : _authorController.text.trim(),
              description: _descriptionController.text.trim().isEmpty
                  ? null
                  : _descriptionController.text.trim(),
              tags: _tags,
              coverImage: _coverImage,
            );

        if (mounted) {
          Navigator.pop(context, hunt);
        }
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
          _isLoading = false;
        });
      }
    }
  }
}
