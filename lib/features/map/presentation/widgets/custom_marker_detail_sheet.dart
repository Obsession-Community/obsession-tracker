import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/custom_marker.dart';
import 'package:obsession_tracker/core/models/marker_attachment.dart';
import 'package:obsession_tracker/core/providers/custom_markers_provider.dart';
import 'package:obsession_tracker/features/map/presentation/pages/marker_attachment_viewer.dart';

/// Bottom sheet that displays details about a tapped custom marker (view-only)
class CustomMarkerDetailSheet extends ConsumerWidget {
  const CustomMarkerDetailSheet({
    super.key,
    required this.marker,
    this.onNavigate,
    this.onEdit,
    this.onDelete,
  });

  final CustomMarker marker;
  final VoidCallback? onNavigate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final category = marker.category;

    // Watch attachments for this marker
    final attachmentsAsync = ref.watch(markerAttachmentsProvider(marker.id));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header with category icon and name
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Category icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: marker.effectiveColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      category.emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Name and category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        marker.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: marker.effectiveColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category.displayName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.white70
                                : marker.effectiveColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Notes section (if present)
          if (marker.notes != null && marker.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  marker.notes!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),

          // Coordinates
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${marker.latitude.toStringAsFixed(6)}, ${marker.longitude.toStringAsFixed(6)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(
                        text: '${marker.latitude}, ${marker.longitude}',
                      ),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Coordinates copied to clipboard'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Copy coordinates',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Attachments section (read-only display)
          attachmentsAsync.when(
            data: (attachments) => _buildAttachmentsSection(context, ref, attachments),
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Navigate button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.near_me),
                    label: const Text('Navigate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Edit button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 8),
                // Delete button
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  tooltip: 'Delete marker',
                ),
              ],
            ),
          ),

          // Bottom padding for safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(
    BuildContext context,
    WidgetRef ref,
    List<MarkerAttachment> attachments,
  ) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    // Separate images from other attachments
    final images = attachments
        .where((a) => a.type == MarkerAttachmentType.image)
        .toList();
    final others = attachments
        .where((a) => a.type != MarkerAttachmentType.image)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attachments (${attachments.length})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // Image gallery (tappable thumbnails)
          if (images.isNotEmpty) ...[
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final image = images[index];
                  return _ImageThumbnail(
                    attachment: image,
                    onTap: () async {
                      await showMarkerAttachmentViewer(
                        context,
                        attachment: image,
                        allAttachments: images,
                        initialIndex: index,
                      );
                      // Refresh attachments in case rotation was changed
                      ref.invalidate(markerAttachmentsProvider(marker.id));
                    },
                  );
                },
              ),
            ),
            if (others.isNotEmpty) const SizedBox(height: 8),
          ],

          // Other attachments as tappable chips
          if (others.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: others.map((attachment) {
                final index = attachments.indexOf(attachment);
                return ActionChip(
                  avatar: Text(attachment.type.icon),
                  label: Text(
                    attachment.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onPressed: () => showMarkerAttachmentViewer(
                    context,
                    attachment: attachment,
                    allAttachments: attachments,
                    initialIndex: index,
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Image thumbnail for detail sheet (view-only, no delete button)
class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    required this.attachment,
    required this.onTap,
  });

  final MarkerAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filePath = attachment.thumbnailPath ?? attachment.filePath;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: filePath != null
            ? _buildRotatedImage(filePath)
            : const Center(
                child: Icon(
                  Icons.image,
                  color: Colors.grey,
                ),
              ),
      ),
    );
  }

  Widget _buildRotatedImage(String filePath) {
    Widget imageWidget = Image.file(
      File(filePath),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return const Center(
          child: Icon(
            Icons.broken_image,
            color: Colors.grey,
          ),
        );
      },
    );

    // Apply rotation if needed
    final rotation = attachment.userRotation;
    if (rotation != null && rotation != 0) {
      imageWidget = RotatedBox(
        quarterTurns: rotation,
        child: imageWidget,
      );
    }

    return imageWidget;
  }
}

/// Helper function to show the custom marker detail sheet
Future<void> showCustomMarkerDetailSheet(
  BuildContext context,
  WidgetRef ref,
  CustomMarker marker, {
  VoidCallback? onNavigate,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CustomMarkerDetailSheet(
      marker: marker,
      onNavigate: onNavigate ?? () => Navigator.pop(context),
      onEdit: onEdit ?? () => Navigator.pop(context),
      onDelete: onDelete ?? () => Navigator.pop(context),
    ),
  );
}
