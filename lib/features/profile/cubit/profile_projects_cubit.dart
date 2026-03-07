import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maker_friend/models/project_model.dart';

class ProfileProjectsState {
  final bool loading;
  final String? error;
  final List<Project> projects;

  const ProfileProjectsState({
    this.loading = true,
    this.error,
    this.projects = const [],
  });

  ProfileProjectsState copyWith({
    bool? loading,
    String? error,
    List<Project>? projects,
  }) {
    return ProfileProjectsState(
      loading: loading ?? this.loading,
      error: error,
      projects: projects ?? this.projects,
    );
  }
}

class ProfileProjectsCubit extends Cubit<ProfileProjectsState> {
  final Stream<List<Project>> _projectsStream;
  StreamSubscription<List<Project>>? _sub;

  ProfileProjectsCubit({required Stream<List<Project>> projectsStream})
    : _projectsStream = projectsStream,
      super(const ProfileProjectsState()) {
    _sub = _projectsStream.listen(
      (projects) {
        emit(
          state.copyWith(
            loading: false,
            error: null,
            projects: projects,
          ),
        );
      },
      onError: (e) => emit(state.copyWith(loading: false, error: e.toString())),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
