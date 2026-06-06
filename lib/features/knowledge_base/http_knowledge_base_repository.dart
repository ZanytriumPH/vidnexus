import '../../services/global_chat_service.dart';
import '../../services/global_qa_service.dart';
import '../../services/knowledge_base_service.dart';
import '../../services/models/common_dto.dart';
import 'knowledge_base_models.dart';
import 'knowledge_base_repository.dart';

/// 基于 HTTP 的真实 KnowledgeBaseRepository 实现。
class HttpKnowledgeBaseRepository extends KnowledgeBaseRepository {
  HttpKnowledgeBaseRepository({
    required KnowledgeBaseService kbService,
    required GlobalChatService chatService,
    required GlobalQAService qaService,
  })  : _kbService = kbService,
       _chatService = chatService,
       _qaService = qaService;

  final KnowledgeBaseService _kbService;
  final GlobalChatService _chatService;
  final GlobalQAService _qaService;

  @override
  Future<ApiListResponse<KnowledgeBaseLibrary>> listLibraries({
    PageParams params = const PageParams(),
  }) async {
    final resp = await _kbService.listKBs(params: params);

    final libraries = <KnowledgeBaseLibrary>[];
    for (final dto in resp.data) {
      // 异步拉取该知识库的来源数量
      int sourceCount = 0;
      try {
        final sourcesResp = await _kbService.listVideos(
          dto.kbid,
          params: const PageParams(page: 1, pageSize: 1),
        );
        sourceCount = sourcesResp.pagination?.total ?? 0;
      } catch (_) {
        // 拉取失败不阻塞列表展示
      }

      // 异步拉取该知识库的最新一次提问（chatTitle）
      String? latestQuestion;
      try {
        final chatsResp = await _chatService.listChats(
          dto.kbid,
          params: const PageParams(page: 1, pageSize: 1, sort: '-created_at'),
        );
        if (chatsResp.data.isNotEmpty) {
          latestQuestion = chatsResp.data.first.chatTitle;
        }
      } catch (_) {
        // 拉取失败不阻塞列表展示
      }

      libraries.add(KnowledgeBaseLibrary(
        id: dto.kbid,
        title: dto.name,
        meta: _buildMeta(null, dto.createdAt),
        description: dto.description ?? '',
        sourceCount: sourceCount,
        sources: const [],
        conversations: const [],
        latestQuestion: latestQuestion,
      ));
    }

    return ApiListResponse(
      status: resp.status,
      data: libraries,
      pagination: resp.pagination,
      meta: resp.meta,
    );
  }

  @override
  Future<KnowledgeBaseLibrary?> getLibrary(String kbid) async {
    final resp = await _kbService.getKB(kbid);
    final dto = resp.data;
    if (dto == null) return null;

    final sources = await listSources(kbid);
    final chatsResp = await _chatService.listChats(kbid);

    final conversations = <KnowledgeConversationPreview>[];
    for (final chatDto in chatsResp.data) {
      // 拉取该会话的最新系统回答作为 preview
      String preview = chatDto.chatTitle;
      try {
        final qasResp = await _qaService.listQAs(
          kbid,
          chatDto.chatId,
          params: const PageParams(page: 1, pageSize: 1, sort: '-created_at'),
        );
        if (qasResp.data.isNotEmpty && qasResp.data.first.answerContent != null) {
          final answer = qasResp.data.first.answerContent!;
          if (answer.isNotEmpty) {
            preview = answer;
          }
        }
      } catch (_) {
        // 拉取失败使用 chatTitle 作为降级
      }

      conversations.add(KnowledgeConversationPreview(
        id: chatDto.chatId,
        title: chatDto.chatTitle,
        preview: preview,
        dateLabel: _buildDateLabel(chatDto.createdAt),
        messages: const [],
      ));
    }

    return KnowledgeBaseLibrary(
      id: dto.kbid,
      title: dto.name,
      meta: _buildMeta(dto.category, dto.createdAt),
      description: dto.description ?? '',
      sourceCount: sources.length,
      sources: sources,
      conversations: conversations,
    );
  }

  @override
  Future<KnowledgeBaseLibrary> createLibrary({
    required String name,
    String? category,
    String? description,
  }) async {
    final resp = await _kbService.createKB(
      name: name,
      category: category,
      description: description,
    );
    final dto = resp.data!;
    return KnowledgeBaseLibrary(
      id: dto.kbid,
      title: dto.name,
      meta: _buildMeta(dto.category, dto.createdAt),
      description: dto.description ?? '',
      sourceCount: 0,
      sources: const [],
      conversations: const [],
    );
  }

  @override
  Future<KnowledgeBaseLibrary> updateLibrary(
    String kbid, {
    String? name,
    String? category,
    String? description,
  }) async {
    final resp = await _kbService.updateKB(
      kbid,
      name: name,
      category: category,
      description: description,
    );
    final dto = resp.data!;
    return KnowledgeBaseLibrary(
      id: dto.kbid,
      title: dto.name,
      meta: _buildMeta(dto.category, dto.createdAt),
      description: dto.description ?? '',
      sourceCount: 0,
      sources: const [],
      conversations: const [],
    );
  }

  @override
  Future<void> deleteLibrary(String kbid) async {
    await _kbService.deleteKB(kbid);
  }

  @override
  Future<void> bindVideo({required String kbid, required String videoId}) async {
    await _kbService.bindVideo(kbid: kbid, videoId: videoId);
  }

  @override
  Future<List<KnowledgeSourceItem>> listSources(String kbid) async {
    final resp = await _kbService.listVideos(kbid);
    return resp.data.map((video) {
      return KnowledgeSourceItem(
        id: video.videoId,
        title: video.fileName,
        subtitle: '上传于 ${_formatDateTime(video.createdAt ?? '')}',
        kindLabel: '视频',
      );
    }).toList();
  }

  String _buildMeta(String? category, String? createdAt) {
    final parts = <String>[];
    if (category != null && category.isNotEmpty) parts.add(category);
    if (createdAt != null && createdAt.isNotEmpty) {
      parts.add('创建于 ${_formatDateTime(createdAt)}');
    }
    return parts.isEmpty ? '暂无信息' : parts.join(' · ');
  }

  /// 将 ISO 时间戳转换为 "年/月/日 时:分" 格式（例：2026/05/18 10:00）。
  String _formatDateTime(String isoString) {
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final y = dt.year.toString();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$y/$m/$d $h:$min';
    } catch (_) {
      return isoString;
    }
  }

  /// 将 ISO 时间戳格式化为简短日期标签（如 "5月17日"）。
  String _buildDateLabel(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString);
      return '${dt.month}月${dt.day}日';
    } catch (_) {
      return isoString;
    }
  }
}
