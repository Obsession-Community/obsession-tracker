import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:obsession_tracker/core/models/tracking_session.dart';
import 'package:obsession_tracker/core/models/treasure_hunt.dart';
import 'package:obsession_tracker/core/providers/hunt_provider.dart';
import 'package:obsession_tracker/core/providers/session_provider.dart';
import 'package:obsession_tracker/core/services/database_service.dart';
import 'package:obsession_tracker/core/services/navigation_service.dart';
import 'package:obsession_tracker/core/services/session_import_service.dart';
import 'package:obsession_tracker/features/map/presentation/pages/map_page.dart';
import 'package:obsession_tracker/features/sessions/presentation/pages/session_detail_page.dart';
import 'package:obsession_tracker/features/sessions/presentation/widgets/session_edit_dialog.dart';
import 'package:obsession_tracker/features/sessions/presentation/widgets/session_export_dialog.dart';

/// Page displaying all saved tracking sessions with metadata and playback options.
///
/// This page provides the session management functionality for Milestone 1, including:
/// - Display of all saved tracking sessions
/// - Session metadata (duration, distance, date, breadcrumb count)
/// - Session playback functionality
/// - Navigation to map view for trail visualization
/// - Bulk selection and deletion
class SessionListPage extends ConsumerStatefulWidget {
  const SessionListPage({super.key});

  @override
  ConsumerState<SessionListPage> createState() => _SessionListPageState();
}

class _SessionListPageState extends ConsumerState<SessionListPage> with WidgetsBindingObserver {
  bool _isSelectionMode = false;
  final Set<String> _selectedSessionIds = {};
  String? _selectedHuntFilter; // null means "All Sessions"

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh sessions when page first loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(sessionProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh sessions when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      ref.read(sessionProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<TrackingSession>> sessionsAsync =
        ref.watch(sessionProvider);
    final huntsAsync = ref.watch(huntProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelectionMode
            ? '${_selectedSessionIds.length} selected'
            : 'Saved Adventures'),
        centerTitle: true,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
                tooltip: 'Cancel',
              )
            : null,
        actions: <Widget>[
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () => _toggleSelectAll(sessionsAsync.value ?? []),
              tooltip: _selectedSessionIds.length == (sessionsAsync.value?.length ?? 0)
                  ? 'Deselect All'
                  : 'Select All',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _selectedSessionIds.isEmpty ? null : _deleteSelected,
              tooltip: 'Delete Selected',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.file_download),
              onPressed: _importSession,
              tooltip: 'Import Session',
            ),
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _enterSelectionMode,
              tooltip: 'Select Sessions',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Hunt filter bar (only show if hunts exist)
          huntsAsync.maybeWhen(
            data: (hunts) => hunts.isNotEmpty
                ? _buildHuntFilterBar(context, hunts)
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
          // Session list
          Expanded(
            child: sessionsAsync.when(
              data: (List<TrackingSession> sessions) =>
                  _buildSessionsList(context, _filterSessionsByHunt(sessions)),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (Object error, StackTrace stack) =>
                  _buildErrorView(context, error),
            ),
          ),
        ],
      ),
    );
  }

  /// Filter sessions by the selected hunt
  List<TrackingSession> _filterSessionsByHunt(List<TrackingSession> sessions) {
    if (_selectedHuntFilter == null) {
      return sessions; // No filter - show all
    }
    if (_selectedHuntFilter == '_unassigned') {
      // Show sessions without any hunt
      return sessions.where((s) => s.huntId == null).toList();
    }
    // Filter by specific hunt
    return sessions.where((s) => s.huntId == _selectedHuntFilter).toList();
  }

  /// Build the hunt filter bar
  Widget _buildHuntFilterBar(BuildContext context, List<TreasureHunt> hunts) {
    // Sort hunts: active first, then by name
    final sortedHunts = List<TreasureHunt>.from(hunts)
      ..sort((a, b) {
        if (a.status == HuntStatus.active && b.status != HuntStatus.active) {
          return -1;
        }
        if (b.status == HuntStatus.active && a.status != HuntStatus.active) {
          return 1;
        }
        return a.name.compareTo(b.name);
      });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Filter by Hunt',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              if (_selectedHuntFilter != null)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedHuntFilter = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // "All Sessions" chip
                _buildFilterChip(
                  context,
                  label: 'All',
                  isSelected: _selectedHuntFilter == null,
                  onSelected: () {
                    setState(() {
                      _selectedHuntFilter = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                // "Unassigned" chip
                _buildFilterChip(
                  context,
                  label: 'Unassigned',
                  isSelected: _selectedHuntFilter == '_unassigned',
                  onSelected: () {
                    setState(() {
                      _selectedHuntFilter = '_unassigned';
                    });
                  },
                  icon: Icons.help_outline,
                ),
                const SizedBox(width: 8),
                // Hunt chips
                ...sortedHunts.map((hunt) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildFilterChip(
                        context,
                        label: hunt.name,
                        isSelected: _selectedHuntFilter == hunt.id,
                        onSelected: () {
                          setState(() {
                            _selectedHuntFilter = hunt.id;
                          });
                        },
                        color: _getHuntStatusColor(hunt.status),
                        icon: Icons.search,
                      ),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? color,
    IconData? icon,
  }) {
    final chipColor = color ?? Theme.of(context).colorScheme.primary;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : chipColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? Colors.white : null,
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: chipColor,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  Color _getHuntStatusColor(HuntStatus status) {
    switch (status) {
      case HuntStatus.active:
        return Colors.green;
      case HuntStatus.paused:
        return Colors.orange;
      case HuntStatus.solved:
        return Colors.amber.shade700;
      case HuntStatus.abandoned:
        return Colors.grey;
    }
  }

  void _enterSelectionMode() {
    setState(() {
      _isSelectionMode = true;
      _selectedSessionIds.clear();
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedSessionIds.clear();
    });
  }

  void _toggleSelectAll(List<TrackingSession> sessions) {
    setState(() {
      if (_selectedSessionIds.length == sessions.length) {
        // Deselect all
        _selectedSessionIds.clear();
      } else {
        // Select all
        _selectedSessionIds.clear();
        _selectedSessionIds.addAll(sessions.map((s) => s.id));
      }
    });
  }

  void _toggleSelection(String sessionId) {
    setState(() {
      if (_selectedSessionIds.contains(sessionId)) {
        _selectedSessionIds.remove(sessionId);
      } else {
        _selectedSessionIds.add(sessionId);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedSessionIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Sessions'),
        content: Text(
          'Are you sure you want to delete $count session${count > 1 ? 's' : ''}? This action cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Show loading indicator
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final sessionNotifier = ref.read(sessionProvider.notifier);
    int successCount = 0;
    int failCount = 0;

    // Delete each selected session
    for (final sessionId in _selectedSessionIds) {
      try {
        final success = await sessionNotifier.deleteSession(sessionId);
        if (success) {
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    // Reload sessions
    if (successCount > 0) {
      try {
        await sessionNotifier.reloadAfterDeletion();
      } catch (e) {
        debugPrint('Error reloading sessions: $e');
      }
    }

    if (!mounted) return;

    // Hide loading indicator
    Navigator.of(context).pop();

    // Exit selection mode
    _exitSelectionMode();

    // Show result
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failCount == 0
              ? 'Deleted $successCount session${successCount > 1 ? 's' : ''} successfully'
              : 'Deleted $successCount session${successCount > 1 ? 's' : ''}, $failCount failed',
        ),
        backgroundColor: failCount == 0 ? Colors.green : Colors.orange,
      ),
    );
  }

  /// Import a session from an .obstrack file
  Future<void> _importSession() async {
    // Step 1: Pick the .obstrack file
    final result = await FilePicker.platform.pickFiles();

    if (result == null || result.files.isEmpty) return;

    final filePath = result.files.first.path;
    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access file'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Validate file extension
    if (!filePath.toLowerCase().endsWith('.obstrack')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a .obstrack file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Step 2: Show password dialog
    final password = await _showPasswordDialog();
    if (password == null) return; // User cancelled

    // Step 3: Show loading indicator
    if (!mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Importing session...'),
              ],
            ),
          ),
        ),
      ),
    );

    // Step 4: Import the session
    final importService = SessionImportService();
    final importResult = await importService.importSession(
      obstrackFilePath: filePath,
      password: password,
    );

    // Step 5: Hide loading and show result
    if (!mounted) return;
    Navigator.of(context).pop(); // Close loading dialog

    if (importResult.success) {
      // Refresh sessions list
      await ref.read(sessionProvider.notifier).refresh();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Session imported successfully!\n'
            '${importResult.counts?['breadcrumbs'] ?? 0} breadcrumbs, '
            '${importResult.counts?['waypoints'] ?? 0} waypoints, '
            '${importResult.counts?['custom_markers'] ?? 0} markers',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(importResult.errorMessage ?? 'Import failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Show password dialog for decrypting the import file
  Future<String?> _showPasswordDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Enter Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the password used to encrypt this session file.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                  ),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    Navigator.of(context).pop(value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (passwordController.text.isNotEmpty) {
                  Navigator.of(context).pop(passwordController.text);
                }
              },
              child: const Text('Import'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionsList(
      BuildContext context, List<TrackingSession> sessions) {
    if (sessions.isEmpty) {
      return _buildEmptyState(context);
    }

    // Sort sessions by creation date (newest first)
    sessions.sort((TrackingSession a, TrackingSession b) =>
        b.createdAt.compareTo(a.createdAt));

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(sessionProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: sessions.length,
        itemBuilder: (BuildContext context, int index) =>
            _buildSessionCard(context, sessions[index]),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, TrackingSession session) {
    final isSelected = _selectedSessionIds.contains(session.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            _toggleSelection(session.id);
          } else {
            _viewSessionDetails(context, session);
          }
        },
        onLongPress: () {
          if (_isSelectionMode) {
            // In selection mode, long press does nothing extra
            return;
          }
          // Open edit dialog on long press
          showDialog<void>(
            context: context,
            builder: (BuildContext context) => SessionEditDialog(
              session: session,
            ),
          );
        },
        borderRadius: BorderRadius.circular(8.0),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Session header
              Row(
                children: <Widget>[
                  if (_isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: (_) => _toggleSelection(session.id),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      session.name,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  _buildStatusChip(context, session.status),
                ],
              ),

                if (session.description != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    session.description!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                  ),
                ],

                const SizedBox(height: 12),

                // Session statistics
                Row(
                  children: <Widget>[
                    Expanded(
                        child: _buildStatItem(
                      context,
                      Icons.straighten,
                      'Distance',
                      session.formattedDistance,
                    )),
                    Expanded(
                        child: _buildStatItem(
                      context,
                      Icons.schedule,
                      'Duration',
                      session.formattedDuration,
                    )),
                    Expanded(
                        child: _buildStatItem(
                      context,
                      Icons.timeline,
                      'Points',
                      '${session.breadcrumbCount}',
                    )),
                  ],
                ),

                const SizedBox(height: 12),

                // Session date and actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      DateFormat('MMM d, y • h:mm a').format(session.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!_isSelectionMode)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // Play button (new - primary action)
                          IconButton(
                            onPressed: () => _viewSessionDetails(context, session),
                            icon: const Icon(Icons.play_circle, size: 28),
                            color: Theme.of(context).colorScheme.primary,
                            tooltip: 'View Session',
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: () =>
                                _showSessionOptions(context, session),
                            icon: const Icon(Icons.more_vert, size: 16),
                            label: const Text('More'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildStatItem(
          BuildContext context, IconData icon, String label, String value) =>
      Column(
        children: <Widget>[
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );

  Widget _buildStatusChip(BuildContext context, SessionStatus status) {
    Color backgroundColor;
    Color textColor;
    String text;

    switch (status) {
      case SessionStatus.active:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        text = 'Active';
        break;
      case SessionStatus.paused:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        text = 'Paused';
        break;
      case SessionStatus.completed:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        text = 'Completed';
        break;
      case SessionStatus.cancelled:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        text = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.explore_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Adventures Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Go to the Map tab and tap the play button\non the control bar to start tracking!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => NavigationService().switchToTab(0), // Switch to Map tab
              icon: const Icon(Icons.map),
              label: const Text('Go to Map'),
            ),
          ],
        ),
      );

  Widget _buildErrorView(BuildContext context, Object error) {
    final isRecoverable = error is DatabaseRecoveryException;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              isRecoverable ? Icons.storage : Icons.error_outline,
              size: 64,
              color: isRecoverable ? Colors.orange[300] : Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              isRecoverable ? 'Database Recovery Needed' : 'Error Loading Sessions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: isRecoverable ? Colors.orange[300] : Theme.of(context).colorScheme.error,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              isRecoverable
                  ? error.message
                  : 'Failed to load your saved adventures',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isRecoverable) ...[
              ElevatedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reset App Data?'),
                      content: const Text(
                        'This will delete all local data and start fresh. '
                        'This cannot be undone.\n\n'
                        'If you have a backup (.obk file), you can restore '
                        'it after resetting.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await DatabaseService().resetDatabase();
                    ref.invalidate(sessionProvider);
                  }
                },
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
              onPressed: () {
                if (isRecoverable) {
                  ref.invalidate(sessionProvider);
                } else {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _viewSessionDetails(BuildContext context, TrackingSession session) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SessionDetailPage(session: session),
      ),
    );
  }

  void _showSessionOptions(BuildContext context, TrackingSession session) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => _SessionOptionsSheet(session: session),
    );
  }
}

/// Bottom sheet with session management options
class _SessionOptionsSheet extends ConsumerWidget {
  const _SessionOptionsSheet({required this.session});
  final TrackingSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Capture the session notifier early to avoid disposal issues
    final sessionNotifier = ref.read(sessionProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('View on Map'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => MapPage(
                    playbackSession: session,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Export Session'),
            onTap: () {
              Navigator.of(context).pop();
              showDialog<void>(
                context: context,
                builder: (BuildContext context) => SessionExportDialog(
                  session: session,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Details'),
            onTap: () {
              Navigator.of(context).pop();
              showDialog<void>(
                context: context,
                builder: (BuildContext context) => SessionEditDialog(
                  session: session,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Session',
                style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.of(context).pop();
              _confirmDelete(context, sessionNotifier);
            },
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, SessionNotifier sessionNotifier) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
            'Are you sure you want to delete "${session.name}"? This action cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Show loading indicator
              showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (BuildContext context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              try {
                // DEBUG: Add logging to track widget lifecycle
                debugPrint(
                    'DEBUG: Starting session deletion for ${session.id}');
                debugPrint(
                    'DEBUG: Widget mounted before deletion: ${context.mounted}');

                // Perform deletion using captured notifier
                debugPrint('DEBUG: Calling deleteSession...');
                final success = await sessionNotifier.deleteSession(session.id);

                // DEBUG: Check widget state after async operation
                debugPrint(
                    'DEBUG: Session deletion completed. Success: $success');
                debugPrint(
                    'DEBUG: Widget mounted after deletion: ${context.mounted}');

                // Hide loading indicator and update UI only if widget is still mounted
                if (context.mounted) {
                  debugPrint(
                      'DEBUG: Widget still mounted, dismissing loading dialog');
                  Navigator.of(context).pop();

                  // If deletion was successful, manually reload sessions
                  if (success) {
                    debugPrint(
                        'DEBUG: Manually reloading sessions after successful deletion');
                    try {
                      await sessionNotifier.reloadAfterDeletion();
                      debugPrint('DEBUG: Sessions reloaded successfully');
                    } catch (reloadError) {
                      debugPrint(
                          'DEBUG: Error reloading sessions: $reloadError');
                    }
                  }

                  // Show result message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? 'Session "${session.name}" deleted successfully'
                          : 'Failed to delete session. Please try again.'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                } else {
                  debugPrint(
                      'DEBUG: Widget was disposed during deletion - skipping UI updates');
                }
              } catch (error, stackTrace) {
                debugPrint('DEBUG: Exception during deletion: $error');
                debugPrint('DEBUG: Stack trace: $stackTrace');

                // Ensure loading dialog is dismissed even on error
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'An error occurred during deletion. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
