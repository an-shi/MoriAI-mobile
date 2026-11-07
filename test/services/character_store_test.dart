import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/character_profile.dart';
import 'package:mori_ai/services/character_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await CharacterStore.instance.load();
  });

  test('seeds the preset Mori card by default', () async {
    await CharacterStore.instance.load();

    expect(CharacterStore.instance.cards.value, hasLength(1));
    expect(
      CharacterStore.instance.activeCard.id,
      CharacterProfile.presetMoriId,
    );
    expect(CharacterStore.instance.activeCard.displayName, 'Mori');
    expect(
      CharacterStore.instance.activeCard.avatar,
      CharacterProfile.presetMoriAvatar,
    );
    expect(
      CharacterStore.instance.activeCard.persona,
      CharacterProfile.defaultPersona,
    );
  });

  test('adds the preset avatar once and respects later removal', () async {
    SharedPreferences.setMockInitialValues({
      'character_cards': jsonEncode([
        CharacterProfile.presetMori.withAvatar('').toJson(),
      ]),
      'character_active_card_id': CharacterProfile.presetMoriId,
    });

    await CharacterStore.instance.load();
    expect(
      CharacterStore.instance.activeCard.avatar,
      CharacterProfile.presetMoriAvatar,
    );

    await CharacterStore.instance.save(
      CharacterStore.instance.activeCard.withAvatar(''),
    );
    await CharacterStore.instance.load();
    expect(CharacterStore.instance.activeCard.avatar, isEmpty);
  });

  test('cannot delete the only remaining character card', () async {
    await CharacterStore.instance.load();

    await expectLater(
      CharacterStore.instance.deleteCard(CharacterProfile.presetMoriId),
      throwsStateError,
    );
    expect(CharacterStore.instance.cards.value, hasLength(1));
  });

  test('adds, selects, and deletes character cards', () async {
    await CharacterStore.instance.load();
    final added = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '冷静、简洁，喜欢倾听。',
    );

    expect(CharacterStore.instance.cards.value, hasLength(2));
    expect(CharacterStore.instance.activeCard.id, added.id);
    expect(CharacterStore.instance.activeCard.name, '小森');

    await CharacterStore.instance.selectCard(CharacterProfile.presetMoriId);
    expect(
      CharacterStore.instance.activeCard.id,
      CharacterProfile.presetMoriId,
    );
    expect(CharacterStore.instance.activeCard.displayName, 'Mori');

    await CharacterStore.instance.deleteCard(added.id);
    expect(CharacterStore.instance.cards.value, hasLength(1));
    expect(
      CharacterStore.instance.activeCard.id,
      CharacterProfile.presetMoriId,
    );
  });

  test('deleting the active card selects another card', () async {
    await CharacterStore.instance.load();
    final added = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '冷静、简洁，喜欢倾听。',
    );

    await CharacterStore.instance.deleteCard(added.id);

    expect(CharacterStore.instance.cards.value, hasLength(1));
    expect(
      CharacterStore.instance.activeCard.id,
      CharacterProfile.presetMoriId,
    );
  });

  test('editing an inactive card does not change the active card', () async {
    await CharacterStore.instance.load();
    final added = await CharacterStore.instance.addCard(
      name: '小森',
      persona: '冷静、简洁，喜欢倾听。',
    );
    await CharacterStore.instance.selectCard(CharacterProfile.presetMoriId);

    await CharacterStore.instance.save(
      CharacterProfile(id: added.id, name: '小森', persona: '修改后的人格设定。'),
    );

    expect(
      CharacterStore.instance.activeCard.id,
      CharacterProfile.presetMoriId,
    );
    expect(CharacterStore.instance.cardById(added.id)?.persona, '修改后的人格设定。');
  });

  test('persists cards, active selection, and edits', () async {
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
    expect(CharacterStore.instance.activeCard.id, added.id);
    expect(CharacterStore.instance.activeCard.name, '小森');
    expect(CharacterStore.instance.activeCard.persona, '温柔、耐心，说话简洁自然。');
  });

  test('migrates the old single profile and keeps the Mori preset', () async {
    SharedPreferences.setMockInitialValues({
      'character_name': '小森',
      'character_persona': '冷静、简洁，喜欢倾听。',
    });

    await CharacterStore.instance.load();

    expect(CharacterStore.instance.cards.value, hasLength(2));
    expect(CharacterStore.instance.activeCard.name, '小森');
    expect(
      CharacterStore.instance.cards.value.any(
        (card) => card.id == CharacterProfile.presetMoriId,
      ),
      isTrue,
    );
  });
}
