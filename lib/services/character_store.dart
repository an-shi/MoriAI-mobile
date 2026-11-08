import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/services/avatar_store.dart';
import 'package:mori_ai/services/chat_history_store.dart';
import 'package:mori_ai/services/chat_queue_store.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:mori_ai/services/moment_store.dart';
import 'package:mori_ai/services/pinned_conversation_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 管理多张角色卡以及卡片内容。
class CharacterStore {
  CharacterStore._();

  static final CharacterStore instance = CharacterStore._();

  static const _cardsKey = 'character_cards';
  static const _legacyNameKey = 'character_name';
  static const _legacyPersonaKey = 'character_persona';
  static const _presetAvatarMigrationKey = 'preset_avatar_migration_v1';

  final ValueNotifier<List<CharacterProfile>> cards =
      ValueNotifier<List<CharacterProfile>>(const [
        CharacterProfile.presetMori,
      ]);

  bool get canDeleteCards => cards.value.length > 1;

  CharacterProfile? cardById(String cardId) {
    for (final card in cards.value) {
      if (card.id == cardId) {
        return card;
      }
    }
    return null;
  }

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final rawCards = preferences.getString(_cardsKey);

      List<CharacterProfile> loadedCards;
      var shouldPersist = false;

      if (rawCards == null) {
        loadedCards = _buildInitialCards(preferences);
        shouldPersist = true;
      } else {
        loadedCards = _decodeCards(rawCards);
        if (loadedCards.isEmpty) {
          loadedCards = const [CharacterProfile.presetMori];
          shouldPersist = true;
        }
      }

      final presetAvatarMigrationDone =
          preferences.getBool(_presetAvatarMigrationKey) ?? false;
      if (!presetAvatarMigrationDone) {
        final presetIndex = loadedCards.indexWhere(
          (card) =>
              card.id == CharacterProfile.presetMoriId && card.avatar.isEmpty,
        );
        if (presetIndex >= 0) {
          loadedCards = [...loadedCards];
          loadedCards[presetIndex] = loadedCards[presetIndex].withAvatar(
            CharacterProfile.presetMoriAvatar,
          );
        }
        shouldPersist = true;
      }

      _apply(loadedCards);
      if (shouldPersist) {
        final saved = await _write(preferences, loadedCards);
        if (saved) {
          await preferences.setBool(_presetAvatarMigrationKey, true);
          await _clearLegacyProfile(preferences);
        }
      }
    } catch (_) {
      _apply(const [CharacterProfile.presetMori]);
    }
  }

  /// 保存指定角色卡。
  Future<void> save(CharacterProfile next) async {
    final index = cards.value.indexWhere((card) => card.id == next.id);
    if (index < 0) {
      throw StateError('Character card not found');
    }

    final updated = next.normalized();
    final nextCards = [...cards.value];
    nextCards[index] = updated;

    await _persist(nextCards);
  }

  /// 为尚未保存的新角色卡生成一个不会与现有卡片冲突的 ID。
  String createCardId() => _newCardId();

  /// 生成一个建议的新角色卡名称。
  String nextCardName() => _nextCardName(cards.value);

  /// 保存一张全新的角色卡。调用前应先在编辑页完成内容填写。
  Future<CharacterProfile> createCard(CharacterProfile next) async {
    final normalized = next.normalized();
    if (normalized.id.isEmpty) {
      throw ArgumentError.value(next.id, 'id', 'Card id cannot be empty');
    }
    if (cards.value.any((card) => card.id == normalized.id)) {
      throw StateError('Character card already exists');
    }

    final nextCards = [...cards.value, normalized];
    await _persist(nextCards);
    return normalized;
  }

  Future<CharacterProfile> addCard({String? name, String? persona}) async {
    final card = CharacterProfile(
      id: createCardId(),
      name: (name?.trim().isNotEmpty ?? false) ? name!.trim() : nextCardName(),
      persona: (persona?.trim().isEmpty ?? true)
          ? CharacterProfile.defaultPersona
          : persona!.trim(),
    ).normalized();

    return createCard(card);
  }

  Future<void> deleteCard(String cardId) async {
    if (cards.value.length <= 1) {
      throw StateError('At least one character card must be kept');
    }

    CharacterProfile? deletedCard;
    for (final card in cards.value) {
      if (card.id == cardId) {
        deletedCard = card;
        break;
      }
    }

    final nextCards = cards.value
        .where((card) => card.id != cardId)
        .toList(growable: false);
    if (nextCards.length == cards.value.length) {
      return;
    }

    await _persist(nextCards);

    final avatar = deletedCard?.avatar;
    if (avatar != null && avatar.isNotEmpty) {
      await AvatarStore.instance.deleteAvatar(avatar);
    }

    // 删除角色的单聊记录、排队消息、动态与评论，以及群聊中由该角色发送的消息。
    await ChatHistoryStore.instance.deleteForCard(cardId);
    await ChatQueueStore.instance.saveFor(cardId, const []);
    await MomentStore.instance.deleteForCharacter(cardId);
    await _deleteGroupMessages(cardId);
    try {
      await PinnedConversationStore.instance.setPinned(cardId, false);
    } catch (_) {
      // 清理置顶失败不影响角色删除结果。
    }
  }

  Future<void> _deleteGroupMessages(String cardId) async {
    for (final group in GroupStore.instance.groups.value) {
      final history = await ChatHistoryStore.instance.loadFor(group.id);
      if (history.isEmpty) {
        continue;
      }
      final filtered = [
        for (final message in history)
          if (message.isUser || message.senderId != cardId) message,
      ];
      if (filtered.length != history.length) {
        await ChatHistoryStore.instance.saveFor(group.id, filtered);
      }
    }
  }

  Future<void> _persist(List<CharacterProfile> nextCards) async {
    final previousCards = cards.value;
    final immutableCards = List<CharacterProfile>.unmodifiable(nextCards);

    _apply(immutableCards);

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await _write(preferences, immutableCards);
      if (!saved) {
        throw StateError('Failed to save character cards');
      }
    } catch (_) {
      _apply(previousCards);
      rethrow;
    }
  }

  Future<bool> _write(
    SharedPreferences preferences,
    List<CharacterProfile> nextCards,
  ) {
    return preferences.setString(
      _cardsKey,
      jsonEncode([for (final card in nextCards) card.toJson()]),
    );
  }

  void _apply(List<CharacterProfile> nextCards) {
    cards.value = List<CharacterProfile>.unmodifiable(nextCards);
  }

  List<CharacterProfile> _decodeCards(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const [];
      }

      final result = <CharacterProfile>[];
      final ids = <String>{};
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        try {
          final card = CharacterProfile.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (ids.add(card.id)) {
            result.add(card);
          }
        } on FormatException {
          // 跳过损坏的角色卡。
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  List<CharacterProfile> _buildInitialCards(SharedPreferences preferences) {
    final legacyName = preferences.getString(_legacyNameKey)?.trim() ?? '';
    final legacyPersona =
        preferences.getString(_legacyPersonaKey)?.trim() ?? '';

    final isDefaultMori =
        legacyName == CharacterProfile.presetMori.name &&
        (legacyPersona.isEmpty ||
            legacyPersona == CharacterProfile.defaultPersona);
    final hasCustomProfile =
        !isDefaultMori &&
        (legacyName.isNotEmpty ||
            (legacyPersona.isNotEmpty &&
                legacyPersona != CharacterProfile.defaultPersona));

    if (!hasCustomProfile) {
      return const [CharacterProfile.presetMori];
    }

    final migrated = CharacterProfile(
      id: _newCardId(),
      name: legacyName,
      persona: legacyPersona.isEmpty
          ? CharacterProfile.defaultPersona
          : legacyPersona,
    ).normalized();

    return [CharacterProfile.presetMori, migrated];
  }

  Future<void> _clearLegacyProfile(SharedPreferences preferences) async {
    try {
      await preferences.remove(_legacyNameKey);
      await preferences.remove(_legacyPersonaKey);
    } catch (_) {
      // 清理旧字段失败不影响新的多角色卡数据。
    }
  }

  String _newCardId() {
    final base = 'card_${DateTime.now().microsecondsSinceEpoch}';
    var id = base;
    var suffix = 1;
    while (cards.value.any((card) => card.id == id)) {
      id = '${base}_$suffix';
      suffix++;
    }
    return id;
  }

  String _nextCardName(List<CharacterProfile> existingCards) {
    final names = {for (final card in existingCards) card.displayName};
    var candidate = '新角色';
    var index = 2;
    while (names.contains(candidate)) {
      candidate = '新角色 $index';
      index++;
    }
    return candidate;
  }
}
