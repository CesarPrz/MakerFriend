import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maker_friend/repositories/timeline_repository.dart';

class FeedGroup {
  final String projectId;
  final String projectTitle;
  final String authorUid;
  final String? authorName;
  final String? authorPhotoUrl;
  final String? projectCoverUrl;
  final List<FollowingFeedItem> items;

  FeedGroup({
    required this.projectId,
    required this.projectTitle,
    required this.authorUid,
    required this.authorName,
    required this.authorPhotoUrl,
    required this.projectCoverUrl,
    required this.items,
  });
}

class FeedState {
  final bool loading;
  final String? error;
  final List<FollowingFeedItem> items;
  final List<FeedGroup> groups;

  const FeedState({
    this.loading = true,
    this.error,
    this.items = const [],
    this.groups = const [],
  });

  FeedState copyWith({
    bool? loading,
    String? error,
    List<FollowingFeedItem>? items,
    List<FeedGroup>? groups,
  }) {
    return FeedState(
      loading: loading ?? this.loading,
      error: error,
      items: items ?? this.items,
      groups: groups ?? this.groups,
    );
  }
}

class FeedCubit extends Cubit<FeedState> {
  final Stream<List<FollowingFeedItem>> _feedStream;
  StreamSubscription<List<FollowingFeedItem>>? _sub;

  FeedCubit({required Stream<List<FollowingFeedItem>> feedStream})
    : _feedStream = feedStream,
      super(const FeedState()) {
    _sub = _feedStream.listen(
      (items) {
        emit(
          state.copyWith(
            loading: false,
            error: null,
            items: items,
            groups: _groupFeed(items),
          ),
        );
      },
      onError: (e) => emit(state.copyWith(loading: false, error: e.toString())),
    );
  }

  List<FeedGroup> _groupFeed(List<FollowingFeedItem> feed) {
    final groups = <FeedGroup>[];
    for (final entry in feed) {
      if (groups.isNotEmpty) {
        final last = groups.last;
        if (last.projectId == entry.projectId &&
            last.authorUid == entry.item.authorUid) {
          last.items.add(entry);
          continue;
        }
      }

      groups.add(
        FeedGroup(
          projectId: entry.projectId,
          projectTitle: entry.projectTitle,
          authorUid: entry.item.authorUid,
          authorName: entry.item.authorName,
          authorPhotoUrl: entry.item.authorPhotoUrl,
          projectCoverUrl: entry.projectCoverUrl,
          items: [entry],
        ),
      );
    }
    return groups;
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
