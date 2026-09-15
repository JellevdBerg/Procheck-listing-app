import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/hive_setup.dart';
import 'data/notification_service.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'theme/nocturne_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setUpHive();
  await NotificationService.instance.initialize();
  runApp(const ProviderScope(child: ProcheckApp()));
}

class ProcheckApp extends ConsumerWidget {
  const ProcheckApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final accent = settings.accentColor;
    return MaterialApp(
      title: 'ProCheck',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: buildNocturneTheme(brightness: Brightness.light, accent: accent),
      darkTheme: buildNocturneTheme(brightness: Brightness.dark, accent: accent),
      home: const SplashScreen(),
    );
  }
}
