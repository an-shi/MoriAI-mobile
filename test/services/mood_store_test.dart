import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/mood.dart';
import 'package:mori_ai/services/mood_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MoodStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await MoodStore.instance.load();
  });

  test('loads defaults and clamps settings', () async {
    final defaults = MoodStore.instance.settings.value;
    expect(defaults.enabled, isTrue);
    expect(defaults.modelJudgeEnabled, isFalse);
    expect(defaults.base, 60);
    expect(defaults.halfLifeHours, 3);

    final normalized = const MoodSettings(
      base: 150,
      halfLifeHours: 0,
    ).normalized();
    expect(normalized.base, 100);
    expect(normalized.halfLifeHours, 1);
  });

  test('positive and negative chat messages move the mood', () async {
    await MoodStore.instance.observe(
      'mori',
      '喜欢你，真棒，厉害，可爱',
      direct: true,
      owner: true,
    );
    final happy = MoodStore.instance.snapshotFor('mori');
    expect(happy.value, 90);
    expect(happy.label, '超开心');
    expect(MoodStore.instance.contextLine('mori'), contains('超开心'));

    await MoodStore.instance.reset('mori');
    await MoodStore.instance.observe(
      'mori',
      '讨厌，烦死，闭嘴，笨',
      direct: true,
      owner: true,
    );
    final upset = MoodStore.instance.snapshotFor('mori');
    expect(upset.value, lessThan(50));
    expect(MoodStore.instance.contextLine('mori'), isNotEmpty);
  });

  test('group messages have less weight than direct messages', () async {
    await MoodStore.instance.observe(
      'group-character',
      '喜欢你，真棒，厉害，可爱',
      direct: false,
      owner: true,
    );
    final snapshot = MoodStore.instance.snapshotFor('group-character');
    expect(snapshot.value, greaterThan(60));
    expect(snapshot.value, lessThan(90));
  });

  test('mood decays back to base over the half-life', () {
    final now = DateTime(2026, 11, 8, 12);
    const settings = MoodSettings(base: 60, halfLifeHours: 3);
    final state = MoodState(
      value: 90,
      updatedAtMs: now
          .subtract(const Duration(hours: 3))
          .millisecondsSinceEpoch,
    );
    final decayed = state.decayed(settings, now);
    expect(decayed.value, 75);

    final afterSixHours = state.decayed(
      settings,
      now.add(const Duration(hours: 3)),
    );
    expect(afterSixHours.value, 68);
  });

  test('persists mood state and settings, and can reset', () async {
    await MoodStore.instance.saveSettings(
      const MoodSettings(
        enabled: true,
        modelJudgeEnabled: true,
        base: 70,
        halfLifeHours: 6,
      ),
    );
    await MoodStore.instance.nudge('mori', 20, '被夸了');
    expect(MoodStore.instance.snapshotFor('mori').value, 90);

    await MoodStore.instance.load();
    expect(MoodStore.instance.settings.value.base, 70);
    expect(MoodStore.instance.settings.value.halfLifeHours, 6);
    expect(MoodStore.instance.settings.value.modelJudgeEnabled, isTrue);
    expect(MoodStore.instance.snapshotFor('mori').reason, '被夸了');
    expect(MoodStore.instance.snapshotFor('mori').history, isNotEmpty);

    await MoodStore.instance.reset('mori');
    expect(MoodStore.instance.snapshotFor('mori').value, 70);
  });

  test('delay factor reflects mood', () async {
    await MoodStore.instance.nudge('mori', 30, '开心');
    expect(MoodStore.instance.delayFactor('mori'), 0.85);

    await MoodStore.instance.nudge('mori', -80, '难过');
    expect(MoodStore.instance.delayFactor('mori'), 1.5);
  });
}
