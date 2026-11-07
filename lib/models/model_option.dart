/// 从供应商 `/models` 接口获取到的单个模型信息。
class ModelOption {
  const ModelOption({
    required this.id,
    required this.name,
    required this.supportsVision,
  });

  final String id;
  final String name;

  /// 是否支持图片输入（多模态视觉识别）。
  final bool supportsVision;

  String get displayName => name.trim().isEmpty ? id : name.trim();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'supportsVision': supportsVision,
  };

  factory ModelOption.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Invalid model option');
    }

    final rawName = json['name'];
    return ModelOption(
      id: id.trim(),
      name: rawName is String && rawName.trim().isNotEmpty
          ? rawName.trim()
          : id.trim(),
      supportsVision: json['supportsVision'] == true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ModelOption &&
        other.id == id &&
        other.name == name &&
        other.supportsVision == supportsVision;
  }

  @override
  int get hashCode => Object.hash(id, name, supportsVision);

  @override
  String toString() => 'ModelOption($id, $name, vision: $supportsVision)';
}
