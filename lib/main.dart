import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:forui/forui.dart';
import 'package:mori_ai/pages/home_page.dart';
import 'package:mori_ai/services/api_key_store.dart';
import 'package:mori_ai/services/avatar_store.dart';
import 'package:mori_ai/services/character_activity_backfill.dart';
import 'package:mori_ai/services/character_activity_store.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_burst_settings_store.dart';
import 'package:mori_ai/services/chat_reply_settings_store.dart';
import 'package:mori_ai/services/diary_service.dart';
import 'package:mori_ai/services/diary_store.dart';
import 'package:mori_ai/services/group_memory_service.dart';
import 'package:mori_ai/services/group_memory_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/services/local_notification_service.dart';
import 'package:mori_ai/services/memory_service.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/services/model_store.dart';
import 'package:mori_ai/services/moment_interaction_settings_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:mori_ai/services/pinned_conversation_store.dart';
import 'package:mori_ai/services/proactive_message_service.dart';
import 'package:mori_ai/services/proactive_message_store.dart';
import 'package:mori_ai/services/sticker_store.dart';
import 'package:mori_ai/services/system_context_settings_store.dart';
import 'package:mori_ai/services/theme_store.dart';
import 'package:mori_ai/services/unread_store.dart';
import 'package:mori_ai/services/user_profile_store.dart';
import 'package:mori_ai/ui/mori_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    ApiKeyStore.instance.load(),
    ModelStore.instance.load(),
    CharacterStore.instance.load(),
    GroupStore.instance.load(),
    GroupMemoryStore.instance.load(),
    UserProfileStore.instance.load(),
    PinnedConversationStore.instance.load(),
    MomentStore.instance.load(),
    MomentInteractionSettingsStore.instance.load(),
    ProactiveMessageStore.instance.load(),
    ChatBurstSettingsStore.instance.load(),
    ChatReplySettingsStore.instance.load(),
    SystemContextSettingsStore.instance.load(),
    StickerStore.instance.load(),
    CharacterActivityStore.instance.load(),
    MoodStore.instance.load(),
    DiaryStore.instance.load(),
    MemoryStore.instance.load(),
    AvatarStore.instance.load(),
    ThemeStore.instance.load(),
    UnreadStore.instance.load(),
  ]);
  await CharacterActivityBackfill.instance.ensureBackfilled();
  await LocalNotificationService.instance.init();
  runApp(const MoriApp());
  ProactiveMessageService.instance.start();
  DiaryService.instance.start();
  MemoryService.instance.start();
  GroupMemoryService.instance.start();
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
          home: const HomePage(),
        );
      },
    );
  }
}
