import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/services/avatar_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 管理多张角色卡、当前使用的角色以及卡片内容。
class CharacterStore {
  CharacterStore._();

  static final CharacterStore instance = CharacterStore._();

  static const _cardsKey = 'character_cards';
  static const _activeIdKey = 'character_active_card_id';
  static const _legacyNameKey = 'character_name';
  static const _legacyPersonaKey = 'character_persona';
  static const _presetAvatarMigrationKey = 'preset_avatar_migration_v1';

  final ValueNotifier<List<CharacterProfile>> cards =
      ValueNotifier<List<CharacterProfile>>(const [
        CharacterProfile.presetMori,
      ]);

  final ValueNotifier<String> activeCardId = ValueNotifier<String>(
    CharacterProfile.presetMoriId,
  );

  /// 当前正在使用的角色，对话页面会监听它。
  final ValueNotifier<CharacterProfile> profile =
      ValueNotifier<CharacterProfile>(CharacterProfile.presetMori);

  CharacterProfile get activeCard => profile.value;

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
      String? loadedActiveId;
      var shouldPersist = false;

      if (rawCards == null) {
        final initial = _buildInitialState(preferences);
        loadedCards = initial.cards;
        loadedActiveId = initial.activeId;
        shouldPersist = true;
      } else {
        loadedCards = _decodeCards(rawCards);
        if (loadedCards.isEmpty) {
          loadedCards = const [CharacterProfile.presetMori];
          loadedActiveId = CharacterProfile.presetMoriId;
          shouldPersist = true;
        } else {
          loadedActiveId = preferences.getString(_activeIdKey);
          if (loadedActiveId == null ||
              !loadedCards.any((card) => card.id == loadedActiveId)) {
            loadedActiveId = loadedCards.first.id;
            shouldPersist = true;
          }
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

      _apply(loadedCards, loadedActiveId);
      if (shouldPersist) {
        final saved = await _write(preferences, loadedCards, loadedActiveId);
        if (saved) {
          await preferences.setBool(_presetAvatarMigrationKey, true);
          await _clearLegacyProfile(preferences);
        }
      }
    } catch (_) {
      _apply(const [
        CharacterProfile.presetMori,
      ], CharacterProfile.presetMoriId);
    }
  }

  /// 保存指定角色卡。编辑非当前角色时不会改变当前使用中的角色。
  Future<void> save(CharacterProfile next) async {
    final index = cards.value.indexWhere((card) => card.id == next.id);
    if (index < 0) {
      throw StateError('Character card not found');
    }

    final updated = next.normalized();
    final nextCards = [...cards.value];
    nextCards[index] = updated;

    await _persist(nextCards, activeCardId.value);
  }

  Future<void> selectCard(String cardId) async {
    if (cardId == activeCardId.value) {
      return;
    }
    if (!cards.value.any((card) => card.id == cardId)) {
      throw StateError('Character card not found');
    }

    await _persist(cards.value, cardId);
  }

  Future<CharacterProfile> addCard({String? name, String? persona}) async {
    final nextCards = [...cards.value];
    final card = CharacterProfile(
      id: _newCardId(),
      name: (name?.trim().isNotEmpty ?? false)
          ? name!.trim()
          : _nextCardName(nextCards),
      persona: (persona?.trim().isEmpty ?? true)
          ? CharacterProfile.defaultPersona
          : persona!.trim(),
    ).normalized();

    nextCards.add(card);
    await _persist(nextCards, card.id);
    return card;
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

    final nextActiveId = activeCardId.value == cardId
        ? nextCards.first.id
        : activeCardId.value;
    await _persist(nextCards, nextActiveId);

    final avatar = deletedCard?.avatar;
    if (avatar != null && avatar.isNotEmpty) {
      await AvatarStore.instance.deleteAvatar(avatar);
    }
  }

  Future<void> _persist(
    List<CharacterProfile> nextCards,
    String nextActiveId,
  ) async {
    final previousCards = cards.value;
    final previousActiveId = activeCardId.value;
    final immutableCards = List<CharacterProfile>.unmodifiable(nextCards);

    _apply(immutableCards, nextActiveId);

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await _write(
        preferences,
        immutableCards,
        activeCardId.value,
      );
      if (!saved) {
        throw StateError('Failed to save character cards');
      }
    } catch (_) {
      _apply(previousCards, previousActiveId);
      rethrow;
    }
  }

  Future<bool> _write(
    SharedPreferences preferences,
    List<CharacterProfile> nextCards,
    String nextActiveId,
  ) async {
    var saved = await preferences.setString(
      _cardsKey,
      jsonEncode([for (final card in nextCards) card.toJson()]),
    );
    saved = await preferences.setString(_activeIdKey, nextActiveId) && saved;
    return saved;
  }

  void _apply(List<CharacterProfile> nextCards, String nextActiveId) {
    CharacterProfile active;
    try {
      active = nextCards.firstWhere((card) => card.id == nextActiveId);
    } on StateError {
      active = nextCards.first;
    }

    cards.value = List<CharacterProfile>.unmodifiable(nextCards);
    activeCardId.value = active.id;
    profile.value = active;
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

  ({List<CharacterProfile> cards, String activeId}) _buildInitialState(
    SharedPreferences preferences,
  ) {
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
      return (
        cards: const [CharacterProfile.presetMori],
        activeId: CharacterProfile.presetMoriId,
      );
    }

    final migrated = CharacterProfile(
      id: _newCardId(),
      name: legacyName,
      persona: legacyPersona.isEmpty
          ? CharacterProfile.defaultPersona
          : legacyPersona,
    ).normalized();

    return (
      cards: [CharacterProfile.presetMori, migrated],
      activeId: migrated.id,
    );
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
