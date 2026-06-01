import '../../services/global_chat_service.dart';
import '../../services/knowledge_base_service.dart';
import '../../services/models/common_dto.dart';
import 'knowledge_base_models.dart';
import 'knowledge_base_repository.dart';

/// 基于 HTTP 的真实 KnowledgeBaseRepository 实现。
class HttpKnowledgeBaseRepository extends KnowledgeBaseRepository {
  HttpKnowledgeBaseRepository({
    required KnowledgeBaseService kbService,
    required GlobalChatService chatService,
  })  : _kbService = kbService,
       _chatService = chatService;

  final KnowledgeBaseService _kbService;
  final GlobalChatService _chatService;

  @override
  Future<ApiListResponse<KnowledgeBaseLibrary>> listLibraries({
    PageParams params = const PageParams(),
  }) async {
    final resp = await _kbService.listKBs(params: params);

    final libraries = resp.data.map((dto) {
      return KnowledgeBaseLibrary(
        id: dto.kbid,
        title: dto.name,
        meta: _buildMeta(dto.category, dto.createdAt),
        description: dto.description ?? '',
        sourceCount: 0, // 由后续 listSources 异步填充
        sources: const [],
        conversations: const [], // Phase 5 接入
      );
    }).toList();

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

    final conversations = chatsResp.data.map((dto) {
      return KnowledgeConversationPreview(
        id: dto.chatId,
        title: dto.chatTitle,
        preview: dto.chatTitle,
        dateLabel: _buildDateLabel(dto.createdAt),
        messages: const [],
      );
    }).toList();

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
        subtitle: '上传于 ${video.createdAt}',
        kindLabel: '视频',
      );
    }).toList();
  }

  String _buildMeta(String? category, String? createdAt) {
    final parts = <String>[];
    if (category != null && category.isNotEmpty) parts.add(category);
    if (createdAt != null && createdAt.isNotEmpty) {
      parts.add('创建于 $createdAt');
    }
    return parts.isEmpty ? '暂无信息' : parts.join(' · ');
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
