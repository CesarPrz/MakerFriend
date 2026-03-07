import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maker_friend/features/feed/cubit/feed_cubit.dart';
import 'package:maker_friend/models/timeline_item_model.dart';
import 'package:maker_friend/repositories/timeline_repository.dart';

void main() {
  test('groups feed entries by project and author', () async {
    final controller = StreamController<List<FollowingFeedItem>>();
    final cubit = FeedCubit(feedStream: controller.stream);

    final itemA = TimelineItem(
      id: 'a',
      type: TimelineItemType.post,
      title: 'A',
      authorUid: 'u1',
      createdAt: DateTime.now(),
    );
    final itemB = TimelineItem(
      id: 'b',
      type: TimelineItemType.post,
      title: 'B',
      authorUid: 'u1',
      createdAt: DateTime.now(),
    );
    final itemC = TimelineItem(
      id: 'c',
      type: TimelineItemType.post,
      title: 'C',
      authorUid: 'u2',
      createdAt: DateTime.now(),
    );

    controller.add([
      FollowingFeedItem(
        projectId: 'p1',
        projectTitle: 'P1',
        projectCoverUrl: null,
        item: itemA,
      ),
      FollowingFeedItem(
        projectId: 'p1',
        projectTitle: 'P1',
        projectCoverUrl: null,
        item: itemB,
      ),
      FollowingFeedItem(
        projectId: 'p2',
        projectTitle: 'P2',
        projectCoverUrl: null,
        item: itemC,
      ),
    ]);

    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(cubit.state.groups.length, 2);
    expect(cubit.state.groups.first.items.length, 2);

    await cubit.close();
    await controller.close();
  });
}
