import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:obsession_tracker/core/models/help_models.dart';
import 'package:obsession_tracker/core/utils/app_logger.dart';

/// Service for managing help content including loading, caching, and searching
class HelpContentService {
  factory HelpContentService() => _instance;
  HelpContentService._internal();
  static final HelpContentService _instance = HelpContentService._internal();

  final Map<String, HelpContent> _contentCache = {};
  final Map<HelpContext, List<HelpContent>> _contextCache = {};
  final Map<String, HelpProgress> _progressCache = {};
  final List<OnboardingFlow> _onboardingFlows = <OnboardingFlow>[];

  bool _isInitialized = false;

  /// Initialize the help content service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _loadHelpContent();
      await _loadOnboardingFlows();
      await _loadUserProgress();
      _isInitialized = true;
      AppLogger.info('Help content service initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to initialize help content service', e, stackTrace);
      rethrow;
    }
  }

  /// Load help content from assets
  Future<void> _loadHelpContent() async {
    try {
      // Load tutorials
      await _loadContentType('tutorials', HelpContentType.tutorial);

      // Load guides
      await _loadContentType('guides', HelpContentType.guide);

      // Load FAQs
      await _loadContentType('faqs', HelpContentType.faq);

      // Load troubleshooting guides
      await _loadContentType(
          'troubleshooting', HelpContentType.troubleshooting);

      // Load documentation
      await _loadContentType('documentation', HelpContentType.documentation);

      // Load video tutorials
      await _loadContentType('videos', HelpContentType.video);

      // Load interactive guides
      await _loadContentType('interactive', HelpContentType.interactive);

      // Load quick tips
      await _loadContentType('tips', HelpContentType.quickTip);

      _buildContextCache();
    } catch (e) {
      AppLogger.error('Failed to load help content', e);
      // Load default content if assets fail
      await _loadDefaultContent();
    }
  }

  /// Load specific content type from assets
  Future<void> _loadContentType(String folder, HelpContentType type) async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifestMap =
          json.decode(manifestContent) as Map<String, dynamic>;

      final contentFiles = manifestMap.keys
          .where((String key) => key.startsWith('assets/help/$folder/'))
          .where((String key) => key.endsWith('.json'))
          .toList();

      for (final file in contentFiles) {
        try {
          final contentJson = await rootBundle.loadString(file);
          final contentData = json.decode(contentJson) as Map<String, dynamic>;
          final content = HelpContent.fromJson(contentData);
          _contentCache[content.id] = content;
        } catch (e) {
          AppLogger.warning('Failed to load help content file: $file', e);
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to load content type: $folder', e);
    }
  }

  /// Load onboarding flows
  Future<void> _loadOnboardingFlows() async {
    try {
      final flowsJson =
          await rootBundle.loadString('assets/help/onboarding/flows.json');
      final flowsData = json.decode(flowsJson) as Map<String, dynamic>;
      final flows = (flowsData['flows'] as List<dynamic>)
          .map((f) => OnboardingFlow.fromJson(f as Map<String, dynamic>))
          .toList();

      _onboardingFlows.clear();
      _onboardingFlows.addAll(flows);
    } catch (e) {
      AppLogger.warning('Failed to load onboarding flows, using defaults', e);
      await _loadDefaultOnboardingFlows();
    }
  }

  /// Load user progress from local storage
  Future<void> _loadUserProgress() async {
    try {
      // TODO(obsession): Implement local storage loading
      // For now, initialize empty progress
      _progressCache.clear();
    } catch (e) {
      AppLogger.warning('Failed to load user progress', e);
    }
  }

  /// Build context-based cache for faster lookups
  void _buildContextCache() {
    _contextCache.clear();

    for (final context in HelpContext.values) {
      _contextCache[context] = _contentCache.values
          .where((content) => content.context == context)
          .toList()
        ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
    }
  }

  /// Get all help content
  List<HelpContent> getAllContent() => _contentCache.values.toList();

  /// Get content by ID
  HelpContent? getContentById(String id) => _contentCache[id];

  /// Get content by context
  List<HelpContent> getContentByContext(HelpContext context) =>
      _contextCache[context] ?? [];

  /// Get content by type
  List<HelpContent> getContentByType(HelpContentType type) =>
      _contentCache.values.where((content) => content.type == type).toList();

  /// Get content by difficulty
  List<HelpContent> getContentByDifficulty(HelpDifficulty difficulty) =>
      _contentCache.values
          .where((content) => content.difficulty == difficulty)
          .toList();

  /// Search help content
  List<HelpSearchResult> searchContent(
    String query, {
    HelpContext? context,
    HelpContentType? type,
    HelpDifficulty? difficulty,
    int limit = 20,
  }) {
    if (query.trim().isEmpty) return [];

    final searchTerms = query.toLowerCase().split(' ');
    final results = <HelpSearchResult>[];

    for (final content in _contentCache.values) {
      // Apply filters
      if (context != null && content.context != context) continue;
      if (type != null && content.type != type) continue;
      if (difficulty != null && content.difficulty != difficulty) continue;

      final relevanceScore = _calculateRelevanceScore(content, searchTerms);
      if (relevanceScore > 0) {
        results.add(HelpSearchResult(
          content: content,
          relevanceScore: relevanceScore,
          matchedTerms: _getMatchedTerms(content, searchTerms),
          highlightedContent: _highlightContent(content, searchTerms),
        ));
      }
    }

    // Sort by relevance score
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    return results.take(limit).toList();
  }

  /// Calculate relevance score for search
  double _calculateRelevanceScore(
      HelpContent content, List<String> searchTerms) {
    double score = 0.0;
    final titleLower = content.title.toLowerCase();
    final descriptionLower = content.description.toLowerCase();
    final tagsLower = content.tags.map((tag) => tag.toLowerCase()).toList();

    for (final term in searchTerms) {
      // Title matches (highest weight)
      if (titleLower.contains(term)) {
        score += titleLower == term ? 10.0 : 5.0;
      }

      // Description matches
      if (descriptionLower.contains(term)) {
        score += 2.0;
      }

      // Tag matches
      for (final tag in tagsLower) {
        if (tag.contains(term)) {
          score += tag == term ? 3.0 : 1.0;
        }
      }

      // Content-specific matches
      score += _getContentSpecificScore(content, term);
    }

    // Boost score based on priority
    switch (content.priority) {
      case HelpPriority.critical:
        score *= 1.5;
        break;
      case HelpPriority.high:
        score *= 1.3;
        break;
      case HelpPriority.medium:
        score *= 1.1;
        break;
      case HelpPriority.low:
        break;
    }

    return score;
  }

  /// Get content-specific search score
  double _getContentSpecificScore(HelpContent content, String term) {
    switch (content.type) {
      case HelpContentType.faq:
        final faq = content as FAQ;
        if (faq.question.toLowerCase().contains(term) ||
            faq.answer.toLowerCase().contains(term)) {
          return 2.0;
        }
        break;
      case HelpContentType.troubleshooting:
        final guide = content as TroubleshootingGuide;
        if (guide.problem.toLowerCase().contains(term) ||
            guide.symptoms.any((s) => s.toLowerCase().contains(term))) {
          return 3.0;
        }
        break;
      case HelpContentType.documentation:
        final doc = content as Documentation;
        if (doc.content.toLowerCase().contains(term)) {
          return 1.0;
        }
        break;
      default:
        break;
    }
    return 0.0;
  }

  /// Get matched terms for highlighting
  List<String> _getMatchedTerms(HelpContent content, List<String> searchTerms) {
    final matched = <String>[];
    final allText =
        '${content.title} ${content.description} ${content.tags.join(' ')}'
            .toLowerCase();

    for (final term in searchTerms) {
      if (allText.contains(term)) {
        matched.add(term);
      }
    }

    return matched;
  }

  /// Highlight matched terms in content
  String? _highlightContent(HelpContent content, List<String> searchTerms) {
    String text = content.description;

    for (final term in searchTerms) {
      final regex = RegExp(term, caseSensitive: false);
      text = text.replaceAllMapped(regex, (match) => '**${match.group(0)}**');
    }

    return text != content.description ? text : null;
  }

  /// Get contextual help for current screen
  List<HelpContent> getContextualHelp(HelpContext context, {int limit = 5}) {
    final contextContent = getContentByContext(context);

    // Prioritize quick tips and FAQs for contextual help
    final prioritized = <HelpContent>[];

    // Add quick tips first
    prioritized.addAll(contextContent
        .where((c) => c.type == HelpContentType.quickTip)
        .take(2));

    // Add FAQs
    prioritized.addAll(
        contextContent.where((c) => c.type == HelpContentType.faq).take(2));

    // Add other content
    prioritized.addAll(contextContent
        .where((c) =>
            c.type != HelpContentType.quickTip && c.type != HelpContentType.faq)
        .take(limit - prioritized.length));

    return prioritized.take(limit).toList();
  }

  /// Get onboarding flows
  List<OnboardingFlow> getOnboardingFlows({String? targetUserType}) {
    if (targetUserType != null) {
      return _onboardingFlows
          .where((flow) =>
              flow.targetUserType == targetUserType ||
              flow.targetUserType == null)
          .toList();
    }
    return _onboardingFlows;
  }

  /// Get user progress for content
  HelpProgress? getUserProgress(String contentId, String userId) {
    final key = '${userId}_$contentId';
    return _progressCache[key];
  }

  /// Update user progress
  Future<void> updateUserProgress(HelpProgress progress) async {
    final key = '${progress.userId}_${progress.contentId}';
    _progressCache[key] = progress;

    try {
      // TODO(obsession): Persist to local storage
      await _saveUserProgress();
    } catch (e) {
      AppLogger.error('Failed to save user progress', e);
    }
  }

  /// Mark content as completed
  Future<void> markContentCompleted(String contentId, String userId) async {
    final existing = getUserProgress(contentId, userId);
    final progress = existing?.copyWith(
          isCompleted: true,
          completedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        ) ??
        HelpProgress(
          contentId: contentId,
          userId: userId,
          isCompleted: true,
          completedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
        );

    await updateUserProgress(progress);
  }

  /// Update step progress
  Future<void> updateStepProgress(
      String contentId, String userId, int stepIndex,
      {Duration? additionalTime}) async {
    final existing = getUserProgress(contentId, userId);
    final completedSteps = List<int>.from(existing?.completedSteps ?? []);

    if (!completedSteps.contains(stepIndex)) {
      completedSteps.add(stepIndex);
    }

    final progress = existing?.copyWith(
          currentStep: stepIndex + 1,
          completedSteps: completedSteps,
          lastAccessedAt: DateTime.now(),
          timeSpent: existing.timeSpent + (additionalTime ?? Duration.zero),
        ) ??
        HelpProgress(
          contentId: contentId,
          userId: userId,
          currentStep: stepIndex + 1,
          completedSteps: completedSteps,
          startedAt: DateTime.now(),
          lastAccessedAt: DateTime.now(),
          timeSpent: additionalTime ?? Duration.zero,
        );

    await updateUserProgress(progress);
  }

  /// Get recommended content based on user progress and context
  List<HelpContent> getRecommendedContent(
    String userId,
    HelpContext currentContext, {
    int limit = 5,
  }) {
    final recommendations = <HelpContent>[];

    // Get incomplete content from current context
    final contextContent = getContentByContext(currentContext);
    for (final content in contextContent) {
      final progress = getUserProgress(content.id, userId);
      if (progress == null || !progress.isCompleted) {
        recommendations.add(content);
      }
    }

    // Add beginner content if user is new
    final userProgress =
        _progressCache.values.where((p) => p.userId == userId).toList();

    if (userProgress.length < 3) {
      recommendations.addAll(
        _contentCache.values
            .where((c) => c.difficulty == HelpDifficulty.beginner)
            .where((c) => !recommendations.contains(c))
            .take(2),
      );
    }

    // Sort by priority and return limited results
    recommendations
        .sort((a, b) => b.priority.index.compareTo(a.priority.index));
    return recommendations.take(limit).toList();
  }

  /// Save user progress to local storage
  Future<void> _saveUserProgress() async {
    try {
      // TODO(obsession): Implement local storage persistence
      // This would typically use SharedPreferences or a local database
    } catch (e) {
      AppLogger.error('Failed to save user progress to storage', e);
    }
  }

  /// Load default content when assets fail
  Future<void> _loadDefaultContent() async {
    // Add essential default content
    _contentCache['welcome_tutorial'] = const Tutorial(
      id: 'welcome_tutorial',
      title: 'Welcome to Obsession Tracker',
      description: 'Learn the basics of using Obsession Tracker',
      context: HelpContext.home,
      difficulty: HelpDifficulty.beginner,
      priority: HelpPriority.high,
      steps: [
        HelpStep(
          id: 'step_1',
          title: 'Welcome',
          content:
              'Welcome to Obsession Tracker! This tutorial will help you get started.',
        ),
        HelpStep(
          id: 'step_2',
          title: 'Navigation',
          content:
              'Use the bottom navigation bar to switch between different sections of the app.',
        ),
        HelpStep(
          id: 'step_3',
          title: 'Start Tracking',
          content:
              'Tap the "Track" tab to begin your first GPS tracking session.',
        ),
      ],
      tags: ['welcome', 'basics', 'getting-started'],
    );

    _contentCache['gps_faq'] = const FAQ(
      id: 'gps_faq',
      title: 'GPS Not Working',
      description: 'Common GPS issues and solutions',
      context: HelpContext.tracking,
      difficulty: HelpDifficulty.beginner,
      priority: HelpPriority.high,
      question: 'Why is my GPS not working?',
      answer:
          'Make sure location permissions are enabled and you have a clear view of the sky. GPS works best outdoors.',
      tags: ['gps', 'location', 'troubleshooting'],
    );

    _buildContextCache();
  }

  /// Load default onboarding flows
  Future<void> _loadDefaultOnboardingFlows() async {
    final welcomeTutorial = _contentCache['welcome_tutorial'] as Tutorial?;
    if (welcomeTutorial != null) {
      _onboardingFlows.add(OnboardingFlow(
        id: 'first_time_user',
        name: 'First Time User',
        description: 'Introduction for new users',
        steps: [welcomeTutorial],
      ));
    }
  }

  /// Clear all cached content (useful for testing)
  void clearCache() {
    _contentCache.clear();
    _contextCache.clear();
    _progressCache.clear();
    _onboardingFlows.clear();
    _isInitialized = false;
  }

  /// Get content statistics
  Map<String, dynamic> getContentStatistics() {
    final stats = <String, dynamic>{};

    // Count by type
    for (final type in HelpContentType.values) {
      stats['${type.name}_count'] = getContentByType(type).length;
    }

    // Count by context
    for (final context in HelpContext.values) {
      stats['${context.name}_count'] = getContentByContext(context).length;
    }

    // Count by difficulty
    for (final difficulty in HelpDifficulty.values) {
      stats['${difficulty.name}_count'] =
          getContentByDifficulty(difficulty).length;
    }

    stats['total_content'] = _contentCache.length;
    stats['onboarding_flows'] = _onboardingFlows.length;
    stats['user_progress_entries'] = _progressCache.length;

    return stats;
  }
}
