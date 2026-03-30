import 'package:flutter/material.dart';

/// Represents different types of help content
enum HelpContentType {
  tutorial,
  guide,
  faq,
  troubleshooting,
  documentation,
  video,
  interactive,
  quickTip,
}

/// Represents the context where help is being accessed
enum HelpContext {
  home,
  tracking,
  map,
  photos,
  sessions,
  settings,
  waypoints,
  search,
  general,
}

/// Represents the difficulty level of help content
enum HelpDifficulty {
  beginner,
  intermediate,
  advanced,
}

/// Represents the priority of help content
enum HelpPriority {
  low,
  medium,
  high,
  critical,
}

/// Base class for all help content
abstract class HelpContent {
  const HelpContent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.context,
    required this.difficulty,
    required this.priority,
    this.tags = const [],
    this.prerequisites = const [],
    this.estimatedDuration,
    this.lastUpdated,
    this.version = '1.0.0',
  });

  final String id;
  final String title;
  final String description;
  final HelpContentType type;
  final HelpContext context;
  final HelpDifficulty difficulty;
  final HelpPriority priority;
  final List<String> tags;
  final List<String> prerequisites;
  final Duration? estimatedDuration;
  final DateTime? lastUpdated;
  final String version;

  Map<String, dynamic> toJson();

  static HelpContent fromJson(Map<String, dynamic> json) {
    final type = HelpContentType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => HelpContentType.documentation,
    );

    switch (type) {
      case HelpContentType.tutorial:
        return Tutorial.fromJson(json);
      case HelpContentType.guide:
        return Guide.fromJson(json);
      case HelpContentType.faq:
        return FAQ.fromJson(json);
      case HelpContentType.troubleshooting:
        return TroubleshootingGuide.fromJson(json);
      case HelpContentType.documentation:
        return Documentation.fromJson(json);
      case HelpContentType.video:
        return VideoTutorial.fromJson(json);
      case HelpContentType.interactive:
        return InteractiveGuide.fromJson(json);
      case HelpContentType.quickTip:
        return QuickTip.fromJson(json);
    }
  }
}

/// Represents a step in a tutorial or guide
class HelpStep {
  const HelpStep({
    required this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    this.videoUrl,
    this.action,
    this.targetWidget,
    this.highlightWidget = false,
    this.showOverlay = false,
    this.duration,
    this.validation,
  });

  final String id;
  final String title;
  final String content;
  final String? imageUrl;
  final String? videoUrl;
  final VoidCallback? action;
  final String? targetWidget; // Widget key for highlighting
  final bool highlightWidget;
  final bool showOverlay;
  final Duration? duration;
  final bool Function()? validation; // Validates if step is completed

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'image_url': imageUrl,
        'video_url': videoUrl,
        'target_widget': targetWidget,
        'highlight_widget': highlightWidget,
        'show_overlay': showOverlay,
        'duration_seconds': duration?.inSeconds,
      };

  static HelpStep fromJson(Map<String, dynamic> json) => HelpStep(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        imageUrl: json['image_url'] as String?,
        videoUrl: json['video_url'] as String?,
        targetWidget: json['target_widget'] as String?,
        highlightWidget: json['highlight_widget'] as bool? ?? false,
        showOverlay: json['show_overlay'] as bool? ?? false,
        duration: json['duration_seconds'] != null
            ? Duration(seconds: json['duration_seconds'] as int)
            : null,
      );
}

/// Interactive tutorial with guided steps
class Tutorial extends HelpContent {
  const Tutorial({
    required super.id,
    required super.title,
    required super.description,
    required super.context,
    required super.difficulty,
    required super.priority,
    required this.steps,
    super.tags,
    super.prerequisites,
    super.estimatedDuration,
    super.lastUpdated,
    super.version,
    this.isInteractive = true,
    this.canSkip = true,
    this.showProgress = true,
  }) : super(type: HelpContentType.tutorial);

  final List<HelpStep> steps;
  final bool isInteractive;
  final bool canSkip;
  final bool showProgress;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'context': context.name,
        'difficulty': difficulty.name,
        'priority': priority.name,
        'tags': tags,
        'prerequisites': prerequisites,
        'estimated_duration_minutes': estimatedDuration?.inMinutes,
        'last_updated': lastUpdated?.toIso8601String(),
        'version': version,
        'steps': steps.map((s) => s.toJson()).toList(),
        'is_interactive': isInteractive,
        'can_skip': canSkip,
        'show_progress': showProgress,
      };

  static Tutorial fromJson(Map<String, dynamic> json) => Tutorial(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        context: HelpContext.values.firstWhere(
          (e) => e.name == json['context'],
          orElse: () => HelpContext.general,
        ),
        difficulty: HelpDifficulty.values.firstWhere(
          (e) => e.name == json['difficulty'],
          orElse: () => HelpDifficulty.beginner,
        ),
        priority: HelpPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => HelpPriority.medium,
        ),
        steps: (json['steps'] as List<dynamic>?)
                ?.map((s) => HelpStep.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        prerequisites:
            (json['prerequisites'] as List<dynamic>?)?.cast<String>() ?? [],
        estimatedDuration: json['estimated_duration_minutes'] != null
            ? Duration(minutes: json['estimated_duration_minutes'] as int)
            : null,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
        version: json['version'] as String? ?? '1.0.0',
        isInteractive: json['is_interactive'] as bool? ?? true,
        canSkip: json['can_skip'] as bool? ?? true,
        showProgress: json['show_progress'] as bool? ?? true,
      );
}

/// Step-by-step guide for specific tasks
class Guide extends HelpContent {
  const Guide({
    required super.id,
    required super.title,
    required super.description,
    required super.context,
    required super.difficulty,
    required super.priority,
    required this.steps,
    super.tags,
    super.prerequisites,
    super.estimatedDuration,
    super.lastUpdated,
    super.version,
    this.category,
  }) : super(type: HelpContentType.guide);

  final List<HelpStep> steps;
  final String? category;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'context': context.name,
        'difficulty': difficulty.name,
        'priority': priority.name,
        'tags': tags,
        'prerequisites': prerequisites,
        'estimated_duration_minutes': estimatedDuration?.inMinutes,
        'last_updated': lastUpdated?.toIso8601String(),
        'version': version,
        'steps': steps.map((s) => s.toJson()).toList(),
        'category': category,
      };

  static Guide fromJson(Map<String, dynamic> json) => Guide(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        context: HelpContext.values.firstWhere(
          (e) => e.name == json['context'],
          orElse: () => HelpContext.general,
        ),
        difficulty: HelpDifficulty.values.firstWhere(
          (e) => e.name == json['difficulty'],
          orElse: () => HelpDifficulty.beginner,
        ),
        priority: HelpPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => HelpPriority.medium,
        ),
        steps: (json['steps'] as List<dynamic>?)
                ?.map((s) => HelpStep.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        prerequisites:
            (json['prerequisites'] as List<dynamic>?)?.cast<String>() ?? [],
        estimatedDuration: json['estimated_duration_minutes'] != null
            ? Duration(minutes: json['estimated_duration_minutes'] as int)
            : null,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
        version: json['version'] as String? ?? '1.0.0',
        category: json['category'] as String?,
      );
}

/// Frequently asked question with answer
class FAQ extends HelpContent {
  const FAQ({
    required super.id,
    required super.title,
    required super.description,
    required super.context,
    required super.difficulty,
    required super.priority,
    required this.question,
    required this.answer,
    super.tags,
    super.prerequisites,
    super.estimatedDuration,
    super.lastUpdated,
    super.version,
    this.relatedFAQs = const [],
    this.category,
  }) : super(type: HelpContentType.faq);

  final String question;
  final String answer;
  final List<String> relatedFAQs;
  final String? category;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'context': context.name,
        'difficulty': difficulty.name,
        'priority': priority.name,
        'tags': tags,
        'prerequisites': prerequisites,
        'estimated_duration_minutes': estimatedDuration?.inMinutes,
        'last_updated': lastUpdated?.toIso8601String(),
        'version': version,
        'question': question,
        'answer': answer,
        'related_faqs': relatedFAQs,
        'category': category,
      };

  static FAQ fromJson(Map<String, dynamic> json) => FAQ(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        context: HelpContext.values.firstWhere(
          (e) => e.name == json['context'],
          orElse: () => HelpContext.general,
        ),
        difficulty: HelpDifficulty.values.firstWhere(
          (e) => e.name == json['difficulty'],
          orElse: () => HelpDifficulty.beginner,
        ),
        priority: HelpPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => HelpPriority.medium,
        ),
        question: json['question'] as String,
        answer: json['answer'] as String,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        prerequisites:
            (json['prerequisites'] as List<dynamic>?)?.cast<String>() ?? [],
        estimatedDuration: json['estimated_duration_minutes'] != null
            ? Duration(minutes: json['estimated_duration_minutes'] as int)
            : null,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
        version: json['version'] as String? ?? '1.0.0',
        relatedFAQs:
            (json['related_faqs'] as List<dynamic>?)?.cast<String>() ?? [],
        category: json['category'] as String?,
      );
}

/// Troubleshooting guide for common issues
class TroubleshootingGuide extends HelpContent {
  const TroubleshootingGuide({
    required super.id,
    required super.title,
    required super.description,
    required super.context,
    required super.difficulty,
    required super.priority,
    required this.problem,
    required this.symptoms,
    required this.solutions,
    super.tags,
    super.prerequisites,
    super.estimatedDuration,
    super.lastUpdated,
    super.version,
    this.commonCauses = const [],
    this.preventionTips = const [],
  }) : super(type: HelpContentType.troubleshooting);

  final String problem;
  final List<String> symptoms;
  final List<HelpStep> solutions;
  final List<String> commonCauses;
  final List<String> preventionTips;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'context': context.name,
        'difficulty': difficulty.name,
        'priority': priority.name,
        'tags': tags,
        'prerequisites': prerequisites,
        'estimated_duration_minutes': estimatedDuration?.inMinutes,
        'last_updated': lastUpdated?.toIso8601String(),
        'version': version,
        'problem': problem,
        'symptoms': symptoms,
        'solutions': solutions.map((s) => s.toJson()).toList(),
        'common_causes': commonCauses,
        'prevention_tips': preventionTips,
      };

  static TroubleshootingGuide fromJson(Map<String, dynamic> json) =>
      TroubleshootingGuide(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        context: HelpContext.values.firstWhere(
          (e) => e.name == json['context'],
          orElse: () => HelpContext.general,
        ),
        difficulty: HelpDifficulty.values.firstWhere(
          (e) => e.name == json['difficulty'],
          orElse: () => HelpDifficulty.beginner,
        ),
        priority: HelpPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => HelpPriority.medium,
        ),
        problem: json['problem'] as String,
        symptoms: (json['symptoms'] as List<dynamic>?)?.cast<String>() ?? [],
        solutions: (json['solutions'] as List<dynamic>?)
                ?.map((s) => HelpStep.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        prerequisites:
            (json['prerequisites'] as List<dynamic>?)?.cast<String>() ?? [],
        estimatedDuration: json['estimated_duration_minutes'] != null
            ? Duration(minutes: json['estimated_duration_minutes'] as int)
            : null,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
        version: json['version'] as String? ?? '1.0.0',
        commonCauses:
            (json['common_causes'] as List<dynamic>?)?.cast<String>() ?? [],
        preventionTips:
            (json['prevention_tips'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

/// Documentation content
class Documentation extends HelpContent {
  const Documentation({
    required super.id,
    required super.title,
    required super.description,
    required super.context,
    required super.difficulty,
    required super.priority,
    required this.content,
    super.tags,
    super.prerequisites,
    super.estimatedDuration,
    super.lastUpdated,
    super.version,
    this.sections = const [],
    this.category,
  }) : super(type: HelpContentType.documentation);

  final String content;
  final List<DocumentationSection> sections;
  final String? category;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'context': context.name,
        'difficulty': difficulty.name,
        'priority': priority.name,
        'tags': tags,
        'prerequisites': prerequisites,
        'estimated_duration_minutes': estimatedDuration?.inMinutes,
        'last_updated': lastUpdated?.toIso8601String(),
        'version': version,
        'content': content,
        'sections': sections.map((s) => s.toJson()).toList(),
        'category': category,
      };

  static Documentation fromJson(Map<String, dynamic> json) => Documentation(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        context: HelpContext.values.firstWhere(
          (e) => e.name == json['context'],
          orElse: () => HelpContext.general,
        ),
        difficulty: HelpDifficulty.values.firstWhere(
          (e) => e.name == json['difficulty'],
          orElse: () => HelpDifficulty.beginner,
        ),
        priority: HelpPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => HelpPriority.medium,
        ),
        content: json['content'] as String,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        prerequisites:
            (json['prerequisites'] as List<dynamic>?)?.cast<String>() ?? [],
        estimatedDuration: json['estimated_duration_minutes'] != null
            ? Duration(minutes: json['estimated_duration_minutes'] as int)
            : null,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
        version: json['version'] as String? ?? '1.0.0',
        sections: (json['sections'] as List<dynamic>?)
                ?.map((s) =>
                    DocumentationSection.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        category: json['category'] as String?,
      );
}

/// Video tutorial content
class VideoTutorial extends HelpContent {
  const VideoTutorial({
    required super.id,
    required super.title,
    required super.description,
    required super.context,
    required super.difficulty,
    required super.priority,
    required this.videoUrl,
    super.tags,
    super.prerequisites,
    super.estimatedDuration,
    super.lastUpdated,
    super.version,
    this.thumbnailUrl,
    this.transcript,
    this.chapters = const [],
  }) : super(type: HelpContentType.video);

  final String videoUrl;
  final String? thumbnailUrl;
  final String? transcript;
  final List<VideoChapter> chapters;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'context': context.name,
        'difficulty': difficulty.name,
        'priority': priority.name,
        'tags': tags,
        'prerequisites': prerequisites,
        'estimated_duration_minutes': estimatedDuration?.inMinutes,
        'last_updated': lastUpdated?.toIso8601String(),
        'version': version,
        'video_url': videoUrl,
        'thumbnail_url': thumbnailUrl,
        'transcript': transcript,
        'chapters': chapters.map((c) => c.toJson()).toList(),
      };

  static VideoTutorial fromJson(Map<String, dynamic> json) => VideoTutorial(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        context: HelpContext.values.firstWhere(
          (e) => e.name == json['context'],
          orElse: () => HelpContext.general,
        ),
        difficulty: HelpDifficulty.values.firstWhere(
          (e) => e.name == json['difficulty'],
          orElse: () => HelpDifficulty.beginner,
        ),
        priority: HelpPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => HelpPriority.medium,
        ),
        videoUrl: json['video_url'] as String,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        prerequisites:
            (json['prerequisites'] as List<dynamic>?)?.cast<String>() ?? [],
        estimatedDuration: json['estimated_duration_minutes'] != null
            ? Duration(minutes: json['estimated_duration_minutes'] as int)
            : null,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
        version: json['version'] as String? ?? '1.0.0',
        thumbnailUrl: json['thumbnail_url'] as String?,
        transcript: json['transcript'] as String?,
        chapters: (json['chapters'] as List<dynamic>?)
                ?.map((c) => VideoChapter.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Interactive guide with user interactions
class InteractiveGuide extends HelpContent {
  const InteractiveGuide({
    required super.id,
    required super.title,
    required super.description,
    required super.context,
    required super.difficulty,
    required super.priority,
    required this.steps,
    super.tags,
    super.prerequisites,
    super.estimatedDuration,
    super.lastUpdated,
    super.version,
    this.allowSkipping = true,
    this.showProgress = true,
    this.requiresCompletion = false,
  }) : super(type: HelpContentType.interactive);

  final List<HelpStep> steps;
  final bool allowSkipping;
  final bool showProgress;
  final bool requiresCompletion;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'context': context.name,
        'difficulty': difficulty.name,
        'priority': priority.name,
        'tags': tags,
        'prerequisites': prerequisites,
        'estimated_duration_minutes': estimatedDuration?.inMinutes,
        'last_updated': lastUpdated?.toIso8601String(),
        'version': version,
        'steps': steps.map((s) => s.toJson()).toList(),
        'allow_skipping': allowSkipping,
        'show_progress': showProgress,
        'requires_completion': requiresCompletion,
      };

  static InteractiveGuide fromJson(Map<String, dynamic> json) =>
      InteractiveGuide(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        context: HelpContext.values.firstWhere(
          (e) => e.name == json['context'],
          orElse: () => HelpContext.general,
        ),
        difficulty: HelpDifficulty.values.firstWhere(
          (e) => e.name == json['difficulty'],
          orElse: () => HelpDifficulty.beginner,
        ),
        priority: HelpPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => HelpPriority.medium,
        ),
        steps: (json['steps'] as List<dynamic>?)
                ?.map((s) => HelpStep.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        prerequisites:
            (json['prerequisites'] as List<dynamic>?)?.cast<String>() ?? [],
        estimatedDuration: json['estimated_duration_minutes'] != null
            ? Duration(minutes: json['estimated_duration_minutes'] as int)
            : null,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
        version: json['version'] as String? ?? '1.0.0',
        allowSkipping: json['allow_skipping'] as bool? ?? true,
        showProgress: json['show_progress'] as bool? ?? true,
        requiresCompletion: json['requires_completion'] as bool? ?? false,
      );
}

/// Quick tip for immediate help
class QuickTip extends HelpContent {
  const QuickTip({
    required super.id,
    required super.title,
    required super.description,
    required super.context,
    required super.difficulty,
    required super.priority,
    required this.tip,
    super.tags,
    super.prerequisites,
    super.estimatedDuration,
    super.lastUpdated,
    super.version,
    this.icon,
    this.actionText,
    this.action,
  }) : super(type: HelpContentType.quickTip);

  final String tip;
  final IconData? icon;
  final String? actionText;
  final VoidCallback? action;

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'context': context.name,
        'difficulty': difficulty.name,
        'priority': priority.name,
        'tags': tags,
        'prerequisites': prerequisites,
        'estimated_duration_minutes': estimatedDuration?.inMinutes,
        'last_updated': lastUpdated?.toIso8601String(),
        'version': version,
        'tip': tip,
        'action_text': actionText,
      };

  static QuickTip fromJson(Map<String, dynamic> json) => QuickTip(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        context: HelpContext.values.firstWhere(
          (e) => e.name == json['context'],
          orElse: () => HelpContext.general,
        ),
        difficulty: HelpDifficulty.values.firstWhere(
          (e) => e.name == json['difficulty'],
          orElse: () => HelpDifficulty.beginner,
        ),
        priority: HelpPriority.values.firstWhere(
          (e) => e.name == json['priority'],
          orElse: () => HelpPriority.medium,
        ),
        tip: json['tip'] as String,
        tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
        prerequisites:
            (json['prerequisites'] as List<dynamic>?)?.cast<String>() ?? [],
        estimatedDuration: json['estimated_duration_minutes'] != null
            ? Duration(minutes: json['estimated_duration_minutes'] as int)
            : null,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
        version: json['version'] as String? ?? '1.0.0',
        actionText: json['action_text'] as String?,
      );
}

/// Documentation section
class DocumentationSection {
  const DocumentationSection({
    required this.id,
    required this.title,
    required this.content,
    this.subsections = const [],
    this.order = 0,
  });

  final String id;
  final String title;
  final String content;
  final List<DocumentationSection> subsections;
  final int order;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'subsections': subsections.map((s) => s.toJson()).toList(),
        'order': order,
      };

  static DocumentationSection fromJson(Map<String, dynamic> json) =>
      DocumentationSection(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        subsections: (json['subsections'] as List<dynamic>?)
                ?.map((s) =>
                    DocumentationSection.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        order: json['order'] as int? ?? 0,
      );
}

/// Video chapter
class VideoChapter {
  const VideoChapter({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    this.description,
  });

  final String id;
  final String title;
  final Duration startTime;
  final Duration? endTime;
  final String? description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start_time_seconds': startTime.inSeconds,
        'end_time_seconds': endTime?.inSeconds,
        'description': description,
      };

  static VideoChapter fromJson(Map<String, dynamic> json) => VideoChapter(
        id: json['id'] as String,
        title: json['title'] as String,
        startTime: Duration(seconds: json['start_time_seconds'] as int),
        endTime: json['end_time_seconds'] != null
            ? Duration(seconds: json['end_time_seconds'] as int)
            : null,
        description: json['description'] as String?,
      );
}

/// User progress tracking for help content
class HelpProgress {
  const HelpProgress({
    required this.contentId,
    required this.userId,
    this.isCompleted = false,
    this.currentStep = 0,
    this.completedSteps = const [],
    this.startedAt,
    this.completedAt,
    this.lastAccessedAt,
    this.timeSpent = Duration.zero,
  });

  final String contentId;
  final String userId;
  final bool isCompleted;
  final int currentStep;
  final List<int> completedSteps;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? lastAccessedAt;
  final Duration timeSpent;

  HelpProgress copyWith({
    String? contentId,
    String? userId,
    bool? isCompleted,
    int? currentStep,
    List<int>? completedSteps,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? lastAccessedAt,
    Duration? timeSpent,
  }) =>
      HelpProgress(
        contentId: contentId ?? this.contentId,
        userId: userId ?? this.userId,
        isCompleted: isCompleted ?? this.isCompleted,
        currentStep: currentStep ?? this.currentStep,
        completedSteps: completedSteps ?? this.completedSteps,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
        timeSpent: timeSpent ?? this.timeSpent,
      );

  Map<String, dynamic> toJson() => {
        'content_id': contentId,
        'user_id': userId,
        'is_completed': isCompleted,
        'current_step': currentStep,
        'completed_steps': completedSteps,
        'started_at': startedAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'last_accessed_at': lastAccessedAt?.toIso8601String(),
        'time_spent_seconds': timeSpent.inSeconds,
      };

  static HelpProgress fromJson(Map<String, dynamic> json) => HelpProgress(
        contentId: json['content_id'] as String,
        userId: json['user_id'] as String,
        isCompleted: json['is_completed'] as bool? ?? false,
        currentStep: json['current_step'] as int? ?? 0,
        completedSteps:
            (json['completed_steps'] as List<dynamic>?)?.cast<int>() ?? [],
        startedAt: json['started_at'] != null
            ? DateTime.parse(json['started_at'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        lastAccessedAt: json['last_accessed_at'] != null
            ? DateTime.parse(json['last_accessed_at'] as String)
            : null,
        timeSpent: Duration(seconds: json['time_spent_seconds'] as int? ?? 0),
      );
}

/// Onboarding flow configuration
class OnboardingFlow {
  const OnboardingFlow({
    required this.id,
    required this.name,
    required this.description,
    required this.steps,
    this.isRequired = false,
    this.targetUserType,
    this.minimumAppVersion,
    this.showOnFirstLaunch = true,
    this.canSkip = true,
  });

  final String id;
  final String name;
  final String description;
  final List<Tutorial> steps;
  final bool isRequired;
  final String? targetUserType;
  final String? minimumAppVersion;
  final bool showOnFirstLaunch;
  final bool canSkip;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'steps': steps.map((s) => s.toJson()).toList(),
        'is_required': isRequired,
        'target_user_type': targetUserType,
        'minimum_app_version': minimumAppVersion,
        'show_on_first_launch': showOnFirstLaunch,
        'can_skip': canSkip,
      };

  static OnboardingFlow fromJson(Map<String, dynamic> json) => OnboardingFlow(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        steps: (json['steps'] as List<dynamic>?)
                ?.map((s) => Tutorial.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        isRequired: json['is_required'] as bool? ?? false,
        targetUserType: json['target_user_type'] as String?,
        minimumAppVersion: json['minimum_app_version'] as String?,
        showOnFirstLaunch: json['show_on_first_launch'] as bool? ?? true,
        canSkip: json['can_skip'] as bool? ?? true,
      );
}

/// Help search result
class HelpSearchResult {
  const HelpSearchResult({
    required this.content,
    required this.relevanceScore,
    this.matchedTerms = const [],
    this.highlightedContent,
  });

  final HelpContent content;
  final double relevanceScore;
  final List<String> matchedTerms;
  final String? highlightedContent;

  Map<String, dynamic> toJson() => {
        'content': content.toJson(),
        'relevance_score': relevanceScore,
        'matched_terms': matchedTerms,
        'highlighted_content': highlightedContent,
      };
}

/// Help analytics data
class HelpAnalytics {
  const HelpAnalytics({
    required this.contentId,
    required this.views,
    required this.completions,
    required this.averageTimeSpent,
    required this.userRating,
    this.feedbackCount = 0,
    this.lastUpdated,
  });

  final String contentId;
  final int views;
  final int completions;
  final Duration averageTimeSpent;
  final double userRating;
  final int feedbackCount;
  final DateTime? lastUpdated;

  double get completionRate => views > 0 ? completions / views : 0.0;

  Map<String, dynamic> toJson() => {
        'content_id': contentId,
        'views': views,
        'completions': completions,
        'average_time_spent_seconds': averageTimeSpent.inSeconds,
        'user_rating': userRating,
        'feedback_count': feedbackCount,
        'last_updated': lastUpdated?.toIso8601String(),
      };

  static HelpAnalytics fromJson(Map<String, dynamic> json) => HelpAnalytics(
        contentId: json['content_id'] as String,
        views: json['views'] as int,
        completions: json['completions'] as int,
        averageTimeSpent:
            Duration(seconds: json['average_time_spent_seconds'] as int),
        userRating: (json['user_rating'] as num).toDouble(),
        feedbackCount: json['feedback_count'] as int? ?? 0,
        lastUpdated: json['last_updated'] != null
            ? DateTime.parse(json['last_updated'] as String)
            : null,
      );
}
