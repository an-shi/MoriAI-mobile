import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/services/sticker_store.dart';
import 'package:mori_ai/widgets/sticker_picker_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;
  final pngBytes = Uint8List.fromList(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2Z8sAAAAASUVORK5CYII=',
    ),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('mori_picker_');
    StickerStore.instance.useDirectoryForTest(tempDirectory);
    await StickerStore.instance.load();
    await StickerStore.instance.addSticker(pngBytes, 'image/png');
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  testWidgets('shows the add tile first and a sticker grid', (tester) async {
    var addCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StickerPickerSheet(
            onAdd: () async {
              addCalls++;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('表情包'), findsOneWidget);
    expect(find.text('添加'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();
    expect(addCalls, 1);
  });

  testWidgets('deletes a sticker from the long-press menu', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StickerPickerSheet(onAdd: () async => null)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.text('删除表情包'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await tester.pumpAndSettle();
    expect(StickerStore.instance.stickers.value, isEmpty);
  });
}
