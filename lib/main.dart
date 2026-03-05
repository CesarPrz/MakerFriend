import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maker_friend/repositories/project_repository.dart';
import 'package:maker_friend/repositories/timeline_repository.dart';
import 'package:maker_friend/repositories/user_repository.dart';
import 'package:maker_friend/themes/app_theme.dart';
import 'package:maker_friend/themes/theme_controller.dart';
import 'firebase_options.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.router();

    return ValueListenableBuilder(
      valueListenable: ThemeController.mode,
      builder: (_, ThemeMode mode, __) {
        return MultiRepositoryProvider(
          providers: [
            RepositoryProvider(create: (_) => UserRepository()),
            RepositoryProvider(create: (_) => ProjectRepository()),
            RepositoryProvider(create: (_) => TimelineRepository()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            routerConfig: router,
          ),
        );
      },
    );
  }
}
