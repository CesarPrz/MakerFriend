import 'package:flutter/material.dart';
import 'package:maker_friend/themes/theme_controller.dart';

class ThemeSettingsPage extends StatelessWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thème')),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.mode,
        builder: (context, mode, _) {
          return ListView(
            children: [
              RadioListTile<ThemeMode>(
                value: ThemeMode.system,
                groupValue: mode,
                onChanged: (v) => ThemeController.setMode(v!),
                title: const Text('Système'),
                subtitle: const Text('Suit le thème du téléphone'),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.light,
                groupValue: mode,
                onChanged: (v) => ThemeController.setMode(v!),
                title: const Text('Clair'),
              ),
              RadioListTile<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: mode,
                onChanged: (v) => ThemeController.setMode(v!),
                title: const Text('Sombre'),
              ),
            ],
          );
        },
      ),
    );
  }
}
