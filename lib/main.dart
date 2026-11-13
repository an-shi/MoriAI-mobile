import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:forui/forui.dart';
import 'package:mori_ai/pages/moribot/mori_gate.dart';
import 'package:mori_ai/services/moribot/mori_session_store.dart';
import 'package:mori_ai/services/theme_store.dart';
import 'package:mori_ai/ui/mori_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ThemeStore.instance.load(),
    MoriSessionStore.instance.load(),
  ]);
  runApp(const MoriApp());
}

class MoriApp extends StatelessWidget {
  const MoriApp({super.key});

  @override
  Widget build(BuildContext context) {
    final lightTheme = MoriTheme.light();
    final darkTheme = MoriTheme.dark();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeStore.instance.themeMode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Mori',
          themeMode: themeMode,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeAnimationDuration: const Duration(milliseconds: 280),
          themeAnimationCurve: Curves.easeOutCubic,
          locale: const Locale('zh', 'CN'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
          builder: (context, child) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return FTheme(
              data: MoriTheme.forui(isDark ? darkTheme : lightTheme),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const MoriGate(),
        );
      },
    );
  }
}
