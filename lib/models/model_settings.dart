import 'package:mori_ai/config/model_providers.dart';

/// 当前选择的供应商与模型。
class ModelSelection {
  const ModelSelection({required this.providerId, required this.modelId});

  static const ModelSelection empty = ModelSelection(
    providerId: ModelProviderCatalog.defaultProviderId,
    modelId: '',
  );

  final String providerId;
  final String modelId;

  bool get hasModel => modelId.trim().isNotEmpty;

  ModelSelection copyWith({String? providerId, String? modelId}) {
    return ModelSelection(
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ModelSelection &&
        other.providerId == providerId &&
        other.modelId == modelId;
  }

  @override
  int get hashCode => Object.hash(providerId, modelId);

  @override
  String toString() => 'ModelSelection($providerId, $modelId)';
}

/// 用户保存的一组模型配置，可在不同供应商/模型之间快速切换。
class ModelPreset {
  const ModelPreset({
    required this.id,
    required this.name,
    required this.selection,
  });

  final String id;
  final String name;
  final ModelSelection selection;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'providerId': selection.providerId,
    'modelId': selection.modelId,
  };

  factory ModelPreset.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final providerId = json['providerId'];
    final modelId = json['modelId'];

    if (id is! String ||
        id.isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        providerId is! String ||
        modelId is! String) {
      throw const FormatException('Invalid model preset');
    }

    return ModelPreset(
      id: id,
      name: name.trim(),
      selection: ModelSelection(
        providerId: providerId,
        modelId: modelId.trim(),
      ),
    );
  }
}
