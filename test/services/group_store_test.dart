import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/models/group_reply_mode.dart';
import 'package:mori_ai/services/group_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    await GroupStore.instance.load();
  });

  test('creates and persists a group chat', () async {
    await GroupStore.instance.load();

    final group = await GroupStore.instance.createGroup(
      name: '测试群聊',
      memberIds: const ['mori', 'card_2'],
    );

    expect(group.displayName, '测试群聊');
    expect(group.memberIds, ['mori', 'card_2']);
    expect(GroupStore.instance.groups.value, hasLength(1));

    await GroupStore.instance.load();
    expect(GroupStore.instance.groups.value, hasLength(1));
    expect(GroupStore.instance.groups.value.single.name, '测试群聊');
  });

  test('updates group name and members', () async {
    await GroupStore.instance.load();
    final group = await GroupStore.instance.createGroup(
      name: '测试群聊',
      memberIds: const ['mori', 'card_2'],
    );

    await GroupStore.instance.updateGroup(
      group.copyWith(
        name: '新群名',
        memberIds: const ['mori', 'card_3'],
        replyMode: GroupReplyMode.singleRandom,
      ),
    );

    final updated = GroupStore.instance.groupById(group.id);
    expect(updated, isNotNull);
    expect(updated!.name, '新群名');
    expect(updated.memberIds, ['mori', 'card_3']);
    expect(updated.replyMode, GroupReplyMode.singleRandom);

    await GroupStore.instance.load();
    expect(
      GroupStore.instance.groupById(group.id)?.replyMode,
      GroupReplyMode.singleRandom,
    );
  });

  test('requires at least two unique members', () async {
    await GroupStore.instance.load();

    await expectLater(
      GroupStore.instance.createGroup(name: '无效群聊', memberIds: const ['mori']),
      throwsArgumentError,
    );
    await expectLater(
      GroupStore.instance.createGroup(
        name: '无效群聊',
        memberIds: const ['mori', 'mori'],
      ),
      throwsArgumentError,
    );
  });
}
