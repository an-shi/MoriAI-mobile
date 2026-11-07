import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/group_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GroupStore {
  GroupStore._();

  static final GroupStore instance = GroupStore._();

  static const _groupsKey = 'chat_groups_v1';

  final ValueNotifier<List<GroupProfile>> groups =
      ValueNotifier<List<GroupProfile>>(const []);

  GroupProfile? groupById(String id) {
    for (final group in groups.value) {
      if (group.id == id) {
        return group;
      }
    }
    return null;
  }

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_groupsKey);
      if (raw == null || raw.isEmpty) {
        groups.value = const [];
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        groups.value = const [];
        return;
      }

      final result = <GroupProfile>[];
      final ids = <String>{};
      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }
        try {
          final group = GroupProfile.fromJson(Map<String, dynamic>.from(item));
          if (ids.add(group.id)) {
            result.add(group);
          }
        } on FormatException {
          // 跳过损坏的群聊记录。
        }
      }
      groups.value = List<GroupProfile>.unmodifiable(result);
    } catch (_) {
      groups.value = const [];
    }
  }

  Future<GroupProfile> createGroup({
    required String name,
    required List<String> memberIds,
  }) async {
    final uniqueMembers = <String>[];
    for (final id in memberIds) {
      if (id.trim().isNotEmpty && !uniqueMembers.contains(id)) {
        uniqueMembers.add(id);
      }
    }
    if (uniqueMembers.length < 2) {
      throw ArgumentError('A group requires at least two members');
    }

    final group = GroupProfile(
      id: 'group_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      memberIds: List<String>.unmodifiable(uniqueMembers),
      createdAt: DateTime.now(),
    );

    final previous = groups.value;
    final next = List<GroupProfile>.unmodifiable([...previous, group]);
    groups.value = next;

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _groupsKey,
        jsonEncode([for (final item in next) item.toJson()]),
      );
      if (!saved) {
        throw StateError('Failed to save group');
      }
    } catch (_) {
      groups.value = previous;
      rethrow;
    }

    return group;
  }

  Future<GroupProfile> updateGroup(GroupProfile next) async {
    final index = groups.value.indexWhere((group) => group.id == next.id);
    if (index < 0) {
      throw StateError('Group not found');
    }

    final uniqueMembers = <String>[];
    for (final id in next.memberIds) {
      if (id.trim().isNotEmpty && !uniqueMembers.contains(id)) {
        uniqueMembers.add(id);
      }
    }
    if (uniqueMembers.length < 2) {
      throw ArgumentError('A group requires at least two members');
    }

    final updated = GroupProfile(
      id: next.id,
      name: next.name.trim(),
      avatar: next.avatar.trim(),
      memberIds: List<String>.unmodifiable(uniqueMembers),
      createdAt: next.createdAt,
    );
    final previous = groups.value;
    final nextGroups = [...previous]..[index] = updated;
    groups.value = List<GroupProfile>.unmodifiable(nextGroups);

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _groupsKey,
        jsonEncode([for (final item in nextGroups) item.toJson()]),
      );
      if (!saved) {
        throw StateError('Failed to save group');
      }
    } catch (_) {
      groups.value = previous;
      rethrow;
    }

    return updated;
  }
}
