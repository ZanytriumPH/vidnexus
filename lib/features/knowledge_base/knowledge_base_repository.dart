import '../../services/models/common_dto.dart';
import 'knowledge_base_models.dart';

/// 知识库数据仓库抽象接口。
///
/// 返回 [KnowledgeBaseLibrary] 等 UI 展示模型，
/// 内部由 Http 实现负责调用 [KnowledgeBaseService] 并完成 DTO → Model 映射。
abstract class KnowledgeBaseRepository {
  const KnowledgeBaseRepository();

  /// 获取知识库列表（异步，支持分页）。
  Future<ApiListResponse<KnowledgeBaseLibrary>> listLibraries({
    PageParams params = const PageParams(),
  });

  /// 获取单个知识库详情（含来源列表）。
  Future<KnowledgeBaseLibrary?> getLibrary(String kbid);

  /// 创建知识库。
  Future<KnowledgeBaseLibrary> createLibrary({
    required String name,
    String? category,
    String? description,
  });

  /// 更新知识库。
  Future<KnowledgeBaseLibrary> updateLibrary(
    String kbid, {
    String? name,
    String? category,
    String? description,
  });

  /// 删除知识库。
  Future<void> deleteLibrary(String kbid);

  /// 获取知识库下的视频来源列表。
  Future<List<KnowledgeSourceItem>> listSources(String kbid);

  /// 向知识库绑定视频。
  Future<void> bindVideo({required String kbid, required String videoId});
}
