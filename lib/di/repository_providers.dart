import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maker_friend/repositories/notification_repository.dart';
import 'package:maker_friend/repositories/project_repository.dart';
import 'package:maker_friend/repositories/timeline_repository.dart';
import 'package:maker_friend/repositories/user_repository.dart';

List<RepositoryProvider<dynamic>> buildRepositoryProviders() {
  final notifications = NotificationRepository();
  final users = UserRepository(notifications: notifications);
  final projects = ProjectRepository(notifications: notifications);
  final timelines = TimelineRepository(notifications: notifications);

  return [
    RepositoryProvider<NotificationRepository>.value(value: notifications),
    RepositoryProvider<UserRepository>.value(value: users),
    RepositoryProvider<ProjectRepository>.value(value: projects),
    RepositoryProvider<TimelineRepository>.value(value: timelines),
  ];
}
