class ModelInfo {
  const ModelInfo({required this.id, this.ownedBy, this.maxInputTokens});

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String,
      ownedBy: json['owned_by'] as String?,
      maxInputTokens: (json['max_input_tokens'] as num?)?.toInt(),
    );
  }

  final String id;
  final String? ownedBy;
  final int? maxInputTokens;

  @override
  bool operator ==(Object other) => other is ModelInfo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
