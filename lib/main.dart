import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mori_ai/pages/home_page.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/avatar_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/theme_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ApiKeyStore.instance.load(),
    ModelStore.instance.load(),
    CharacterStore.instance.load(),
    GroupStore.instance.load(),
    UserProfileStore.instance.load(),
    AvatarStore.instance.load(),
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
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
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
