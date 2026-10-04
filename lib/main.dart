import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_gemma_litertlm/flutter_gemma_litertlm.dart';

import 'app.dart';
import 'screens/setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await FlutterGemma.initialize(inferenceEngines: const [LiteRtLmEngine()]);
  runApp(const MiBarrioApp());
}

class MiBarrioApp extends StatelessWidget {
  const MiBarrioApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mi Barrio',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: const SetupScreen(),
  );
}
