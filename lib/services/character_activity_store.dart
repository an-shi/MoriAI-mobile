import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/character_activity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CharacterActivityStore {
  CharacterActivityStore._();

  static final CharacterActivityStore instance = CharacterActivityStore._();

  static const _activitiesKey = 'character_activity_v1';
  static const maxActivitiesPerCharacter = 300;

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Map<String, List<CharacterActivity>> _byCharacter = {};

  Future<void> load() async {
    _byCharacter.clear();
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_activitiesKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final seen = <String>{};
          for (final item in decoded) {
            if (item is! Map) {
              continue;
            }
            try {
              final activity = CharacterActivity.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (activity.id.isEmpty ||
                  activity.characterId.isEmpty ||
                  activity.content.isEmpty ||
                  !seen.add(_dedupeKey(activity))) {
                continue;
              }
              _byCharacter
                  .putIfAbsent(activity.characterId, () => [])
                  .add(activity);
            } catch (_) {
              // 跳过损坏的记录。
            }
          }
        }
      }
    } catch (_) {
      _byCharacter.clear();
    }
    for (final activities in _byCharacter.values) {
      activities.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
      _trim(activities);
    }
    revision.value++;
  }

  List<CharacterActivity> activitiesFor(String characterId) {
    final activities = _byCharacter[characterId];
    if (activities == null) {
      return const [];
    }
    return List<CharacterActivity>.unmodifiable(activities);
  }

  Future<void> record(CharacterActivity activity) {
    return recordAll([activity]);
  }

  Future<void> recordAll(Iterable<CharacterActivity> activities) async {
    var changed = false;
    for (final raw in activities) {
      final activity = raw.normalized();
      if (activity.id.isEmpty ||
          activity.characterId.isEmpty ||
          activity.content.isEmpty ||
          activity.createdAtMs <= 0) {
        continue;
      }
      final list = _byCharacter.putIfAbsent(activity.characterId, () => []);
      if (list.any((item) => item.id == activity.id)) {
        continue;
      }
      list.add(activity);
      list.sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
      _trim(list);
      changed = true;
    }
    if (!changed) {
      return;
    }
    revision.value++;
    await _persist();
  }

  Future<void> clearForCharacter(String characterId) async {
    if (_byCharacter.remove(characterId) == null) {
      return;
    }
    revision.value++;
    await _persist();
  }

  void _trim(List<CharacterActivity> activities) {
    if (activities.length <= maxActivitiesPerCharacter) {
      return;
    }
    activities.removeRange(0, activities.length - maxActivitiesPerCharacter);
  }

  String _dedupeKey(CharacterActivity activity) {
    return '${activity.characterId}|${activity.id}';
  }

  Future<void> _persist() async {
    final all = <CharacterActivity>[
      for (final activities in _byCharacter.values) ...activities,
    ]..sort((a, b) => a.createdAtMs.compareTo(b.createdAtMs));
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _activitiesKey,
        jsonEncode([for (final activity in all) activity.toJson()]),
      );
    } catch (_) {
      // 活动记录保存失败不阻断聊天，下一次记录会继续尝试。
    }
  }
}
