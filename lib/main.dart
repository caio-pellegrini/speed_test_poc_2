import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'app/modules/speed_test/speed_test_module.dart';

void main() {
  runApp(ModularApp(
    module: SpeedTestModule(),
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Speed test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyanAccent,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),
        useMaterial3: true,
      ),
      routerConfig: Modular.routerConfig,
    );
  }
}
