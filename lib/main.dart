import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/hive_setup.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setUpHive();
  runApp(const ProviderScope(child: ProcheckApp()));
}

class ProcheckApp extends StatelessWidget {
  const ProcheckApp({super.key});

  @override
  Widget build(BuildContext context) {
    final seedColor = const Color(0xFF3D5AFE);
    return MaterialApp(
      title: 'Procheck',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
