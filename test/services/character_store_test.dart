import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/models/chat_message.dart';
import 'package:mori_ai/models/memory.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/services/memory_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:mori_ai/services/pinned_conversation_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
    await GroupStore.instance.load();
    await MomentStore.instance.load();
    await PinnedConversationStore.instance.load();
    await MemoryStore.instance.load();
  });

  test('seeds the preset Mori card by default', () async {
    await CharacterStore.instance.load();

    expect(CharacterStore.instance.cards.value, hasLength(1));
    final card = CharacterStore.instance.cards.value.single;
    expect(card.id, CharacterProfile.presetMoriId);
    expect(card.displayName, 'Mori');
    expect(card.avatar, CharacterProfile.presetMoriAvatar);
    expect(card.persona, CharacterProfile.defaultPersona);
  });

  test('adds the preset avatar once and respects later removal', () async {
    SharedPreferences.setMockInitialValues({
      'character_cards': jsonEncode([
        CharacterProfile.presetMori.withAvatar('').toJson(),
      ]),
    });

    await CharacterStore.instance.load();
    expect(
      CharacterStore.instance.cardById(CharacterProfile.presetMoriId)?.avatar,
      CharacterProfile.presetMoriAvatar,
    );

    await CharacterStore.instance.save(
      CharacterStore.instance
          .cardById(CharacterProfile.presetMoriId)!
          .withAvatar(''),
    );
    await CharacterStore.instance.load();
    expect(
      CharacterStore.instance.cardById(CharacterProfile.presetMoriId)?.avatar,
      isEmpty,
    );
  });

  test('creates a card only when requested', () async {
    await CharacterStore.instance.load();
    final id = CharacterStore.instance.createCardId();

    expect(CharacterStore.instance.cards.value, hasLength(1));

    await CharacterStore.instance.createCard(
      CharacterProfile(id: id, name: '第二个角色'),
    );

    expect(CharacterStore.instance.cards.value, hasLength(2));
    expect(CharacterStore.instance.cardById(id)?.name, '第二个角色');
  });

  test('cannot delete the only remaining character card', () async {
    await CharacterStore.instance.load();

    await expectLater(
      CharacterStore.instance.deleteCard(CharacterProfile.presetMoriId),
      throwsStateError,
    );
    expect(CharacterStore.instance.cards.value, hasLength(1));
  });

  test('adds and deletes character cards', () async {
    await CharacterStore.instance.load();
    await MemoryStore.instance.load();
    final added = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '冷静、简洁，喜欢倾听。',
    );
    await MemoryStore.instance.saveEntry(
      MemoryEntry(
        id: 'memory_sen',
        characterId: added.id,
        text: '小森记得用户喜欢热牛奶',
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );

    expect(CharacterStore.instance.cards.value, hasLength(2));
    expect(CharacterStore.instance.cardById(added.id)?.displayName, '小森');

    await CharacterStore.instance.deleteCard(added.id);
    expect(CharacterStore.instance.cards.value, hasLength(1));
    expect(CharacterStore.instance.cards.value.single.id, 'mori');
    expect(MemoryStore.instance.entriesFor(added.id), isEmpty);
  });

  test('editing a card only changes that card', () async {
    await CharacterStore.instance.load();
    final added = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '冷静、简洁，喜欢倾听。',
    );

    await CharacterStore.instance.save(
      CharacterProfile(id: added.id, name: '小森', persona: '修改后的人格设定。'),
    );

    expect(CharacterStore.instance.cardById(added.id)?.persona, '修改后的人格设定。');
    expect(CharacterStore.instance.cardById('mori')?.displayName, 'Mori');
  });

  test('persists cards and edits', () async {
    await CharacterStore.instance.load();
    final added = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '冷静、简洁，喜欢倾听。',
    );
    await CharacterStore.instance.save(
      CharacterProfile(id: added.id, name: '小森', persona: '温柔、耐心，说话简洁自然。'),
    );

    await CharacterStore.instance.load();

    expect(CharacterStore.instance.cards.value, hasLength(2));
    final loaded = CharacterStore.instance.cardById(added.id);
    expect(loaded?.displayName, '小森');
    expect(loaded?.persona, '温柔、耐心，说话简洁自然。');
  });

  test('migrates the old single profile and keeps the Mori preset', () async {
    SharedPreferences.setMockInitialValues({
      'character_name': '小森',
      'character_persona': '冷静、简洁，喜欢倾听。',
    });

    await CharacterStore.instance.load();

    expect(CharacterStore.instance.cards.value, hasLength(2));
    expect(
      CharacterStore.instance.cards.value.any(
        (card) => card.displayName == '小森',
      ),
      isTrue,
    );
    expect(
      CharacterStore.instance.cards.value.any(
        (card) => card.id == CharacterProfile.presetMoriId,
      ),
      isTrue,
    );
  });

  test(
    'deleting a card cleans its chats, group messages, and moments',
    () async {
      await CharacterStore.instance.load();
      await GroupStore.instance.load();
      await MomentStore.instance.load();
      await PinnedConversationStore.instance.load();

      final card = await CharacterStore.instance.addCard(
        name: '小森',
        persona: '冷静、简洁，喜欢倾听。',
      );

      await ChatHistoryStore.instance.saveFor(card.id, [
        ChatMessage(
          id: 'card_message',
          role: ChatRole.assistant,
          content: '这条记录应该被删除。',
        ),
      ]);

      final group = await GroupStore.instance.createGroup(
        name: '测试群聊',
        memberIds: [CharacterProfile.presetMoriId, card.id],
      );
      await ChatHistoryStore.instance.saveFor(group.id, [
        const ChatMessage(
          id: 'group_user',
          role: ChatRole.user,
          content: '大家好。',
          senderId: 'user',
        ),
        const ChatMessage(
          id: 'group_mori',
          role: ChatRole.assistant,
          content: '你好。',
          senderId: 'mori',
        ),
        ChatMessage(
          id: 'group_card',
          role: ChatRole.assistant,
          content: '你们好。',
          senderId: card.id,
          senderName: card.displayName,
        ),
      ]);

      final ownMoment = await MomentStore.instance.add(
        authorId: card.id,
        authorName: card.displayName,
        isUser: false,
        content: '准备删除的动态。',
      );
      final otherMoment = await MomentStore.instance.add(
        authorId: CharacterProfile.presetMoriId,
        authorName: 'Mori',
        isUser: false,
        content: '保留的动态。',
      );
      await MomentStore.instance.addComment(
        otherMoment.id,
        authorId: card.id,
        authorName: card.displayName,
        isUser: false,
        content: '准备删除的评论。',
      );
      await MomentStore.instance.addComment(
        otherMoment.id,
        authorId: 'user',
        authorName: '我',
        isUser: true,
        content: '保留的评论。',
      );
      await PinnedConversationStore.instance.setPinned(card.id, true);

      await CharacterStore.instance.deleteCard(card.id);

      expect(await ChatHistoryStore.instance.loadFor(card.id), isEmpty);
      final groupHistory = await ChatHistoryStore.instance.loadFor(group.id);
      expect(groupHistory.map((message) => message.id), [
        'group_user',
        'group_mori',
      ]);

      expect(MomentStore.instance.momentById(ownMoment.id), isNull);
      final remaining = MomentStore.instance.momentById(otherMoment.id);
      expect(remaining, isNotNull);
      expect(remaining!.comments.map((comment) => comment.authorId), ['user']);
      expect(PinnedConversationStore.instance.isPinned(card.id), isFalse);
    },
  );
}
