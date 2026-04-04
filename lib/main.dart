import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/inventory_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const GalacticGameplayApp());
}

class GalacticGameplayApp extends StatelessWidget {
  const GalacticGameplayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Galactic Three Kingdoms — Gameplay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          // Player faction (Three Kingdoms — yellow / imperial gold).
          seedColor: const Color(0xFFFFC107),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const InventoryScreen(),
    );
  }
}
