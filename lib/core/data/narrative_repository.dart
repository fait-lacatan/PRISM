import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/narrative_chapter.dart';
import '../models/chapter_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

final narrativeRepositoryProvider = Provider<NarrativeRepository>((ref) {
  return NarrativeRepository();
});

final narrativeFlowProvider = FutureProvider<List<NarrativeChapter>>((ref) async {
  final repo = ref.watch(narrativeRepositoryProvider);
  return repo.loadNarrativeFlow();
});

final narrativeChapterContentProvider = FutureProvider.family<String, String>((ref, filename) async {
  final repo = ref.watch(narrativeRepositoryProvider);
  return repo.loadChapterContent(filename);
});

/// Loads and parses a chapter's section-array JSON into a typed [ChapterData].
final chapterDataProvider = FutureProvider.family<ChapterData, String>((ref, jsonFilename) async {
  final repo = ref.watch(narrativeRepositoryProvider);
  return repo.loadChapterData(jsonFilename);
});

final currentNarrativeIndexProvider = NotifierProvider<NarrativeIndexNotifier, int>(() {
  return NarrativeIndexNotifier();
});

class NarrativeIndexNotifier extends Notifier<int> {
  static const _key = 'currentNarrativeIndex';

  @override
  int build() {
    _load();
    return 0; // default state while loading
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getInt(_key) ?? 0;
  }

  Future<void> setIndex(int index) async {
    state = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, index);
  }
}

class NarrativeRepository {
  Future<List<NarrativeChapter>> loadNarrativeFlow() async {
    final String jsonString = await rootBundle.loadString('assets/content/narrative_flow.json');
    final Map<String, dynamic> data = jsonDecode(jsonString);
    final List<dynamic> chaptersJson = data['chapters'];
    
    return chaptersJson.map((json) => NarrativeChapter.fromJson(json)).toList();
  }

  Future<String> loadChapterContent(String filename) async {
    try {
      return await rootBundle.loadString('assets/content/$filename');
    } catch (e) {
      return 'Error loading content: $e';
    }
  }

  /// Loads a chapter's JSON and returns a typed [ChapterData] model.
  Future<ChapterData> loadChapterData(String jsonFilename) async {
    final raw = await rootBundle.loadString('assets/content/$jsonFilename');
    final Map<String, dynamic> parsed = jsonDecode(raw);
    return ChapterData.fromJson(parsed);
  }
}
