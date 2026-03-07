import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maker_friend/models/project_model.dart';

class DiscoverState {
  final bool loading;
  final String? error;
  final List<Project> projects;
  final List<Project> sortedProjects;
  final List<String> tags;
  final Set<String> selectedTags;

  const DiscoverState({
    this.loading = true,
    this.error,
    this.projects = const [],
    this.sortedProjects = const [],
    this.tags = const [],
    this.selectedTags = const {},
  });

  DiscoverState copyWith({
    bool? loading,
    String? error,
    List<Project>? projects,
    List<Project>? sortedProjects,
    List<String>? tags,
    Set<String>? selectedTags,
  }) {
    return DiscoverState(
      loading: loading ?? this.loading,
      error: error,
      projects: projects ?? this.projects,
      sortedProjects: sortedProjects ?? this.sortedProjects,
      tags: tags ?? this.tags,
      selectedTags: selectedTags ?? this.selectedTags,
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
      (projects) => _emitComputed(projects: projects, selectedTags: state.selectedTags),
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
    _emitComputed(projects: state.projects, selectedTags: next);
  }

  void clearTags() {
    _emitComputed(projects: state.projects, selectedTags: <String>{});
  }

  void _emitComputed({
    required List<Project> projects,
    required Set<String> selectedTags,
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
    );

    emit(
      state.copyWith(
        loading: false,
        error: null,
        projects: projects,
        sortedProjects: sortedProjects,
        tags: tags,
        selectedTags: selectedTags,
      ),
    );
  }

  List<Project> _sortProjects({
    required List<Project> projects,
    required Set<String> selectedTags,
  }) {
    if (selectedTags.isEmpty) return projects;

    final selected = selectedTags.map((e) => e.toLowerCase()).toSet();
    final sorted = [...projects];
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

      final ad = a.lastTimelineUpdate;
      final bd = b.lastTimelineUpdate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });
    return sorted;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
