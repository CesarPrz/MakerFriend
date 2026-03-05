import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:maker_friend/login_page.dart';
import 'package:maker_friend/screens/discover_page.dart';
import 'package:maker_friend/screens/main_scaffold.dart';
import 'package:maker_friend/screens/my_projects_page.dart';
import 'package:maker_friend/screens/profile_page.dart';
import 'package:maker_friend/screens/project_form_page.dart';
import 'package:maker_friend/screens/settings_page.dart';
import 'package:maker_friend/screens/theme_settings_page.dart';

import '../screens/project_detail_page.dart';
import '../screens/timeline_page.dart';
import '../screens/new_timeline_item_page.dart';
import '../screens/timeline_item_page.dart';

class AuthListenable extends ChangeNotifier {
  late final StreamSubscription<User?> _sub;
  AuthListenable() {
    _sub = FirebaseAuth.instance.authStateChanges().listen(
      (_) => notifyListeners(),
    );
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

class AppRouter {
  static final _auth = AuthListenable();

  static GoRouter router() {
    return GoRouter(
      initialLocation: '/my-projects',
      refreshListenable: _auth,
      redirect: (context, state) {
        final loggedIn = FirebaseAuth.instance.currentUser != null;
        final goingToLogin = state.matchedLocation == '/login';
        if (!loggedIn && !goingToLogin) return '/login';
        if (loggedIn && goingToLogin) return '/my-projects';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),

        /// ✅ Shell avec bottom navigation
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainScaffold(navigationShell: navigationShell);
          },
          branches: [
            // 1) Découvrir
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/discover',
                  builder: (context, state) => const DiscoverPage(),
                ),
              ],
            ),

            // 2) Mes projets
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/my-projects',
                  builder: (context, state) => const ProfilePage(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      builder: (context, state) => const ProjectFormPage(),
                    ),
                    GoRoute(
                      path: ':projectId',
                      builder: (context, state) {
                        final projectId = state.pathParameters['projectId']!;
                        return ProjectDetailPage(projectId: projectId);
                      },
                      routes: [
                        GoRoute(
                          path: 'edit',
                          builder: (context, state) {
                            final id = state.pathParameters['projectId']!;
                            return ProjectFormPage(projectId: id);
                          },
                        ),
                        GoRoute(
                          path: 'timeline',
                          builder: (context, state) {
                            final projectId =
                                state.pathParameters['projectId']!;
                            return TimelinePage(projectId: projectId);
                          },
                          routes: [
                            GoRoute(
                              path: 'new',
                              builder: (context, state) {
                                final projectId =
                                    state.pathParameters['projectId']!;
                                return NewTimelineItemPage(
                                  projectId: projectId,
                                );
                              },
                            ),
                            GoRoute(
                              path: ':itemId',
                              builder: (context, state) {
                                final projectId =
                                    state.pathParameters['projectId']!;
                                final itemId = state.pathParameters['itemId']!;
                                final title =
                                    (state.extra as String?) ?? 'Post';
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
            ),

            // 3) Paramètres
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => const SettingsPage(),
                  routes: [
                    GoRoute(
                      path: 'theme',
                      builder: (context, state) => const ThemeSettingsPage(),
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
