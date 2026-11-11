import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mori_ai/services/sticker_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDirectory;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDirectory = await Directory.systemTemp.createTemp('mori_stickers_');
    StickerStore.instance.useDirectoryForTest(tempDirectory);
    await StickerStore.instance.load();
  });

  tearDown(() async {
    SharedPreferences.setMockInitialValues({});
    StickerStore.instance.useDirectoryForTest(
      Directory('${tempDirectory.path}_unused'),
    );
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('adds, persists and deletes a sticker', () async {
    final bytes = Uint8List.fromList([1, 2, 3, 4]);
    final sticker = await StickerStore.instance.addSticker(bytes, 'image/png');

    expect(sticker, isNotNull);
    expect(StickerStore.instance.stickers.value, hasLength(1));
    final file = File('${tempDirectory.path}/${sticker!.fileName}');
    expect(await file.exists(), isTrue);

    await StickerStore.instance.load();
    expect(StickerStore.instance.stickers.value, hasLength(1));
    expect(
      StickerStore.instance.stickers.value.single.bytes,
      orderedEquals(bytes),
    );

    await StickerStore.instance.deleteSticker(sticker.id);
    expect(StickerStore.instance.stickers.value, isEmpty);
    expect(await file.exists(), isFalse);
  });

  test('skips sticker records whose file is missing', () async {
    SharedPreferences.setMockInitialValues({
      'user_stickers_v1': '[{"id":"s1","file":"missing.png","mimeType":"image/png","createdAtMs":1000}]',
    });
    await StickerStore.instance.load();
    expect(StickerStore.instance.stickers.value, isEmpty);
  });
}
