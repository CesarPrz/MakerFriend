import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maker_friend/features/profile/cubit/profile_projects_cubit.dart';
import 'package:maker_friend/models/project_model.dart';

void main() {
  test('emits projects from stream', () async {
    final controller = StreamController<List<Project>>();
    final cubit = ProfileProjectsCubit(projectsStream: controller.stream);

    final projects = [
      Project(id: '1', ownerUid: 'u1', title: 'Projet 1'),
      Project(id: '2', ownerUid: 'u1', title: 'Projet 2'),
    ];

    controller.add(projects);
    await Future<void>.delayed(const Duration(milliseconds: 1));

    expect(cubit.state.loading, false);
    expect(cubit.state.projects.length, 2);

    await cubit.close();
    await controller.close();
  });
}
