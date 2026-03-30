import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/providers/hunt_provider.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/hunts/presentation/pages/hunt_detail_page.dart';
import 'package:obsession_tracker/features/hunts/presentation/widgets/create_hunt_dialog.dart';
import 'package:obsession_tracker/features/hunts/presentation/widgets/public_hunts_list.dart';

/// Page displaying treasure hunts with tabbed interface.
///
/// This page provides two tabs:
/// - My Hunts: User's personal treasure hunt tracking
/// - Discover: Public hunts from the BFF API
class HuntsPage extends ConsumerStatefulWidget {
  const HuntsPage({super.key});

  @override
  ConsumerState<HuntsPage> createState() => _HuntsPageState();
}

class _HuntsPageState extends ConsumerState<HuntsPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(huntProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(huntProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final huntsAsync = ref.watch(huntProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hunts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showHuntInfo,
            tooltip: 'About Hunts',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.gold,
          labelColor: AppTheme.gold,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(Icons.folder), text: 'My Hunts'),
            Tab(icon: Icon(Icons.public), text: 'Discover'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Hunts tab
          Stack(
            children: [
              huntsAsync.when(
                data: (hunts) => _buildHuntsList(context, hunts),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => _buildErrorView(context, error),
              ),
              // FAB positioned at bottom right
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: _createHunt,
                  icon: const Icon(Icons.add),
                  label: const Text('New Hunt'),
                  backgroundColor: AppTheme.gold,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          // Discover tab - public hunts from BFF
          const PublicHuntsList(),
        ],
      ),
    );
  }

  Widget _buildHuntsList(BuildContext context, List<TreasureHunt> hunts) {
    if (hunts.isEmpty) {
      return _buildEmptyState(context);
    }

    // Group hunts by status
    final activeHunts = hunts.where((h) => h.status == HuntStatus.active).toList();
    final pausedHunts = hunts.where((h) => h.status == HuntStatus.paused).toList();
    final solvedHunts = hunts.where((h) => h.status == HuntStatus.solved).toList();
    final abandonedHunts = hunts.where((h) => h.status == HuntStatus.abandoned).toList();

    return RefreshIndicator(
      onRefresh: () => ref.read(huntProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 88), // Room for FAB
        children: [
          if (activeHunts.isNotEmpty) ...[
            _buildSectionHeader('Active Hunts', HuntStatus.active),
            ...activeHunts.map((hunt) => _buildHuntCard(context, hunt)),
          ],
          if (pausedHunts.isNotEmpty) ...[
            _buildSectionHeader('Paused Hunts', HuntStatus.paused),
            ...pausedHunts.map((hunt) => _buildHuntCard(context, hunt)),
          ],
          if (solvedHunts.isNotEmpty) ...[
            _buildSectionHeader('Solved Hunts', HuntStatus.solved),
            ...solvedHunts.map((hunt) => _buildHuntCard(context, hunt)),
          ],
          if (abandonedHunts.isNotEmpty) ...[
            _buildSectionHeader('Abandoned Hunts', HuntStatus.abandoned),
            ...abandonedHunts.map((hunt) => _buildHuntCard(context, hunt)),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, HuntStatus status) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Text(
            status.icon,
            style: TextStyle(
              fontSize: 16,
              color: Color(status.color),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(status.color),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHuntCard(BuildContext context, TreasureHunt hunt) {
    final theme = Theme.of(context);
    final summary = ref.watch(huntSummaryProvider(hunt.id));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: hunt.status == HuntStatus.active
            ? BorderSide(color: AppTheme.gold.withValues(alpha: 0.3))
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _openHuntDetail(hunt),
        onLongPress: () => _showHuntOptions(hunt),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image or placeholder
              _buildCoverImage(hunt),
              const SizedBox(width: 16),
              // Hunt details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hunt name
                    Text(
                      hunt.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Author
                    if (hunt.author != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'by ${hunt.author}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    // Tags
                    if (hunt.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: hunt.tags.take(3).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.gold,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    // Summary stats
                    const SizedBox(height: 8),
                    summary.when(
                      data: (s) => s != null
                          ? _buildSummaryRow(s)
                          : const SizedBox.shrink(),
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              // Status badge
              _buildStatusBadge(hunt.status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage(TreasureHunt hunt) {
    debugPrint('_buildCoverImage: "${hunt.name}" path=${hunt.coverImagePath}');
    if (hunt.coverImagePath != null) {
      final file = File(hunt.coverImagePath!);
      final exists = file.existsSync();
      debugPrint('_buildCoverImage: file exists=$exists');
      if (exists) {
        // Use file modification time in key to force reload when contents change
        final modTime = file.lastModifiedSync().millisecondsSinceEpoch;
        debugPrint('_buildCoverImage: modTime=$modTime');
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            file,
            key: ValueKey('${hunt.coverImagePath}_$modTime'),
            height: 60,
            fit: BoxFit.contain, // Preserve aspect ratio without stretching
            cacheHeight: 120, // 2x for retina
            errorBuilder: (context, error, stackTrace) {
              debugPrint('_buildCoverImage: Error loading image: $error');
              return const Icon(Icons.broken_image, size: 28);
            },
          ),
        );
      }
    }

    // Placeholder
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.gold.withValues(alpha: 0.3),
        ),
      ),
      child: Icon(
        Icons.search,
        color: AppTheme.gold.withValues(alpha: 0.5),
        size: 28,
      ),
    );
  }

  Widget _buildSummaryRow(HuntSummary summary) {
    return Row(
      children: [
        _buildStatItem(Icons.description, '${summary.totalItems}'),
        const SizedBox(width: 12),
        _buildStatItem(Icons.route, '${summary.sessionCount}'),
        const SizedBox(width: 12),
        _buildStatItem(Icons.place, '${summary.locationCount}'),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(HuntStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(status.color).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.icon,
        style: TextStyle(
          fontSize: 14,
          color: Color(status.color),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: AppTheme.gold.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 24),
            Text(
              'No Treasure Hunts Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start tracking your treasure hunting adventures!\n'
              'Create a hunt to organize your research, notes,\n'
              'documents, and potential solve locations.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _createHunt,
              icon: const Icon(Icons.add),
              label: const Text('Create Your First Hunt'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, Object error) {
    // Check if this is a recoverable database error
    final isRecoverable = error is DatabaseRecoveryException;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isRecoverable ? Icons.storage : Icons.error_outline,
              size: 64,
              color: isRecoverable ? Colors.orange[300] : Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              isRecoverable ? 'Database Recovery Needed' : 'Error Loading Hunts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              isRecoverable
                  ? 'The app database cannot be opened. This can happen '
                    'after restoring from a backup or updating your device.\n\n'
                    'You can reset the app to start fresh. All existing data will be lost.'
                  : error.toString(),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            if (isRecoverable) ...[
              ElevatedButton.icon(
                onPressed: _confirmDatabaseReset,
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset App Data'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton.icon(
              onPressed: () => ref.read(huntProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDatabaseReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reset App Data?'),
          ],
        ),
        content: const Text(
          'This will permanently delete ALL your data including:\n\n'
          '• All treasure hunts\n'
          '• All tracking sessions\n'
          '• All waypoints and photos\n'
          '• All documents and notes\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Everything'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Show loading indicator
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );

        // Reset the database
        await DatabaseService().resetDatabase();

        // Close loading indicator
        if (mounted) Navigator.pop(context);

        // Refresh to create fresh database
        ref.read(huntProvider.notifier).refresh();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('App data reset successfully. Starting fresh!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Close loading indicator
        if (mounted) Navigator.pop(context);

        // Show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reset failed: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _createHunt() async {
    final result = await showDialog<TreasureHunt>(
      context: context,
      builder: (context) => const CreateHuntDialog(),
    );

    if (result != null && mounted) {
      _openHuntDetail(result);
    }
  }

  void _openHuntDetail(TreasureHunt hunt) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => HuntDetailPage(huntId: hunt.id),
      ),
    );
  }

  void _showHuntOptions(TreasureHunt hunt) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.gold),
              title: const Text('Edit Hunt'),
              onTap: () {
                Navigator.pop(context);
                _editHunt(hunt);
              },
            ),
            if (hunt.status != HuntStatus.active)
              ListTile(
                leading: const Icon(Icons.play_arrow, color: Colors.green),
                title: const Text('Set Active'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(hunt, HuntStatus.active);
                },
              ),
            if (hunt.status != HuntStatus.paused)
              ListTile(
                leading: const Icon(Icons.pause, color: Colors.orange),
                title: const Text('Pause Hunt'),
                onTap: () {
                  Navigator.pop(context);
                  _updateStatus(hunt, HuntStatus.paused);
                },
              ),
            if (hunt.status != HuntStatus.solved)
              ListTile(
                leading: const Icon(Icons.check_circle, color: AppTheme.gold),
                title: const Text('Mark as Solved'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmSolved(hunt);
                },
              ),
            if (hunt.status != HuntStatus.abandoned)
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.grey),
                title: const Text('Abandon Hunt'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAbandon(hunt);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Hunt'),
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(hunt);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editHunt(TreasureHunt hunt) async {
    await showDialog<void>(
      context: context,
      builder: (context) => CreateHuntDialog(existingHunt: hunt),
    );
  }

  Future<void> _updateStatus(TreasureHunt hunt, HuntStatus newStatus) async {
    await ref.read(huntProvider.notifier).updateHuntStatus(hunt.id, newStatus);
  }

  Future<void> _confirmSolved(TreasureHunt hunt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.gold),
            SizedBox(width: 8),
            Text('Mark as Solved'),
          ],
        ),
        content: Text(
          'Congratulations! Are you marking "${hunt.name}" as solved?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Yes, Solved!'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus(hunt, HuntStatus.solved);
    }
  }

  Future<void> _confirmAbandon(TreasureHunt hunt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Hunt?'),
        content: Text(
          'Are you sure you want to abandon "${hunt.name}"? '
          'You can always reactivate it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
            ),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _updateStatus(hunt, HuntStatus.abandoned);
    }
  }

  Future<void> _confirmDelete(TreasureHunt hunt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hunt?'),
        content: Text(
          'Are you sure you want to delete "${hunt.name}"?\n\n'
          'This will permanently remove all documents, notes, and locations '
          'associated with this hunt. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(huntProvider.notifier).deleteHunt(hunt.id);
    }
  }

  void _showHuntInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.search, color: AppTheme.gold),
            SizedBox(width: 8),
            Text('Treasure Hunts'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'My Hunts',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Track your personal treasure hunts, armchair hunts, or '
                'geocaching adventures. Each hunt can contain:',
              ),
              SizedBox(height: 12),
              Text('• Notes and research'),
              Text('• PDF documents'),
              Text('• Images and clue photos'),
              Text('• Important links'),
              Text('• Potential solve locations'),
              Text('• Linked tracking sessions'),
              SizedBox(height: 16),
              Text(
                'Hunt Status',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('🟢 Active - Currently working on'),
              Text('🟠 Paused - Taking a break'),
              Text('🏆 Solved - Victory!'),
              Text('⚫ Abandoned - Moved on'),
              SizedBox(height: 16),
              Text(
                'Discover Tab',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Browse public treasure hunts from around the world. '
                'View featured hunts, active searches, and upcoming '
                r'adventures with prizes over $100,000.',
              ),
              SizedBox(height: 16),
              Text(
                'Link Sessions to Hunts',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Associate your tracking sessions with specific hunts '
                'to organize your fieldwork. Long-press any session in '
                'the Sessions tab to edit its details and change the '
                'associated hunt.',
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.gold,
              foregroundColor: Colors.black,
            ),
            child: const Text('Got It'),
          ),
        ],
      ),
    );
  }
}
