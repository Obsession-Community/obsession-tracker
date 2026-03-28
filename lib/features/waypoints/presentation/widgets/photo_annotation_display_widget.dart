import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/photo_metadata.dart';
import 'package:obsession_tracker/core/models/photo_waypoint.dart';

/// Widget for displaying photo annotations in a clean, readable format
class PhotoAnnotationDisplayWidget extends ConsumerWidget {
  const PhotoAnnotationDisplayWidget({
    required this.photo,
    required this.annotations,
    super.key,
    this.onEdit,
    this.onDelete,
    this.showEditButton = true,
    this.showDeleteButton = false,
    this.compact = false,
  });

  final PhotoWaypoint photo;
  final List<PhotoMetadata> annotations;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool showEditButton;
  final bool showDeleteButton;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (annotations.isEmpty) {
      return _buildEmptyState(context);
    }

    final Map<String, PhotoMetadata> annotationMap = {
      for (final annotation in annotations) annotation.key: annotation,
    };

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context, annotationMap),
          if (!compact) ...[
            const SizedBox(height: 12),
            _buildContent(context, annotationMap),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.note_add_outlined,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No annotations yet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
            ),
            if (showEditButton && onEdit != null)
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add'),
              ),
          ],
        ),
      );

  Widget _buildHeader(
      BuildContext context, Map<String, PhotoMetadata> annotationMap) {
    final bool isFavorite =
        annotationMap[CustomKeys.favorite]?.typedValue == true;
    final int rating =
        annotationMap[CustomKeys.rating]?.typedValue as int? ?? 0;

    return Row(
      children: [
        // Annotation icon and title
        Icon(
          Icons.edit_note,
          size: 18,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Text(
          'Photo Annotation',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),

        // Rating stars (if rated)
        if (rating > 0) ...[
          const SizedBox(width: 12),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
                5,
                (index) => Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      size: 14,
                      color: index < rating
                          ? Colors.amber
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withValues(alpha: 0.5),
                    )),
          ),
        ],

        // Favorite indicator
        if (isFavorite) ...[
          const SizedBox(width: 8),
          const Icon(
            Icons.favorite,
            size: 16,
            color: Colors.red,
          ),
        ],

        const Spacer(),

        // Action buttons
        if (showEditButton && onEdit != null)
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, size: 16),
            tooltip: 'Edit annotation',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        if (showDeleteButton && onDelete != null) ...[
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete, size: 16),
            color: Colors.red,
            tooltip: 'Delete annotation',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
          ),
        ],
      ],
    );
  }

  Widget _buildContent(
      BuildContext context, Map<String, PhotoMetadata> annotationMap) {
    final List<Widget> contentWidgets = <Widget>[];

    // User note
    final String? note = annotationMap[CustomKeys.userNote]?.value;
    if (note != null && note.isNotEmpty) {
      contentWidgets.add(_buildNoteSection(context, note));
    }

    // Tags
    final String? tags = annotationMap[CustomKeys.tags]?.value;
    if (tags != null && tags.isNotEmpty) {
      contentWidgets.add(_buildTagsSection(context, tags));
    }

    // Weather
    final String? weather = annotationMap[CustomKeys.weatherConditions]?.value;
    if (weather != null && weather.isNotEmpty) {
      contentWidgets.add(_buildInfoSection(
          context, 'Weather', weather, Icons.wb_sunny_outlined));
    }

    // Companions
    final String? companions = annotationMap[CustomKeys.companions]?.value;
    if (companions != null && companions.isNotEmpty) {
      contentWidgets.add(_buildInfoSection(
          context, 'Companions', companions, Icons.people_outline));
    }

    if (contentWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets
          .expand((widget) => [widget, const SizedBox(height: 12)])
          .take(contentWidgets.length * 2 - 1)
          .toList(),
    );
  }

  Widget _buildNoteSection(BuildContext context, String note) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.note_alt_outlined,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Note',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              note,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );

  Widget _buildTagsSection(BuildContext context, String tagsString) {
    final List<String> tagList = tagsString
        .split(',')
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();

    if (tagList.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.label_outline,
              size: 16,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              'Tags',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tagList.map((tag) => _buildTag(context, tag)).toList(),
        ),
      ],
    );
  }

  Widget _buildTag(BuildContext context, String tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          tag,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
        ),
      );

  Widget _buildInfoSection(
          BuildContext context, String title, String value, IconData icon) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            '$title:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      );
}

/// Compact version for use in photo galleries
class CompactPhotoAnnotationWidget extends StatelessWidget {
  const CompactPhotoAnnotationWidget({
    required this.annotations,
    super.key,
    this.onTap,
  });

  final List<PhotoMetadata> annotations;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (annotations.isEmpty) {
      return const SizedBox.shrink();
    }

    final Map<String, PhotoMetadata> annotationMap = {
      for (final annotation in annotations) annotation.key: annotation,
    };

    final bool isFavorite =
        annotationMap[CustomKeys.favorite]?.typedValue == true;
    final int rating =
        annotationMap[CustomKeys.rating]?.typedValue as int? ?? 0;
    final bool hasNote =
        annotationMap[CustomKeys.userNote]?.value?.isNotEmpty == true;
    final bool hasTags =
        annotationMap[CustomKeys.tags]?.value?.isNotEmpty == true;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasNote)
              const Icon(
                Icons.note_alt,
                size: 12,
                color: Colors.white,
              ),
            if (hasNote && (isFavorite || rating > 0 || hasTags))
              const SizedBox(width: 4),
            if (isFavorite)
              const Icon(
                Icons.favorite,
                size: 12,
                color: Colors.red,
              ),
            if (isFavorite && (rating > 0 || hasTags)) const SizedBox(width: 4),
            if (rating > 0) ...[
              const Icon(
                Icons.star,
                size: 12,
                color: Colors.amber,
              ),
              if (hasTags) const SizedBox(width: 4),
            ],
            if (hasTags)
              const Icon(
                Icons.label,
                size: 12,
                color: Colors.white,
              ),
          ],
        ),
      ),
    );
  }
}
