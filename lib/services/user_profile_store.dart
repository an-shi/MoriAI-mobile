import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:mori_ai/models/user_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileStore {
  UserProfileStore._();

  static final UserProfileStore instance = UserProfileStore._();

  static const _profileKey = 'user_profile';

  final ValueNotifier<UserProfile> profile = ValueNotifier<UserProfile>(
    UserProfile.defaults,
  );

  Future<void> load() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString(_profileKey);
      if (raw == null || raw.isEmpty) {
        profile.value = UserProfile.defaults;
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        profile.value = UserProfile.defaults;
        return;
      }
      profile.value = UserProfile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (_) {
      profile.value = UserProfile.defaults;
    }
  }

  Future<void> save(UserProfile next) async {
    final normalized = next.normalized();
    final previous = profile.value;
    profile.value = normalized;

    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = await preferences.setString(
        _profileKey,
        jsonEncode(normalized.toJson()),
      );
      if (!saved) {
        throw StateError('Failed to save user profile');
      }
    } catch (_) {
      profile.value = previous;
      rethrow;
    }
  }
}
