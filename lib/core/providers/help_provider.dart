import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obsession_tracker/core/models/help_models.dart';
import 'package:obsession_tracker/core/services/help_content_service.dart';
import 'package:obsession_tracker/core/utils/app_logger.dart';

/// Provider for help content service
final helpContentServiceProvider =
    Provider<HelpContentService>((ref) => HelpContentService());

/// Provider for all help content
final helpContentProvider = FutureProvider<List<HelpContent>>((ref) async {
  final service = ref.read(helpContentServiceProvider);
  await service.initialize();
  return service.getAllContent();
});

/// Provider for help content by context
final helpContentByContextProvider =
    FutureProvider.family<List<HelpContent>, HelpContext>((ref, context) async {
  final service = ref.read(helpContentServiceProvider);
  await service.initialize();
  return service.getContentByContext(context);
});

/// Provider for help content by type
final helpContentByTypeProvider =
    FutureProvider.family<List<HelpContent>, HelpContentType>(
        (ref, type) async {
  final service = ref.read(helpContentServiceProvider);
  await service.initialize();
  return service.getContentByType(type);
});

/// Provider for contextual help
final contextualHelpProvider =
    FutureProvider.family<List<HelpContent>, HelpContext>((ref, context) async {
  final service = ref.read(helpContentServiceProvider);
  await service.initialize();
  return service.getContextualHelp(context);
});

/// Provider for onboarding flows
final onboardingFlowsProvider =
    FutureProvider<List<OnboardingFlow>>((ref) async {
  final service = ref.read(helpContentServiceProvider);
  await service.initialize();
  return service.getOnboardingFlows();
});

/// Provider for help search results
final helpSearchProvider =
    FutureProvider.family<List<HelpSearchResult>, HelpSearchParams>(
        (ref, params) async {
  final service = ref.read(helpContentServiceProvider);
  await service.initialize();
  return service.searchContent(
    params.query,
    context: params.context,
    type: params.type,
    difficulty: params.difficulty,
    limit: params.limit,
  );
});

/// Provider for recommended content
final recommendedContentProvider =
    FutureProvider.family<List<HelpContent>, RecommendationParams>(
        (ref, params) async {
  final service = ref.read(helpContentServiceProvider);
  await service.initialize();
  return service.getRecommendedContent(
    params.userId,
    params.context,
    limit: params.limit,
  );
});

/// Provider for user progress
final userProgressProvider =
    FutureProvider.family<HelpProgress?, ProgressParams>((ref, params) async {
  final service = ref.read(helpContentServiceProvider);
  await service.initialize();
  return service.getUserProgress(params.contentId, params.userId);
});

/// Notifier for managing help state
class HelpNotifier extends Notifier<HelpState> {
  late final HelpContentService _service;

  @override
  HelpState build() {
    _service = ref.read(helpContentServiceProvider);
    return const HelpState();
  }

  /// Initialize help system
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      await _service.initialize();
      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
      );
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize help system', e, stackTrace);
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Search help content
  Future<void> searchContent(
    String query, {
    HelpContext? context,
    HelpContentType? type,
    HelpDifficulty? difficulty,
  }) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(searchResults: []);
      return;
    }

    state = state.copyWith(isSearching: true);

    try {
      final results = _service.searchContent(
        query,
        context: context,
        type: type,
        difficulty: difficulty,
      );

      state = state.copyWith(
        isSearching: false,
        searchResults: results,
        lastSearchQuery: query,
      );
    } catch (e) {
      AppLogger.error('Failed to search help content', e);
      state = state.copyWith(
        isSearching: false,
        error: e.toString(),
      );
    }
  }

  /// Clear search results
  void clearSearch() {
    state = state.copyWith(
      searchResults: [],
      lastSearchQuery: '',
    );
  }

  /// Set current context
  void setCurrentContext(HelpContext context) {
    state = state.copyWith(currentContext: context);
  }

  /// Show tutorial
  void showTutorial(Tutorial tutorial) {
    state = state.copyWith(
      currentTutorial: tutorial,
      isTutorialActive: true,
      currentTutorialStep: 0,
    );
  }

  /// Hide tutorial
  void hideTutorial() {
    state = state.copyWith(
      isTutorialActive: false,
      currentTutorialStep: 0,
    );
  }

  /// Next tutorial step
  void nextTutorialStep() {
    final tutorial = state.currentTutorial;
    if (tutorial == null) return;

    final nextStep = state.currentTutorialStep + 1;
    if (nextStep < tutorial.steps.length) {
      state = state.copyWith(currentTutorialStep: nextStep);
    } else {
      // Tutorial completed
      hideTutorial();
    }
  }

  /// Previous tutorial step
  void previousTutorialStep() {
    final currentStep = state.currentTutorialStep;
    if (currentStep > 0) {
      state = state.copyWith(currentTutorialStep: currentStep - 1);
    }
  }

  /// Skip tutorial
  void skipTutorial() {
    hideTutorial();
  }

  /// Update user progress
  Future<void> updateProgress(HelpProgress progress) async {
    try {
      await _service.updateUserProgress(progress);
    } catch (e) {
      AppLogger.error('Failed to update help progress', e);
    }
  }

  /// Mark content as completed
  Future<void> markCompleted(String contentId, String userId) async {
    try {
      await _service.markContentCompleted(contentId, userId);
    } catch (e) {
      AppLogger.error('Failed to mark content as completed', e);
    }
  }

  /// Update step progress
  Future<void> updateStepProgress(
    String contentId,
    String userId,
    int stepIndex, {
    Duration? additionalTime,
  }) async {
    try {
      await _service.updateStepProgress(
        contentId,
        userId,
        stepIndex,
        additionalTime: additionalTime,
      );
    } catch (e) {
      AppLogger.error('Failed to update step progress', e);
    }
  }

  /// Show onboarding
  void showOnboarding(OnboardingFlow flow) {
    state = state.copyWith(
      currentOnboardingFlow: flow,
      isOnboardingActive: true,
      currentOnboardingStep: 0,
    );
  }

  /// Hide onboarding
  void hideOnboarding() {
    state = state.copyWith(
      isOnboardingActive: false,
      currentOnboardingStep: 0,
    );
  }

  /// Next onboarding step
  void nextOnboardingStep() {
    final flow = state.currentOnboardingFlow;
    if (flow == null) return;

    final nextStep = state.currentOnboardingStep + 1;
    if (nextStep < flow.steps.length) {
      state = state.copyWith(currentOnboardingStep: nextStep);
    } else {
      // Onboarding completed
      hideOnboarding();
    }
  }

  /// Skip onboarding
  void skipOnboarding() {
    hideOnboarding();
  }

  /// Set help overlay visibility
  void setHelpOverlayVisible({required bool visible}) {
    state = state.copyWith(isHelpOverlayVisible: visible);
  }

  /// Set quick help visibility
  void setQuickHelpVisible({required bool visible}) {
    state = state.copyWith(isQuickHelpVisible: visible);
  }

  /// Clear error
  void clearError() {
    state = state.copyWith();
  }
}

/// Provider for help notifier
final helpNotifierProvider =
    NotifierProvider<HelpNotifier, HelpState>(HelpNotifier.new);

/// Help state
class HelpState {
  const HelpState({
    this.isLoading = false,
    this.isInitialized = false,
    this.isSearching = false,
    this.isTutorialActive = false,
    this.isOnboardingActive = false,
    this.isHelpOverlayVisible = false,
    this.isQuickHelpVisible = false,
    this.currentContext = HelpContext.general,
    this.searchResults = const [],
    this.lastSearchQuery = '',
    this.currentTutorial,
    this.currentTutorialStep = 0,
    this.currentOnboardingFlow,
    this.currentOnboardingStep = 0,
    this.error,
  });

  final bool isLoading;
  final bool isInitialized;
  final bool isSearching;
  final bool isTutorialActive;
  final bool isOnboardingActive;
  final bool isHelpOverlayVisible;
  final bool isQuickHelpVisible;
  final HelpContext currentContext;
  final List<HelpSearchResult> searchResults;
  final String lastSearchQuery;
  final Tutorial? currentTutorial;
  final int currentTutorialStep;
  final OnboardingFlow? currentOnboardingFlow;
  final int currentOnboardingStep;
  final String? error;

  HelpState copyWith({
    bool? isLoading,
    bool? isInitialized,
    bool? isSearching,
    bool? isTutorialActive,
    bool? isOnboardingActive,
    bool? isHelpOverlayVisible,
    bool? isQuickHelpVisible,
    HelpContext? currentContext,
    List<HelpSearchResult>? searchResults,
    String? lastSearchQuery,
    Tutorial? currentTutorial,
    int? currentTutorialStep,
    OnboardingFlow? currentOnboardingFlow,
    int? currentOnboardingStep,
    String? error,
  }) =>
      HelpState(
        isLoading: isLoading ?? this.isLoading,
        isInitialized: isInitialized ?? this.isInitialized,
        isSearching: isSearching ?? this.isSearching,
        isTutorialActive: isTutorialActive ?? this.isTutorialActive,
        isOnboardingActive: isOnboardingActive ?? this.isOnboardingActive,
        isHelpOverlayVisible: isHelpOverlayVisible ?? this.isHelpOverlayVisible,
        isQuickHelpVisible: isQuickHelpVisible ?? this.isQuickHelpVisible,
        currentContext: currentContext ?? this.currentContext,
        searchResults: searchResults ?? this.searchResults,
        lastSearchQuery: lastSearchQuery ?? this.lastSearchQuery,
        currentTutorial: currentTutorial ?? this.currentTutorial,
        currentTutorialStep: currentTutorialStep ?? this.currentTutorialStep,
        currentOnboardingFlow:
            currentOnboardingFlow ?? this.currentOnboardingFlow,
        currentOnboardingStep:
            currentOnboardingStep ?? this.currentOnboardingStep,
        error: error ?? this.error,
      );
}

/// Search parameters
@immutable
class HelpSearchParams {
  const HelpSearchParams({
    required this.query,
    this.context,
    this.type,
    this.difficulty,
    this.limit = 20,
  });

  final String query;
  final HelpContext? context;
  final HelpContentType? type;
  final HelpDifficulty? difficulty;
  final int limit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HelpSearchParams &&
          runtimeType == other.runtimeType &&
          query == other.query &&
          context == other.context &&
          type == other.type &&
          difficulty == other.difficulty &&
          limit == other.limit;

  @override
  int get hashCode =>
      query.hashCode ^
      context.hashCode ^
      type.hashCode ^
      difficulty.hashCode ^
      limit.hashCode;
}

/// Recommendation parameters
@immutable
class RecommendationParams {
  const RecommendationParams({
    required this.userId,
    required this.context,
    this.limit = 5,
  });

  final String userId;
  final HelpContext context;
  final int limit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecommendationParams &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          context == other.context &&
          limit == other.limit;

  @override
  int get hashCode => userId.hashCode ^ context.hashCode ^ limit.hashCode;
}

/// Progress parameters
@immutable
class ProgressParams {
  const ProgressParams({
    required this.contentId,
    required this.userId,
  });

  final String contentId;
  final String userId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressParams &&
          runtimeType == other.runtimeType &&
          contentId == other.contentId &&
          userId == other.userId;

  @override
  int get hashCode => contentId.hashCode ^ userId.hashCode;
}
