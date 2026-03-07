import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maker_friend/features/discover/cubit/discover_cubit.dart';
import 'package:maker_friend/models/project_model.dart';

void main() {
  test('sorts projects using selected tags', () async {
    final controller = StreamController<List<Project>>();
    final cubit = DiscoverCubit(projectsStream: controller.stream);

    final p1 = Project(
      id: '1',
      ownerUid: 'u1',
      title: 'Projet A',
      types: const ['print'],
      lastTimelineUpdate: DateTime.now().subtract(const Duration(hours: 1)),
    );
    final p2 = Project(
      id: '2',
      ownerUid: 'u2',
      title: 'Projet B',
      types: const ['robot', 'print'],
      lastTimelineUpdate: DateTime.now(),
    );

    controller.add([p1, p2]);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(cubit.state.sortedProjects.first.id, '2');

    cubit.toggleTag('robot');
    await Future<void>.delayed(const Duration(milliseconds: 1));
    expect(cubit.state.selectedTags.contains('robot'), true);
    expect(cubit.state.sortedProjects.first.id, '2');

    await cubit.close();
    await controller.close();
  });
}
