import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/providers/hunt_provider.dart';

/// Modal bottom sheet for selecting a hunt to associate with a tracking session
class HuntSelectionModal extends ConsumerStatefulWidget {
  const HuntSelectionModal({
    this.currentHuntId,
    super.key,
  });

  /// Currently selected hunt ID (if any)
  final String? currentHuntId;

  @override
  ConsumerState<HuntSelectionModal> createState() => _HuntSelectionModalState();
}

class _HuntSelectionModalState extends ConsumerState<HuntSelectionModal> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TreasureHunt> _getFilteredHunts(List<TreasureHunt> hunts) {
    // Filter by search query
    final filtered = hunts.where((hunt) {
      if (_searchQuery.isEmpty) return true;
      return hunt.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (hunt.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();

    // Sort: active hunts first, then by creation date (most recent first)
    filtered.sort((a, b) {
      // Active hunts first
      if (a.status == HuntStatus.active && b.status != HuntStatus.active) {
        return -1;
      }
      if (b.status == HuntStatus.active && a.status != HuntStatus.active) {
        return 1;
      }
      // Then by creation date
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final huntsAsync = ref.watch(huntProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: huntsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error loading hunts: $error'),
            ),
            data: (hunts) {
              final filteredHunts = _getFilteredHunts(hunts);
              return _buildContent(context, scrollController, filteredHunts);
            },
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    ScrollController scrollController,
    List<TreasureHunt> hunts,
  ) {
    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Hunt',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${hunts.length} hunt${hunts.length != 1 ? 's' : ''} available',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Skip'),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search hunts...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),

        const SizedBox(height: 16),

        // "No hunt" option
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.explore, color: Colors.grey),
          ),
          title: const Text('No hunt - standalone session'),
          subtitle: const Text('Track without associating with a hunt'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pop(context),
        ),

        const Divider(),

        // Hunt list
        Expanded(
          child: hunts.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: hunts.length,
                  itemBuilder: (context, index) {
                    final hunt = hunts[index];
                    return _buildHuntCard(hunt);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHuntCard(TreasureHunt hunt) {
    final now = DateTime.now();
    final difference = now.difference(hunt.createdAt);
    final isCurrentSelection = widget.currentHuntId == hunt.id;

    String timeAgo;
    if (difference.inDays > 30) {
      timeAgo = '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() != 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      timeAgo = '${difference.inDays} day${difference.inDays != 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      timeAgo = '${difference.inHours} hour${difference.inHours != 1 ? 's' : ''} ago';
    } else {
      timeAgo = 'Just now';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrentSelection ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrentSelection
            ? BorderSide(color: Theme.of(context).primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.pop(context, hunt),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Hunt cover image or icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(hunt.status).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.antiAlias,
                child: hunt.coverImagePath != null
                    ? Image.file(
                        File(hunt.coverImagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.search,
                          color: _getStatusColor(hunt.status),
                          size: 24,
                        ),
                      )
                    : Icon(
                        Icons.search,
                        color: _getStatusColor(hunt.status),
                        size: 24,
                      ),
              ),

              const SizedBox(width: 12),

              // Hunt details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hunt.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentSelection)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (hunt.description != null)
                      Text(
                        hunt.description!,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(hunt.status).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            hunt.status.displayName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(hunt.status),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          timeAgo,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty ? 'No hunts found' : 'No matching hunts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Create a hunt in the Hunts tab'
                : 'Try a different search term',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(HuntStatus status) {
    switch (status) {
      case HuntStatus.active:
        return Colors.green;
      case HuntStatus.paused:
        return Colors.orange;
      case HuntStatus.solved:
        return Colors.amber;
      case HuntStatus.abandoned:
        return Colors.grey;
    }
  }
}
