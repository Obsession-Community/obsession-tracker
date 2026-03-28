import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/services/quadrangle_detection_service.dart';

/// A banner widget that suggests downloading a historical map quadrangle.
///
/// Displayed when the user is viewing an area where a quadrangle is available
/// but not yet downloaded. Uses purple theming consistent with historical maps.
class QuadSuggestionBanner extends StatelessWidget {
  const QuadSuggestionBanner({
    super.key,
    required this.suggestion,
    required this.onDownload,
    required this.onDismiss,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  /// The quadrangle suggestion to display
  final QuadrangleSuggestion suggestion;

  /// Called when the user taps the download button
  final VoidCallback onDownload;

  /// Called when the user dismisses the banner
  final VoidCallback onDismiss;

  /// Whether a download is currently in progress
  final bool isDownloading;

  /// Download progress (0.0 to 1.0) when downloading
  final double downloadProgress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.purple.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Map icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.map,
                  color: Colors.purple[700],
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      suggestion.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.purple[900],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${suggestion.subtitle} - ${suggestion.quad.formattedSize}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.purple[700],
                      ),
                    ),
                    if (isDownloading) ...[
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: downloadProgress,
                          backgroundColor: Colors.purple.withValues(alpha: 0.2),
                          valueColor: AlwaysStoppedAnimation(Colors.purple[400]),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Action buttons
              if (!isDownloading) ...[
                // Download button
                TextButton(
                  onPressed: onDownload,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Download',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),

                // Dismiss button
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(Icons.close, size: 20, color: Colors.purple[400]),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  splashRadius: 20,
                  tooltip: 'Dismiss',
                ),
              ] else ...[
                // Downloading indicator
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.purple[400]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact version of the suggestion banner for use in tight spaces.
class QuadSuggestionChip extends StatelessWidget {
  const QuadSuggestionChip({
    super.key,
    required this.suggestion,
    required this.onTap,
  });

  final QuadrangleSuggestion suggestion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.purple.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map, size: 14, color: Colors.purple[700]),
            const SizedBox(width: 6),
            Text(
              '${suggestion.quad.year} map available',
              style: TextStyle(
                fontSize: 11,
                color: Colors.purple[700],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.download, size: 12, color: Colors.purple[600]),
          ],
        ),
      ),
    );
  }
}
