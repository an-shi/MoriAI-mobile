import 'dart:typed_data';

class Sticker {
  const Sticker({
    required this.id,
    required this.fileName,
    required this.mimeType,
    this.bytes,
    this.createdAtMs = 0,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final Uint8List? bytes;
  final int createdAtMs;

  Sticker copyWith({Uint8List? bytes}) {
    return Sticker(
      id: id,
      fileName: fileName,
      mimeType: mimeType,
      bytes: bytes ?? this.bytes,
      createdAtMs: createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'file': fileName,
    'mimeType': mimeType,
    'createdAtMs': createdAtMs,
  };

  factory Sticker.fromJson(Map<String, dynamic> json) {
    String readString(String key) {
      final value = json[key];
      return value is String ? value.trim() : '';
    }

    return Sticker(
      id: readString('id'),
      fileName: readString('file'),
      mimeType: readString('mimeType'),
      createdAtMs: json['createdAtMs'] is int ? json['createdAtMs'] as int : 0,
    );
  }
}
