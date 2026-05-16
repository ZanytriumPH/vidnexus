/// Knowledge Base 域请求/响应 DTO，与后端 schemas 对齐。
library;

class KBRetrievalConfig {
  const KBRetrievalConfig({
    this.topK = 5,
    this.rerank = true,
  });

  final int topK;
  final bool rerank;

  factory KBRetrievalConfig.fromJson(Map<String, dynamic> json) {
    return KBRetrievalConfig(
      topK: json['top_k'] as int? ?? 5,
      rerank: json['rerank'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'top_k': topK,
        'rerank': rerank,
      };
}

class KBToolPreferences {
  const KBToolPreferences({
    this.allowWebSearch = false,
  });

  final bool allowWebSearch;

  factory KBToolPreferences.fromJson(Map<String, dynamic> json) {
    return KBToolPreferences(
      allowWebSearch: json['allow_web_search'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'allow_web_search': allowWebSearch,
      };
}

class KBLLMPolicy {
  const KBLLMPolicy({
    this.temperature = 0.2,
  });

  final double temperature;

  factory KBLLMPolicy.fromJson(Map<String, dynamic> json) {
    return KBLLMPolicy(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.2,
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
      };
}

class KBConfig {
  const KBConfig({
    this.retrieval = const KBRetrievalConfig(),
    this.toolPreferences = const KBToolPreferences(),
    this.llmPolicy = const KBLLMPolicy(),
  });

  final KBRetrievalConfig retrieval;
  final KBToolPreferences toolPreferences;
  final KBLLMPolicy llmPolicy;

  factory KBConfig.fromJson(Map<String, dynamic> json) {
    return KBConfig(
      retrieval: json['retrieval'] != null
          ? KBRetrievalConfig.fromJson(json['retrieval'] as Map<String, dynamic>)
          : const KBRetrievalConfig(),
      toolPreferences: json['tool_preferences'] != null
          ? KBToolPreferences.fromJson(
              json['tool_preferences'] as Map<String, dynamic>)
          : const KBToolPreferences(),
      llmPolicy: json['llm_policy'] != null
          ? KBLLMPolicy.fromJson(json['llm_policy'] as Map<String, dynamic>)
          : const KBLLMPolicy(),
    );
  }

  Map<String, dynamic> toJson() => {
        'retrieval': retrieval.toJson(),
        'tool_preferences': toolPreferences.toJson(),
        'llm_policy': llmPolicy.toJson(),
      };
}

/// POST /api/v1/kbs 请求体。
class KnowledgeBaseCreateRequest {
  const KnowledgeBaseCreateRequest({
    required this.name,
    this.category,
    this.description,
    this.config,
  });

  final String name;
  final String? category;
  final String? description;
  final KBConfig? config;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (category != null) 'category': category,
        if (description != null) 'description': description,
        if (config != null) 'config': config!.toJson(),
      };
}

/// PATCH /api/v1/kbs/{kbid} 请求体。
class KnowledgeBaseUpdateRequest {
  const KnowledgeBaseUpdateRequest({
    this.name,
    this.category,
    this.description,
    this.config,
  });

  final String? name;
  final String? category;
  final String? description;
  final KBConfig? config;

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (category != null) 'category': category,
        if (description != null) 'description': description,
        if (config != null) 'config': config!.toJson(),
      };
}

/// KnowledgeBase 响应对象。
class KnowledgeBaseResponseData {
  const KnowledgeBaseResponseData({
    required this.kbid,
    required this.ownerId,
    required this.name,
    this.category,
    this.description,
    this.vectorCollectionName,
    this.config,
    this.createdAt,
  });

  final String kbid;
  final String ownerId;
  final String name;
  final String? category;
  final String? description;
  final String? vectorCollectionName;
  final KBConfig? config;
  final String? createdAt;

  factory KnowledgeBaseResponseData.fromJson(Map<String, dynamic> json) {
    return KnowledgeBaseResponseData(
      kbid: json['kbid'] as String? ?? '',
      ownerId: json['owner_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String?,
      description: json['description'] as String?,
      vectorCollectionName: json['vector_collection_name'] as String?,
      config: json['config'] != null
          ? KBConfig.fromJson(json['config'] as Map<String, dynamic>)
          : null,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// POST /api/v1/kbs/{kbid}/videos 请求体。
class KBVideoBindRequest {
  const KBVideoBindRequest({required this.videoId});

  final String videoId;

  Map<String, dynamic> toJson() => {'video_id': videoId};
}

/// KB 绑定视频响应 data。
class KBVideoBindResponseData {
  const KBVideoBindResponseData({
    required this.kbid,
    required this.videoId,
  });

  final String kbid;
  final String videoId;

  factory KBVideoBindResponseData.fromJson(Map<String, dynamic> json) {
    return KBVideoBindResponseData(
      kbid: json['kbid'] as String? ?? '',
      videoId: json['video_id'] as String? ?? '',
    );
  }
}

/// KB 删除响应 data。
class KBDeleteResponseData {
  const KBDeleteResponseData({required this.kbid});

  final String kbid;

  factory KBDeleteResponseData.fromJson(Map<String, dynamic> json) {
    return KBDeleteResponseData(kbid: json['kbid'] as String? ?? '');
  }
}

/// KB 内视频摘要项（GET /api/v1/kbs/{kbid}/videos 返回）。
class KBVideoItem {
  const KBVideoItem({
    required this.videoId,
    required this.fileName,
    required this.createdAt,
  });

  final String videoId;
  final String fileName;
  final String createdAt;

  factory KBVideoItem.fromJson(Map<String, dynamic> json) {
    return KBVideoItem(
      videoId: json['video_id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}
