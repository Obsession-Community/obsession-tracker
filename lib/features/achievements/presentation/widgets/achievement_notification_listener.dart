import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obsession_tracker/core/services/achievement_service.dart';
import 'package:obsession_tracker/core/theme/app_theme.dart';
import 'package:obsession_tracker/features/achievements/presentation/widgets/achievement_card.dart';

/// A widget that listens for achievement unlock events and shows notifications.
///
/// Wrap this around your main content to receive achievement notifications.
/// Notifications appear as a custom overlay/snackbar when achievements are unlocked.
class AchievementNotificationListener extends StatefulWidget {
  const AchievementNotificationListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AchievementNotificationListener> createState() =>
      _AchievementNotificationListenerState();
}

class _AchievementNotificationListenerState
    extends State<AchievementNotificationListener> {
  final AchievementService _achievementService = AchievementService();
  StreamSubscription<AchievementUnlockedEvent>? _subscription;
  final List<AchievementUnlockedEvent> _pendingNotifications = [];
  final Set<String> _shownAchievementIds = {};
  bool _isShowingNotification = false;

  @override
  void initState() {
    super.initState();
    _subscription = _achievementService.unlockStream.listen(_onAchievementUnlocked);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onAchievementUnlocked(AchievementUnlockedEvent event) {
    // Deduplicate - don't add if this achievement was already shown or is pending
    final achievementId = event.achievement.id;
    if (_shownAchievementIds.contains(achievementId)) {
      return;
    }
    if (_pendingNotifications.any((e) => e.achievement.id == achievementId)) {
      return;
    }

    _pendingNotifications.add(event);
    _showNextNotification();
  }

  Future<void> _showNextNotification() async {
    if (_isShowingNotification || _pendingNotifications.isEmpty || !mounted) {
      return;
    }

    _isShowingNotification = true;
    final event = _pendingNotifications.removeAt(0);

    // Track this achievement as shown
    _shownAchievementIds.add(event.achievement.id);

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => _AchievementUnlockDialog(event: event),
    );

    _isShowingNotification = false;

    // Show next notification if any
    if (_pendingNotifications.isNotEmpty && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      _showNextNotification();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

/// Dialog shown when an achievement is unlocked
class _AchievementUnlockDialog extends StatefulWidget {
  const _AchievementUnlockDialog({required this.event});

  final AchievementUnlockedEvent event;

  @override
  State<_AchievementUnlockDialog> createState() => _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<_AchievementUnlockDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _controller.forward();

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.event.achievement;
    final difficultyColor = AchievementColors.forDifficulty(def.difficulty);

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: difficultyColor.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: difficultyColor.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with confetti effect
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        difficultyColor.withValues(alpha: 0.2),
                        difficultyColor.withValues(alpha: 0.1),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'ACHIEVEMENT UNLOCKED!',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: difficultyColor,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                      ),
                      const SizedBox(height: 16),
                      // Badge icon with glow
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              difficultyColor,
                              difficultyColor.withValues(alpha: 0.7),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: difficultyColor.withValues(alpha: 0.5),
                              blurRadius: 16,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          _getIconData(def.iconName),
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Achievement details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        def.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        def.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      // Difficulty badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: difficultyColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: difficultyColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Text(
                          def.difficulty.toUpperCase(),
                          style: TextStyle(
                            color: difficultyColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dismiss button
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.gold,
                    ),
                    child: const Text('AWESOME!'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'hiking':
        return Icons.hiking;
      case 'explore':
        return Icons.explore;
      case 'map':
        return Icons.map;
      case 'terrain':
        return Icons.terrain;
      case 'stars':
        return Icons.stars;
      case 'military_tech':
        return Icons.military_tech;
      case 'directions_walk':
        return Icons.directions_walk;
      case 'directions_run':
        return Icons.directions_run;
      case 'route':
        return Icons.route;
      case 'flight':
        return Icons.flight;
      case 'public':
        return Icons.public;
      case 'place':
        return Icons.place;
      case 'travel_explore':
        return Icons.travel_explore;
      case 'flag':
        return Icons.flag;
      case 'language':
        return Icons.language;
      case 'emoji_events':
        return Icons.emoji_events;
      case 'local_fire_department':
        return Icons.local_fire_department;
      case 'whatshot':
        return Icons.whatshot;
      case 'bolt':
        return Icons.bolt;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'diamond':
        return Icons.diamond;
      case 'camera_alt':
        return Icons.camera_alt;
      case 'photo_library':
        return Icons.photo_library;
      case 'photo_camera':
        return Icons.photo_camera;
      case 'collections':
        return Icons.collections;
      case 'mic':
        return Icons.mic;
      case 'record_voice_over':
        return Icons.record_voice_over;
      case 'search':
        return Icons.search;
      case 'manage_search':
        return Icons.manage_search;
      case 'workspace_premium':
        return Icons.workspace_premium;
      default:
        return Icons.star;
    }
  }
}

/// Shows a simple snackbar for achievement unlock (alternative to dialog)
void showAchievementSnackbar(BuildContext context, AchievementDefinition achievement) {
  final difficultyColor = AchievementColors.forDifficulty(achievement.difficulty);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: difficultyColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Achievement Unlocked!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                Text(
                  achievement.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.inverseSurface,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: difficultyColor, width: 2),
      ),
    ),
  );
}
