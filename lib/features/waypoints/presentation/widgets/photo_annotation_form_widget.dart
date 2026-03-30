import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';

/// Form widget for adding and editing photo annotations
class PhotoAnnotationFormWidget extends ConsumerStatefulWidget {
  const PhotoAnnotationFormWidget({
    required this.photo,
    super.key,
    this.existingAnnotations = const <PhotoMetadata>[],
    this.onSave,
    this.onCancel,
    this.isEditing = false,
  });

  final PhotoWaypoint photo;
  final List<PhotoMetadata> existingAnnotations;
  final void Function(List<PhotoMetadata> annotations)? onSave;
  final VoidCallback? onCancel;
  final bool isEditing;

  @override
  ConsumerState<PhotoAnnotationFormWidget> createState() =>
      _PhotoAnnotationFormWidgetState();
}

class _PhotoAnnotationFormWidgetState
    extends ConsumerState<PhotoAnnotationFormWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _weatherController = TextEditingController();
  final TextEditingController _companionsController = TextEditingController();
  final FocusNode _noteFocusNode = FocusNode();

  bool _isFavorite = false;
  int _rating = 0;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _loadExistingAnnotations();
    _slideController.forward();
    _fadeController.forward();

    // Auto-focus on note field if not editing
    if (!widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _noteFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    _weatherController.dispose();
    _companionsController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  void _loadExistingAnnotations() {
    for (final annotation in widget.existingAnnotations) {
      switch (annotation.key) {
        case CustomKeys.userNote:
          _noteController.text = annotation.value ?? '';
          break;
        case CustomKeys.tags:
          _tagsController.text = annotation.value ?? '';
          break;
        case CustomKeys.rating:
          _rating = annotation.typedValue as int? ?? 0;
          break;
        case CustomKeys.favorite:
          _isFavorite = annotation.typedValue as bool? ?? false;
          break;
        case CustomKeys.weatherConditions:
          _weatherController.text = annotation.value ?? '';
          break;
        case CustomKeys.companions:
          _companionsController.text = annotation.value ?? '';
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _slideController,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 50 * (1 - _slideController.value)),
          child: FadeTransition(
            opacity: _fadeController,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(),
                  if (_error != null) _buildErrorBanner(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildForm(),
                    ),
                  ),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.edit_note,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isEditing ? 'Edit Annotation' : 'Add Annotation',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Photo taken ${_formatDateTime(widget.photo.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer
                              .withValues(alpha: 0.8),
                        ),
                  ),
                ],
              ),
            ),
            if (widget.onCancel != null)
              IconButton(
                onPressed: _isLoading ? null : widget.onCancel,
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
          ],
        ),
      );

  Widget _buildErrorBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _error = null),
              icon: Icon(
                Icons.close,
                color: Theme.of(context).colorScheme.onErrorContainer,
                size: 16,
              ),
            ),
          ],
        ),
      );

  Widget _buildForm() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Note field
          _buildSectionTitle('Note'),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            focusNode: _noteFocusNode,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Add your thoughts about this photo...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.note_alt_outlined),
            ),
          ),

          const SizedBox(height: 24),

          // Rating and favorite
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Rating'),
                    const SizedBox(height: 8),
                    _buildRatingSelector(),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('Favorite'),
                    const SizedBox(height: 8),
                    _buildFavoriteToggle(),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Tags field
          _buildSectionTitle('Tags'),
          const SizedBox(height: 8),
          TextField(
            controller: _tagsController,
            decoration: InputDecoration(
              hintText: 'adventure, sunset, wildlife (comma separated)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.label_outline),
            ),
          ),

          const SizedBox(height: 24),

          // Weather field
          _buildSectionTitle('Weather'),
          const SizedBox(height: 8),
          TextField(
            controller: _weatherController,
            decoration: InputDecoration(
              hintText: 'Sunny, 75°F, light breeze',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.wb_sunny_outlined),
            ),
          ),

          const SizedBox(height: 24),

          // Companions field
          _buildSectionTitle('Companions'),
          const SizedBox(height: 8),
          TextField(
            controller: _companionsController,
            decoration: InputDecoration(
              hintText: 'Who was with you?',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.people_outline),
            ),
          ),

          const SizedBox(height: 16),
        ],
      );

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      );

  Widget _buildRatingSelector() => Row(
        children: List.generate(5, (index) {
          final starIndex = index + 1;
          return GestureDetector(
            onTap: () => setState(() => _rating = starIndex),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Icon(
                starIndex <= _rating ? Icons.star : Icons.star_border,
                color: starIndex <= _rating
                    ? Colors.amber
                    : Theme.of(context).colorScheme.outline,
                size: 28,
              ),
            ),
          );
        }),
      );

  Widget _buildFavoriteToggle() => GestureDetector(
        onTap: () => setState(() => _isFavorite = !_isFavorite),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _isFavorite
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isFavorite
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _isFavorite ? 'Favorited' : 'Add to Favorites',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _isFavorite
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                      fontWeight: _isFavorite ? FontWeight.w600 : null,
                    ),
              ),
            ],
          ),
        ),
      );

  Widget _buildActionButtons() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius:
              const BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: Row(
          children: [
            if (widget.onCancel != null)
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
            if (widget.onCancel != null) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _isLoading ? null : _saveAnnotations,
                child: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.isEditing ? 'Update' : 'Save'),
              ),
            ),
          ],
        ),
      );

  Future<void> _saveAnnotations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final List<PhotoMetadata> annotations = <PhotoMetadata>[];
      final int timestamp = DateTime.now().millisecondsSinceEpoch;

      // Add note if provided
      if (_noteController.text.trim().isNotEmpty) {
        annotations.add(PhotoMetadata.string(
          id: timestamp + 1,
          photoWaypointId: widget.photo.id,
          key: CustomKeys.userNote,
          value: _noteController.text.trim(),
        ));
      }

      // Add tags if provided
      if (_tagsController.text.trim().isNotEmpty) {
        annotations.add(PhotoMetadata.string(
          id: timestamp + 2,
          photoWaypointId: widget.photo.id,
          key: CustomKeys.tags,
          value: _tagsController.text.trim(),
        ));
      }

      // Add rating if set
      if (_rating > 0) {
        annotations.add(PhotoMetadata.integer(
          id: timestamp + 3,
          photoWaypointId: widget.photo.id,
          key: CustomKeys.rating,
          value: _rating,
        ));
      }

      // Add favorite status
      annotations.add(PhotoMetadata.boolean(
        id: timestamp + 4,
        photoWaypointId: widget.photo.id,
        key: CustomKeys.favorite,
        value: _isFavorite,
      ));

      // Add weather if provided
      if (_weatherController.text.trim().isNotEmpty) {
        annotations.add(PhotoMetadata.string(
          id: timestamp + 5,
          photoWaypointId: widget.photo.id,
          key: CustomKeys.weatherConditions,
          value: _weatherController.text.trim(),
        ));
      }

      // Add companions if provided
      if (_companionsController.text.trim().isNotEmpty) {
        annotations.add(PhotoMetadata.string(
          id: timestamp + 6,
          photoWaypointId: widget.photo.id,
          key: CustomKeys.companions,
          value: _companionsController.text.trim(),
        ));
      }

      // Call the save callback
      if (widget.onSave != null) {
        widget.onSave!(annotations);
      }

      // Update the photo provider state
      // Note: In a real implementation, this would call a service method
      // to persist the annotations to the database
    } catch (e) {
      setState(() {
        _error = 'Failed to save annotations: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) =>
      '${dateTime.day}/${dateTime.month}/${dateTime.year} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')}';
}
