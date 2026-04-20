class NarrativeChapter {
  final String id;
  final String title;
  final String subtitle;
  final String file;
  final String contentType;
  final bool hasInteractiveWidget;
  final String? widgetType;

  const NarrativeChapter({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.file,
    required this.contentType,
    required this.hasInteractiveWidget,
    this.widgetType,
  });

  factory NarrativeChapter.fromJson(Map<String, dynamic> json) {
    return NarrativeChapter(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      file: json['file'] as String,
      contentType: json['content_type'] as String? ?? 'md',
      hasInteractiveWidget: json['has_interactive_widget'] as bool? ?? false,
      widgetType: json['widget_type'] as String?,
    );
  }
}
