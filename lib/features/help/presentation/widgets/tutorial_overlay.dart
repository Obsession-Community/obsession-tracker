import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/help_models.dart';
import 'package:obsession_tracker/core/providers/help_provider.dart';
import 'package:obsession_tracker/core/services/device_id_service.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';

/// Overlay widget for displaying interactive tutorials
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  final DeviceIdService _deviceIdService = DeviceIdService();
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initializeUserId();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward();
  }

  Future<void> _initializeUserId() async {
    _userId = await _deviceIdService.getDeviceId();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpNotifierProvider);

    if (!helpState.isTutorialActive || helpState.currentTutorial == null) {
      return const SizedBox.shrink();
    }

    final tutorial = helpState.currentTutorial!; // Null-checked above
    final currentStepIndex = helpState.currentTutorialStep;

    if (currentStepIndex >= tutorial.steps.length) {
      return const SizedBox.shrink();
    }

    final currentStep = tutorial.steps[currentStepIndex];

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) => Opacity(
        opacity: _fadeAnimation.value,
        child: Material(
          color: Colors.black.withValues(alpha: 0.7),
          child: Stack(
            children: [
              // Background tap to close (if skippable)
              if (tutorial.canSkip)
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _skipTutorial,
                    child: Container(color: Colors.transparent),
                  ),
                ),

              // Tutorial content
              Positioned(
                bottom: 80,
                left: 16,
                right: 16,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: _buildTutorialCard(
                      tutorial, currentStep, currentStepIndex),
                ),
              ),

              // Progress indicator
              if (tutorial.showProgress)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  right: 16,
                  child: _buildProgressIndicator(tutorial, currentStepIndex),
                ),

              // Skip button
              if (tutorial.canSkip)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  right: 16,
                  child: _buildSkipButton(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTutorialCard(Tutorial tutorial, HelpStep step, int stepIndex) =>
      Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: EdgeInsets.all(context.isTablet ? 24 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.school,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                      size: context.isTablet ? 24 : 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tutorial.title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: context.isTablet ? 18 : 16,
                                  ),
                        ),
                        Text(
                          'Step ${stepIndex + 1} of ${tutorial.steps.length}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Step title
              Text(
                step.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: context.isTablet ? 22 : 20,
                    ),
              ),

              const SizedBox(height: 12),

              // Step content
              Text(
                step.content,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: context.isTablet ? 16 : 14,
                      height: 1.5,
                    ),
              ),

              // Image if available
              if (step.imageUrl != null) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    step.imageUrl!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  // Previous button
                  if (stepIndex > 0)
                    TextButton.icon(
                      onPressed: _previousStep,
                      icon: const Icon(Icons.chevron_left),
                      label: const Text('Previous'),
                    ),

                  const Spacer(),

                  // Next/Finish button
                  ElevatedButton.icon(
                    onPressed: step.action ?? _nextStep,
                    icon: Icon(
                      stepIndex == tutorial.steps.length - 1
                          ? Icons.check
                          : Icons.chevron_right,
                    ),
                    label: Text(
                      stepIndex == tutorial.steps.length - 1
                          ? 'Finish'
                          : 'Next',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildProgressIndicator(Tutorial tutorial, int currentStep) {
    final progress = (currentStep + 1) / tutorial.steps.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor:
                  Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${currentStep + 1}/${tutorial.steps.length}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkipButton() => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextButton.icon(
          onPressed: _skipTutorial,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('Skip'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
          ),
        ),
      );

  void _nextStep() {
    final helpState = ref.read(helpNotifierProvider);
    final tutorial = helpState.currentTutorial;
    final currentStep = helpState.currentTutorialStep;

    if (tutorial != null) {
      // Update progress
      ref.read(helpNotifierProvider.notifier).updateStepProgress(
            tutorial.id,
            _userId ?? 'unknown_user',
            currentStep,
            additionalTime: const Duration(seconds: 30), // Estimate time spent
          );

      // Move to next step or complete
      if (currentStep < tutorial.steps.length - 1) {
        ref.read(helpNotifierProvider.notifier).nextTutorialStep();
        _animationController.reset();
        _animationController.forward();
      } else {
        _completeTutorial();
      }
    }
  }

  void _previousStep() {
    ref.read(helpNotifierProvider.notifier).previousTutorialStep();
    _animationController.reset();
    _animationController.forward();
  }

  void _skipTutorial() {
    _animationController.reverse().then((_) {
      ref.read(helpNotifierProvider.notifier).skipTutorial();
    });
  }

  void _completeTutorial() {
    final tutorial = ref.read(helpNotifierProvider).currentTutorial;
    if (tutorial != null) {
      // Mark as completed
      ref.read(helpNotifierProvider.notifier).markCompleted(
            tutorial.id,
            _userId ?? 'unknown_user',
          );
    }

    _animationController.reverse().then((_) {
      ref.read(helpNotifierProvider.notifier).hideTutorial();

      // Show completion message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text('Tutorial "${tutorial?.title}" completed!'),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    });
  }
}
