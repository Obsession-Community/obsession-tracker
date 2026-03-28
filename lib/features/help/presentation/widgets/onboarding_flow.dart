import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/help_models.dart';
import 'package:obsession_tracker/core/providers/help_provider.dart';
import 'package:obsession_tracker/core/utils/responsive_utils.dart';

/// Widget for displaying onboarding flows
class OnboardingFlowWidget extends ConsumerStatefulWidget {
  const OnboardingFlowWidget({super.key});

  @override
  ConsumerState<OnboardingFlowWidget> createState() =>
      _OnboardingFlowWidgetState();
}

class _OnboardingFlowWidgetState extends ConsumerState<OnboardingFlowWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helpState = ref.watch(helpNotifierProvider);

    if (!helpState.isOnboardingActive ||
        helpState.currentOnboardingFlow == null) {
      return const SizedBox.shrink();
    }

    final flow = helpState.currentOnboardingFlow!;
    final currentStepIndex = helpState.currentOnboardingStep;

    if (currentStepIndex >= flow.steps.length) {
      return const SizedBox.shrink();
    }

    final currentTutorial = flow.steps[currentStepIndex];

    return AnimatedBuilder(
      animation: Listenable.merge([_slideController, _fadeController]),
      builder: (context, child) => Opacity(
        opacity: _fadeAnimation.value,
        child: Material(
          color: Colors.black.withValues(alpha: 0.8),
          child: SafeArea(
            child: SlideTransition(
              position: _slideAnimation,
              child: _buildOnboardingContent(
                  flow, currentTutorial, currentStepIndex),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnboardingContent(
          OnboardingFlow flow, Tutorial tutorial, int stepIndex) =>
      Padding(
        padding: EdgeInsets.all(context.isTablet ? 32 : 24),
        child: Column(
          children: [
            // Header
            _buildHeader(flow, stepIndex),

            const SizedBox(height: 24),

            // Content
            Expanded(
              child: _buildTutorialContent(tutorial),
            ),

            const SizedBox(height: 24),

            // Navigation
            _buildNavigation(flow, stepIndex),
          ],
        ),
      );

  Widget _buildHeader(OnboardingFlow flow, int stepIndex) => Column(
        children: [
          // Welcome message
          Text(
            'Welcome to Obsession Tracker!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: context.isTablet ? 32 : 28,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            flow.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: context.isTablet ? 18 : 16,
                ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Progress indicator
          _buildProgressIndicator(flow, stepIndex),
        ],
      );

  Widget _buildProgressIndicator(OnboardingFlow flow, int currentStep) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...List.generate(flow.steps.length, (index) {
              final isActive = index == currentStep;
              final isCompleted = index < currentStep;

              return Container(
                margin: EdgeInsets.only(
                    right: index < flow.steps.length - 1 ? 8 : 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? Colors.green
                            : isActive
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 8,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    if (index < flow.steps.length - 1)
                      Container(
                        width: 20,
                        height: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        color: isCompleted
                            ? Colors.green
                            : Colors.white.withValues(alpha: 0.3),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      );

  Widget _buildTutorialContent(Tutorial tutorial) => Container(
        width: double.infinity,
        padding: EdgeInsets.all(context.isTablet ? 32 : 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(context.isTablet ? 24 : 20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.explore,
                size: context.isTablet ? 64 : 48,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),

            SizedBox(height: context.isTablet ? 24 : 20),

            // Title
            Text(
              tutorial.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: context.isTablet ? 28 : 24,
                  ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: context.isTablet ? 16 : 12),

            // Description
            Text(
              tutorial.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: context.isTablet ? 18 : 16,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),

            SizedBox(height: context.isTablet ? 24 : 20),

            // Features list
            if (tutorial.steps.isNotEmpty) ...[
              Text(
                "What you'll learn:",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              ...tutorial.steps.take(3).map((step) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            step.title,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      );

  Widget _buildNavigation(OnboardingFlow flow, int stepIndex) => Row(
        children: [
          // Skip button
          if (flow.canSkip)
            TextButton(
              onPressed: _skipOnboarding,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.8),
              ),
              child: const Text('Skip'),
            ),

          const Spacer(),

          // Previous button
          if (stepIndex > 0)
            TextButton.icon(
              onPressed: _previousStep,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.8),
              ),
            ),

          const SizedBox(width: 16),

          // Next/Start button
          ElevatedButton.icon(
            onPressed: _nextStep,
            icon: Icon(
              stepIndex == flow.steps.length - 1
                  ? Icons.rocket_launch
                  : Icons.chevron_right,
            ),
            label: Text(
              stepIndex == flow.steps.length - 1 ? 'Get Started' : 'Next',
            ),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: context.isTablet ? 32 : 24,
                vertical: context.isTablet ? 16 : 12,
              ),
            ),
          ),
        ],
      );

  void _nextStep() {
    final helpState = ref.read(helpNotifierProvider);
    final flow = helpState.currentOnboardingFlow;
    final currentStep = helpState.currentOnboardingStep;

    if (flow != null) {
      if (currentStep < flow.steps.length - 1) {
        // Animate to next step
        _slideController.reset();
        ref.read(helpNotifierProvider.notifier).nextOnboardingStep();
        _slideController.forward();
      } else {
        // Complete onboarding
        _completeOnboarding();
      }
    }
  }

  void _previousStep() {
    _slideController.reverse().then((_) {
      ref.read(helpNotifierProvider.notifier).nextOnboardingStep();
      _slideController.forward();
    });
  }

  void _skipOnboarding() {
    _fadeController.reverse().then((_) {
      ref.read(helpNotifierProvider.notifier).skipOnboarding();
    });
  }

  void _completeOnboarding() {
    _fadeController.reverse().then((_) {
      ref.read(helpNotifierProvider.notifier).hideOnboarding();

      // Show welcome message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.celebration, color: Colors.white),
              SizedBox(width: 8),
              Text('Welcome to Obsession Tracker! Happy exploring!'),
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
