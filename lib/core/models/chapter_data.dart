// Typed models for the section-array JSON content schema.
//
// Each chapter defines an ordered list of [ChapterSection]s.
// The [ChapterRenderer] maps each section's [template] key to a
// shared template widget and injects its [data] payload.

class ChapterData {
  final String id;
  final String title;
  final String subtitle;
  final String accentColor;
  final List<ChapterSection> sections;

  const ChapterData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.sections,
  });

  factory ChapterData.fromJson(Map<String, dynamic> json) {
    final rawSections = json['sections'] as List<dynamic>? ?? [];
    return ChapterData(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      accentColor: json['accent_color'] as String? ?? '#3B82F6',
      sections: rawSections
          .map((s) => ChapterSection.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChapterSection {
  final String template;
  final Map<String, dynamic> data;

  const ChapterSection({
    required this.template,
    required this.data,
  });

  factory ChapterSection.fromJson(Map<String, dynamic> json) {
    return ChapterSection(
      template: json['template'] as String,
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }
}
