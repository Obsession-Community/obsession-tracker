import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:obsession_tracker/core/models/public_hunt.dart';
import 'package:obsession_tracker/core/providers/hunt_provider.dart';
import 'package:obsession_tracker/core/providers/public_hunts_provider.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Detail page for viewing a public hunt from the BFF.
///
/// Shows full hunt information including description, media, links, and updates.
class PublicHuntDetailPage extends ConsumerStatefulWidget {
  final String huntSlug;

  const PublicHuntDetailPage({super.key, required this.huntSlug});

  @override
  ConsumerState<PublicHuntDetailPage> createState() => _PublicHuntDetailPageState();
}

class _PublicHuntDetailPageState extends ConsumerState<PublicHuntDetailPage> {
  bool _isAddingToMyHunts = false;

  @override
  Widget build(BuildContext context) {
    final huntAsync = ref.watch(publicHuntBySlugProvider(widget.huntSlug));

    return Scaffold(
      body: huntAsync.when(
        data: (hunt) => hunt != null
            ? _buildContent(context, hunt)
            : _buildNotFound(context),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
      floatingActionButton: huntAsync.whenOrNull(
        data: (hunt) => hunt != null ? _buildAddToMyHuntsFab(context, hunt) : null,
      ),
    );
  }

  Widget _buildAddToMyHuntsFab(BuildContext context, PublicHunt hunt) {
    return FloatingActionButton.extended(
      onPressed: _isAddingToMyHunts ? null : () => _addToMyHunts(hunt),
      backgroundColor: _isAddingToMyHunts ? Colors.grey : AppTheme.gold,
      foregroundColor: Colors.black,
      icon: _isAddingToMyHunts
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
            )
          : const Icon(Icons.add),
      label: Text(_isAddingToMyHunts ? 'Adding...' : 'Add to My Hunts'),
    );
  }

  Future<void> _addToMyHunts(PublicHunt hunt) async {
    setState(() => _isAddingToMyHunts = true);

    try {
      // Build tags from hunt type and difficulty
      final tags = <String>[
        'source:${hunt.slug}', // Track which public hunt this came from
        hunt.huntType.name,
      ];
      if (hunt.difficulty != null) {
        tags.add(hunt.difficulty!.name);
      }
      if (hunt.searchRegion != null) {
        tags.add(hunt.searchRegion!);
      }

      // Build description
      final description = StringBuffer();
      description.writeln(hunt.description);
      if (hunt.prizeDescription != null) {
        description.writeln('\nPrize: ${hunt.prizeDescription}');
      }
      if (hunt.prizeValueUsd != null) {
        description.writeln('Value: \$${hunt.prizeValueUsd!.toStringAsFixed(0)}');
      }
      if (hunt.providerUrl != null) {
        description.writeln('\nOfficial: ${hunt.providerUrl}');
      }

      // Download hero image if available
      File? coverImage;
      if (hunt.heroImageUrl != null) {
        try {
          debugPrint('📥 Downloading hero image from: ${hunt.heroImageUrl}');
          final response = await http.get(Uri.parse(hunt.heroImageUrl!));
          if (response.statusCode == 200) {
            // Save to temp file
            final tempDir = await getTemporaryDirectory();
            final extension = hunt.heroImageUrl!.split('.').last.split('?').first;
            final tempFile = File('${tempDir.path}/hunt_cover_${hunt.slug}.$extension');
            await tempFile.writeAsBytes(response.bodyBytes);
            coverImage = tempFile;
            debugPrint('✅ Hero image saved to: ${tempFile.path}');
          } else {
            debugPrint('⚠️ Failed to download hero image: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('⚠️ Error downloading hero image: $e');
          // Continue without cover image
        }
      }

      // Create the local hunt
      final newHunt = await ref.read(huntProvider.notifier).createHunt(
            name: hunt.title,
            author: hunt.providerName,
            description: description.toString(),
            tags: tags,
            coverImage: coverImage,
          );

      if (newHunt != null && mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hunt added! Check "My Hunts" tab to view it.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate back to the hunts list
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add hunt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToMyHunts = false);
      }
    }
  }

  Widget _buildContent(BuildContext context, PublicHunt hunt) {
    return CustomScrollView(
      slivers: [
        // App bar with hero image
        SliverAppBar(
          expandedHeight: hunt.heroImageUrl != null ? 200 : 0,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              hunt.title,
              style: const TextStyle(
                shadows: [
                  Shadow(color: Colors.black54, blurRadius: 4),
                ],
              ),
            ),
            background: hunt.heroImageUrl != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        hunt.heroImageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => ColoredBox(
                          color: AppTheme.gold.withValues(alpha: 0.2),
                          child: Icon(
                            Icons.image,
                            size: 64,
                            color: AppTheme.gold.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
          ),
          actions: [
            if (hunt.providerUrl != null)
              IconButton(
                icon: const Icon(Icons.open_in_new),
                onPressed: () => _openUrl(hunt.providerUrl!),
                tooltip: 'Visit Provider',
              ),
          ],
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subtitle
                if (hunt.subtitle != null) ...[
                  Text(
                    hunt.subtitle!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Status and info row
                _buildInfoRow(context, hunt),
                const SizedBox(height: 24),

                // Description
                Text(
                  'About This Hunt',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  hunt.description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),

                // Prize info
                if (hunt.prizeDescription != null || hunt.prizeValueUsd != null) ...[
                  _buildPrizeSection(context, hunt),
                  const SizedBox(height: 24),
                ],

                // Dates
                _buildDatesSection(context, hunt),
                const SizedBox(height: 24),

                // Provider info
                _buildProviderSection(context, hunt),
                const SizedBox(height: 24),

                // Media gallery
                if (hunt.media.isNotEmpty) ...[
                  _buildMediaSection(context, hunt.media),
                  const SizedBox(height: 24),
                ],

                // Links
                if (hunt.links.isNotEmpty) ...[
                  _buildLinksSection(context, hunt.links),
                  const SizedBox(height: 24),
                ],

                // Updates timeline
                if (hunt.updates.isNotEmpty) ...[
                  _buildUpdatesSection(context, hunt.updates),
                  const SizedBox(height: 24),
                ],

                // Bottom padding
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(BuildContext context, PublicHunt hunt) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildInfoChip(_getStatusLabel(hunt.status), _getStatusIcon(hunt.status),
            _getStatusColor(hunt.status)),
        _buildInfoChip(_getHuntTypeLabel(hunt.huntType), Icons.category, AppTheme.gold),
        if (hunt.difficulty != null)
          _buildInfoChip(_getDifficultyLabel(hunt.difficulty!), Icons.trending_up,
              _getDifficultyColor(hunt.difficulty!)),
        if (hunt.searchRegion != null)
          _buildInfoChip(hunt.searchRegion!, Icons.location_on, Colors.blue),
      ],
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeSection(BuildContext context, PublicHunt hunt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppTheme.gold),
              const SizedBox(width: 8),
              Text(
                'Prize',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.gold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hunt.prizeValueUsd != null) ...[
            Text(
              '\$${NumberFormat('#,###').format(hunt.prizeValueUsd)}',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.gold,
                  ),
            ),
            const SizedBox(height: 8),
          ],
          if (hunt.prizeDescription != null)
            Text(
              hunt.prizeDescription!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _buildDatesSection(BuildContext context, PublicHunt hunt) {
    final dateFormat = DateFormat('MMMM d, yyyy');
    final hasAnyDate = hunt.announcedAt != null ||
        hunt.startsAt != null ||
        hunt.endsAt != null ||
        hunt.foundAt != null;

    if (!hasAnyDate) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (hunt.announcedAt != null)
          _buildDateRow(context, 'Announced', hunt.announcedAt!, dateFormat, Icons.campaign),
        if (hunt.startsAt != null)
          _buildDateRow(context, 'Starts', hunt.startsAt!, dateFormat, Icons.play_arrow),
        if (hunt.endsAt != null)
          _buildDateRow(context, 'Ends', hunt.endsAt!, dateFormat, Icons.stop),
        if (hunt.foundAt != null)
          _buildDateRow(context, 'Found', hunt.foundAt!, dateFormat, Icons.check_circle,
              color: Colors.green),
      ],
    );
  }

  Widget _buildDateRow(
      BuildContext context, String label, DateTime date, DateFormat format, IconData icon,
      {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? Colors.grey[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Text(
            format.format(date),
            style: TextStyle(color: color ?? Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSection(BuildContext context, PublicHunt hunt) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (hunt.providerLogoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                hunt.providerLogoUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.business, color: AppTheme.gold),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ] else ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.gold.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.business, color: AppTheme.gold),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Organized by',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                Text(
                  hunt.providerName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          if (hunt.providerUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openUrl(hunt.providerUrl!),
              tooltip: 'Visit Website',
            ),
        ],
      ),
    );
  }

  Widget _buildMediaSection(BuildContext context, List<PublicHuntMedia> media) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gallery',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: media.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = media[index];
              return GestureDetector(
                onTap: () => _showMediaViewer(context, item),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.url,
                    width: 160,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 160,
                      height: 120,
                      color: Colors.grey[300],
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMediaViewer(BuildContext context, PublicHuntMedia media) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(
                media.url,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (media.caption != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: Text(
                    media.caption!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinksSection(BuildContext context, List<PublicHuntLink> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resources',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...links.map((link) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_getLinkIcon(link.linkType), color: AppTheme.gold),
              title: Text(link.title),
              subtitle: Text(_getLinkTypeLabel(link.linkType)),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: () => _openUrl(link.url),
            )),
      ],
    );
  }

  Widget _buildUpdatesSection(BuildContext context, List<PublicHuntUpdate> updates) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Updates',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        ...updates.map((update) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getUpdateColor(update.updateType).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_getUpdateIcon(update.updateType),
                          size: 16, color: _getUpdateColor(update.updateType)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          update.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        dateFormat.format(update.publishedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(update.content),
                ],
              ),
            )),
      ],
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hunt Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Hunt not found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('This hunt may have been removed or is not available.'),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String error) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'Failed to load hunt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(error),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // Helper methods for labels and colors
  String _getStatusLabel(PublicHuntStatus status) {
    switch (status) {
      case PublicHuntStatus.active:
        return 'Active';
      case PublicHuntStatus.upcoming:
        return 'Coming Soon';
      case PublicHuntStatus.found:
        return 'Found';
      case PublicHuntStatus.archived:
        return 'Archived';
      case PublicHuntStatus.draft:
        return 'Draft';
    }
  }

  IconData _getStatusIcon(PublicHuntStatus status) {
    switch (status) {
      case PublicHuntStatus.active:
        return Icons.play_circle;
      case PublicHuntStatus.upcoming:
        return Icons.schedule;
      case PublicHuntStatus.found:
        return Icons.check_circle;
      case PublicHuntStatus.archived:
        return Icons.archive;
      case PublicHuntStatus.draft:
        return Icons.edit;
    }
  }

  Color _getStatusColor(PublicHuntStatus status) {
    switch (status) {
      case PublicHuntStatus.active:
        return Colors.green;
      case PublicHuntStatus.upcoming:
        return Colors.blue;
      case PublicHuntStatus.found:
        return Colors.grey;
      case PublicHuntStatus.archived:
        return Colors.grey;
      case PublicHuntStatus.draft:
        return Colors.orange;
    }
  }

  String _getHuntTypeLabel(PublicHuntType type) {
    switch (type) {
      case PublicHuntType.armchair:
        return 'Armchair';
      case PublicHuntType.field:
        return 'Field';
      case PublicHuntType.hybrid:
        return 'Hybrid';
    }
  }

  String _getDifficultyLabel(PublicHuntDifficulty difficulty) {
    switch (difficulty) {
      case PublicHuntDifficulty.beginner:
        return 'Beginner';
      case PublicHuntDifficulty.intermediate:
        return 'Intermediate';
      case PublicHuntDifficulty.advanced:
        return 'Advanced';
      case PublicHuntDifficulty.expert:
        return 'Expert';
    }
  }

  Color _getDifficultyColor(PublicHuntDifficulty difficulty) {
    switch (difficulty) {
      case PublicHuntDifficulty.beginner:
        return Colors.green;
      case PublicHuntDifficulty.intermediate:
        return Colors.blue;
      case PublicHuntDifficulty.advanced:
        return Colors.orange;
      case PublicHuntDifficulty.expert:
        return Colors.red;
    }
  }

  IconData _getLinkIcon(String linkType) {
    switch (linkType.toLowerCase()) {
      case 'official':
        return Icons.link;
      case 'video':
        return Icons.play_circle;
      case 'article':
        return Icons.article;
      case 'social':
        return Icons.share;
      case 'forum':
        return Icons.forum;
      default:
        return Icons.link;
    }
  }

  String _getLinkTypeLabel(String linkType) {
    switch (linkType.toLowerCase()) {
      case 'official':
        return 'Official Link';
      case 'video':
        return 'Video';
      case 'article':
        return 'Article';
      case 'social':
        return 'Social Media';
      case 'forum':
        return 'Forum Discussion';
      default:
        return linkType;
    }
  }

  IconData _getUpdateIcon(String updateType) {
    switch (updateType.toLowerCase()) {
      case 'clue':
        return Icons.lightbulb;
      case 'announcement':
        return Icons.campaign;
      case 'hint':
        return Icons.help;
      case 'found':
        return Icons.check_circle;
      default:
        return Icons.info;
    }
  }

  Color _getUpdateColor(String updateType) {
    switch (updateType.toLowerCase()) {
      case 'clue':
        return AppTheme.gold;
      case 'announcement':
        return Colors.blue;
      case 'hint':
        return Colors.orange;
      case 'found':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
