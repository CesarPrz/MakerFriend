import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/login_page.dart';

import 'package:maker_friend/screens/my_projects_page.dart';
import 'package:maker_friend/screens/project_detail_page.dart';
import 'package:maker_friend/screens/timeline_page.dart';
import 'package:maker_friend/screens/new_timeline_item_page.dart';
import 'package:maker_friend/screens/timeline_item_page.dart';

class AuthListenable extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;

  AuthListenable() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class AppRouter {
  static final AuthListenable _authListenable = AuthListenable();

  static GoRouter router() {
    return GoRouter(
      initialLocation: '/projects',
      refreshListenable: _authListenable,
      redirect: (context, state) {
        final loggedIn = FirebaseAuth.instance.currentUser != null;
        final goingToLogin = state.matchedLocation == '/login';

        if (!loggedIn && !goingToLogin) return '/login';
        if (loggedIn && goingToLogin) return '/projects';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/projects',
          builder: (context, state) => const MyProjectsPage(),
          routes: [
            GoRoute(
              path: ':projectId',
              builder: (context, state) {
                final projectId = state.pathParameters['projectId']!;
                return ProjectDetailPage(projectId: projectId);
              },
              routes: [
                GoRoute(
                  path: 'timeline',
                  builder: (context, state) {
                    final projectId = state.pathParameters['projectId']!;
                    return TimelinePage(projectId: projectId);
                  },
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) {
                        final projectId = state.pathParameters['projectId']!;
                        return NewTimelineItemPage(projectId: projectId);
                      },
                    ),
                    GoRoute(
                      path: ':itemId',
                      builder: (context, state) {
                        final projectId = state.pathParameters['projectId']!;
                        final itemId = state.pathParameters['itemId']!;
                        final title = (state.extra as String?) ?? 'Post';

                        return TimelineItemPage(
                          projectId: projectId,
                          itemId: itemId,
                          title: title,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
