import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:maker_friend/core/flavor/flavor_config.dart';
import 'package:maker_friend/di/bloc_providers.dart';
import 'package:maker_friend/di/repository_providers.dart';
import 'package:maker_friend/routing/app_router.dart';
import 'package:maker_friend/themes/app_theme.dart';
import 'package:maker_friend/themes/theme_controller.dart';

class MakerFlowApp extends StatelessWidget {
  final FlavorConfig flavor;

  const MakerFlowApp({super.key, required this.flavor});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter.router();
    return ValueListenableBuilder(
      valueListenable: ThemeController.mode,
      builder: (_, ThemeMode mode, __) {
        return MultiRepositoryProvider(
          providers: buildRepositoryProviders(),
          child: MultiBlocProvider(
            providers: buildBlocProviders(),
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              title: flavor.appName,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              routerConfig: router,
            ),
          ),
        );
      },
    );
  }
}
