import 'package:flutter/material.dart';
import 'package:mori_ai/pages/home_page.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ApiKeyStore.instance.load(),
    ModelStore.instance.load(),
    ThemeStore.instance.load(),
  ]);
  runApp(const MoriApp());
}

class MoriApp extends StatelessWidget {
  const MoriApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF6B9080);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeStore.instance.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Mori',
          themeMode: themeMode,
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
          home: const HomePage(),
        );
      },
    );
  }
}
