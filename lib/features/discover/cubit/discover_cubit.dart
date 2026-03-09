import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maker_friend/models/project_model.dart';

enum DiscoverSortMode { newest, popular }

class DiscoverState {
  final bool loading;
  final String? error;
  final List<Project> projects;
  final List<Project> sortedProjects;
  final List<String> tags;
  final Set<String> selectedTags;
  final DiscoverSortMode sortMode;

  const DiscoverState({
    this.loading = true,
    this.error,
    this.projects = const [],
    this.sortedProjects = const [],
    this.tags = const [],
    this.selectedTags = const {},
    this.sortMode = DiscoverSortMode.newest,
  });

  DiscoverState copyWith({
    bool? loading,
    String? error,
    List<Project>? projects,
    List<Project>? sortedProjects,
    List<String>? tags,
    Set<String>? selectedTags,
    DiscoverSortMode? sortMode,
  }) {
    return DiscoverState(
      loading: loading ?? this.loading,
      error: error,
      projects: projects ?? this.projects,
      sortedProjects: sortedProjects ?? this.sortedProjects,
      tags: tags ?? this.tags,
      selectedTags: selectedTags ?? this.selectedTags,
      sortMode: sortMode ?? this.sortMode,
    );
  }
}

class DiscoverCubit extends Cubit<DiscoverState> {
  final Stream<List<Project>> _projectsStream;
  StreamSubscription<List<Project>>? _sub;

  DiscoverCubit({required Stream<List<Project>> projectsStream})
    : _projectsStream = projectsStream,
      super(const DiscoverState()) {
    _sub = _projectsStream.listen(
      (projects) => _emitComputed(
        projects: projects,
        selectedTags: state.selectedTags,
        sortMode: state.sortMode,
      ),
      onError: (e) {
        emit(state.copyWith(loading: false, error: e.toString()));
      },
    );
  }

  void toggleTag(String tag) {
    final next = <String>{...state.selectedTags};
    if (next.contains(tag)) {
      next.remove(tag);
    } else {
      next.add(tag);
    }
    _emitComputed(
      projects: state.projects,
      selectedTags: next,
      sortMode: state.sortMode,
    );
  }

  void clearTags() {
    _emitComputed(
      projects: state.projects,
      selectedTags: <String>{},
      sortMode: state.sortMode,
    );
  }

  void setSingleTag(String? tag) {
    final trimmed = tag?.trim() ?? '';
    final next = trimmed.isEmpty ? <String>{} : <String>{trimmed};
    if (next.length == state.selectedTags.length &&
        next.every(state.selectedTags.contains)) {
      return;
    }
    _emitComputed(
      projects: state.projects,
      selectedTags: next,
      sortMode: state.sortMode,
    );
  }

  void setSortMode(DiscoverSortMode mode) {
    if (mode == state.sortMode) return;
    _emitComputed(
      projects: state.projects,
      selectedTags: state.selectedTags,
      sortMode: mode,
    );
  }

  void _emitComputed({
    required List<Project> projects,
    required Set<String> selectedTags,
    required DiscoverSortMode sortMode,
  }) {
    final tags = projects
        .expand((p) => p.types)
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final sortedProjects = _sortProjects(
      projects: projects,
      selectedTags: selectedTags,
      sortMode: sortMode,
    );

    emit(
      state.copyWith(
        loading: false,
        error: null,
        projects: projects,
        sortedProjects: sortedProjects,
        tags: tags,
        selectedTags: selectedTags,
        sortMode: sortMode,
      ),
    );
  }

  int _compareBySortMode(Project a, Project b, DiscoverSortMode sortMode) {
    if (sortMode == DiscoverSortMode.popular) {
      final likesDiff = b.likesCount - a.likesCount;
      if (likesDiff != 0) return likesDiff;
    }

    final ad = a.lastTimelineUpdate ?? a.createdAt;
    final bd = b.lastTimelineUpdate ?? b.createdAt;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  }

  List<Project> _sortProjects({
    required List<Project> projects,
    required Set<String> selectedTags,
    required DiscoverSortMode sortMode,
  }) {
    final sorted = [...projects];
    if (selectedTags.isEmpty) {
      sorted.sort((a, b) => _compareBySortMode(a, b, sortMode));
      return sorted;
    }

    final selected = selectedTags.map((e) => e.toLowerCase()).toSet();
    sorted.sort((a, b) {
      int score(Project p) {
        var s = 0;
        for (final t in p.types) {
          if (selected.contains(t.toLowerCase())) s++;
        }
        return s;
      }

      final scoreDiff = score(b) - score(a);
      if (scoreDiff != 0) return scoreDiff;
      return _compareBySortMode(a, b, sortMode);
    });
    return sorted;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
