import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/services/ghost_trail_playback_service.dart';

/// Provider for ghost trail playback service
final ghostTrailPlaybackServiceProvider =
    Provider<GhostTrailPlaybackService>((ref) => GhostTrailPlaybackService());

/// Provider for playback state stream
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final service = ref.watch(ghostTrailPlaybackServiceProvider);
  return service.stateStream;
});

/// Provider for playback position stream
final playbackPositionProvider = StreamProvider<PlaybackPosition>((ref) {
  final service = ref.watch(ghostTrailPlaybackServiceProvider);
  return service.positionStream;
});

/// Provider for ghost trail segments stream
final ghostTrailSegmentsProvider =
    StreamProvider<List<GhostTrailSegment>>((ref) {
  final service = ref.watch(ghostTrailPlaybackServiceProvider);
  return service.trailStream;
});

/// Playback controls widget for ghost trail animation
class GhostTrailPlaybackControls extends ConsumerStatefulWidget {
  const GhostTrailPlaybackControls({
    super.key,
    this.onPositionChanged,
    this.showSpeedControl = true,
    this.showTimeDisplay = true,
    this.compact = false,
  });

  /// Callback when playback position changes
  final ValueChanged<PlaybackPosition>? onPositionChanged;

  /// Whether to show speed control
  final bool showSpeedControl;

  /// Whether to show time display
  final bool showTimeDisplay;

  /// Whether to use compact layout
  final bool compact;

  @override
  ConsumerState<GhostTrailPlaybackControls> createState() =>
      _GhostTrailPlaybackControlsState();
}

class _GhostTrailPlaybackControlsState
    extends ConsumerState<GhostTrailPlaybackControls>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playbackStateAsync = ref.watch(playbackStateProvider);
    final playbackPositionAsync = ref.watch(playbackPositionProvider);

    return playbackStateAsync.when(
      data: (state) => playbackPositionAsync.when(
        data: (position) => _buildControls(context, state, position),
        loading: () => _buildLoadingControls(context),
        error: (error, stack) => _buildErrorControls(context, error),
      ),
      loading: () => _buildLoadingControls(context),
      error: (error, stack) => _buildErrorControls(context, error),
    );
  }

  Widget _buildControls(
      BuildContext context, PlaybackState state, PlaybackPosition position) {
    final theme = Theme.of(context);
    final service = ref.read(ghostTrailPlaybackServiceProvider);

    if (widget.compact) {
      return _buildCompactControls(context, theme, service, state, position);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          _buildProgressBar(context, theme, service, position),
          const SizedBox(height: 12),

          // Main controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Speed control
              if (widget.showSpeedControl)
                _buildSpeedControl(context, theme, service),

              // Play/pause/stop controls
              _buildPlaybackButtons(context, theme, service, state),

              // Time display
              if (widget.showTimeDisplay)
                _buildTimeDisplay(context, theme, position),
            ],
          ),

          // Additional info row
          if (!widget.compact) ...[
            const SizedBox(height: 8),
            _buildInfoRow(context, theme, service, position),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactControls(
    BuildContext context,
    ThemeData theme,
    GhostTrailPlaybackService service,
    PlaybackState state,
    PlaybackPosition position,
  ) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPlayPauseButton(context, theme, service, state),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: _buildProgressBar(context, theme, service, position),
            ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(position.elapsedTime),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _buildProgressBar(
    BuildContext context,
    ThemeData theme,
    GhostTrailPlaybackService service,
    PlaybackPosition position,
  ) {
    final progress = _isDragging ? _dragValue : position.progress;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: progress,
            onChanged: (value) {
              setState(() {
                _isDragging = true;
                _dragValue = value;
              });
            },
            onChangeEnd: (value) {
              setState(() {
                _isDragging = false;
              });
              service.seekToProgress(value);
            },
            activeColor: theme.colorScheme.primary,
            inactiveColor: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
        if (widget.showTimeDisplay && !widget.compact) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position.elapsedTime),
                style: theme.textTheme.bodySmall,
              ),
              Text(
                _formatDuration(position.totalTime),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPlaybackButtons(
    BuildContext context,
    ThemeData theme,
    GhostTrailPlaybackService service,
    PlaybackState state,
  ) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stop button
          IconButton(
            onPressed:
                state != PlaybackState.stopped ? () => service.stop() : null,
            icon: const Icon(Icons.stop),
            tooltip: 'Stop',
          ),

          // Play/pause button
          _buildPlayPauseButton(context, theme, service, state),

          // Skip to end button
          IconButton(
            onPressed: state != PlaybackState.completed
                ? () => service.seekToProgress(1.0)
                : null,
            icon: const Icon(Icons.skip_next),
            tooltip: 'Skip to end',
          ),
        ],
      );

  Widget _buildPlayPauseButton(
    BuildContext context,
    ThemeData theme,
    GhostTrailPlaybackService service,
    PlaybackState state,
  ) {
    Widget icon;
    VoidCallback? onPressed;
    String tooltip;

    switch (state) {
      case PlaybackState.stopped:
      case PlaybackState.completed:
        icon = const Icon(Icons.play_arrow);
        onPressed = () => service.play();
        tooltip = 'Play';
        break;
      case PlaybackState.playing:
        icon = AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) => Transform.scale(
            scale: _pulseAnimation.value,
            child: const Icon(Icons.pause),
          ),
        );
        onPressed = () => service.pause();
        tooltip = 'Pause';
        break;
      case PlaybackState.paused:
        icon = const Icon(Icons.play_arrow);
        onPressed = () => service.play();
        tooltip = 'Resume';
        break;
      case PlaybackState.loading:
        icon = SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        );
        onPressed = null;
        tooltip = 'Loading';
        break;
    }

    return IconButton(
      onPressed: onPressed,
      icon: icon,
      tooltip: tooltip,
      iconSize: 32,
    );
  }

  Widget _buildSpeedControl(
    BuildContext context,
    ThemeData theme,
    GhostTrailPlaybackService service,
  ) =>
      PopupMenuButton<PlaybackSpeed>(
        initialValue: service.speed,
        onSelected: (speed) => service.setSpeed(speed),
        itemBuilder: (context) => PlaybackSpeed.values
            .map((speed) => PopupMenuItem<PlaybackSpeed>(
                  value: speed,
                  child: Row(
                    children: [
                      Icon(
                        Icons.speed,
                        size: 16,
                        color: service.speed == speed
                            ? theme.colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        speed.displayName,
                        style: TextStyle(
                          color: service.speed == speed
                              ? theme.colorScheme.primary
                              : null,
                          fontWeight:
                              service.speed == speed ? FontWeight.bold : null,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed, size: 16),
              const SizedBox(width: 4),
              Text(
                service.speed.displayName,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );

  Widget _buildTimeDisplay(
    BuildContext context,
    ThemeData theme,
    PlaybackPosition position,
  ) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatDuration(position.elapsedTime),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '/ ${_formatDuration(position.totalTime)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _buildInfoRow(
    BuildContext context,
    ThemeData theme,
    GhostTrailPlaybackService service,
    PlaybackPosition position,
  ) {
    final stats = service.getPlaybackStats();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildInfoChip(
          context,
          theme,
          Icons.location_on,
          'Index: ${position.currentIndex}',
        ),
        _buildInfoChip(
          context,
          theme,
          Icons.percent,
          '${stats['progress_percent']}%',
        ),
        _buildInfoChip(
          context,
          theme,
          Icons.route,
          '${stats['total_breadcrumbs']} points',
        ),
      ],
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    ThemeData theme,
    IconData icon,
    String text,
  ) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12),
            const SizedBox(width: 4),
            Text(
              text,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );

  Widget _buildLoadingControls(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor:
                  AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading playback data...',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorControls(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Playback error: ${error.toString()}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }
}
