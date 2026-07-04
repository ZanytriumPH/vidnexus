import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/api/error_messages.dart';
import '../../../services/service_providers.dart';
import '../../auth/auth_controller.dart';
import '../../home/application/video_summary_session_history_controller.dart';
import '../http_knowledge_base_repository.dart';
import '../knowledge_base_models.dart';
import '../knowledge_base_repository.dart';

// ============================================================
// Repository Provider
// ============================================================

final knowledgeBaseRepositoryProvider = Provider<KnowledgeBaseRepository>((ref) {
  return HttpKnowledgeBaseRepository(
    kbService: ref.watch(knowledgeBaseServiceProvider),
    chatService: ref.watch(globalChatServiceProvider),
    qaService: ref.watch(globalQAServiceProvider),
  );
});

// ============================================================
// 1. LibraryListController — 知识库列表（首页用）
// ============================================================

class LibraryListState {
  const LibraryListState({
    this.isLoading = false,
    this.libraries = const [],
    this.errorMessage,
    this.isSelectionMode = false,
    this.selectedIds = const {},
  });

  final bool isLoading;
  final List<KnowledgeBaseLibrary> libraries;
  final String? errorMessage;
  final bool isSelectionMode;
  final Set<String> selectedIds;

  LibraryListState copyWith({
    bool? isLoading,
    List<KnowledgeBaseLibrary>? libraries,
    String? errorMessage,
    bool? isSelectionMode,
    Set<String>? selectedIds,
    bool clearError = false,
  }) {
    return LibraryListState(
      isLoading: isLoading ?? this.isLoading,
      libraries: libraries ?? this.libraries,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

class LibraryListController extends Notifier<LibraryListState> {
  KnowledgeBaseRepository get _repo => ref.read(knowledgeBaseRepositoryProvider);

  @override
  LibraryListState build() {
    // 监听登录状态：用户换号时自动刷新知识库列表
    ref.listen(authControllerProvider, (prev, next) {
      final prevUserId = prev?.currentUser?.userId;
      final nextUserId = next.currentUser?.userId;
      if (prev != null && prevUserId != nextUserId) {
        Future.microtask(_loadLibraries);
      }
    });

    Future.microtask(_loadLibraries);
    return const LibraryListState();
  }

  Future<void> _loadLibraries() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await _repo.listLibraries();
      state = state.copyWith(
        isLoading: false,
        libraries: resp.data,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFriendlyError.fromException(e),
      );
    }
  }

  Future<void> refresh() => _loadLibraries();

  Future<KnowledgeBaseLibrary?> createLibrary({
    required String name,
    String? category,
    String? description,
  }) async {
    try {
      final library = await _repo.createLibrary(
        name: name,
        category: category,
        description: description,
      );
      state = state.copyWith(
        libraries: [...state.libraries, library],
      );
      return library;
    } catch (e) {
      state = state.copyWith(errorMessage: UserFriendlyError.fromException(e));
      return null;
    }
  }

  Future<void> deleteLibrary(String kbid) async {
    try {
      await _repo.deleteLibrary(kbid);
      state = state.copyWith(
        libraries: state.libraries.where((l) => l.id != kbid).toList(),
      );
      // KB 删除后端会级联删除关联任务，invalidate 侧边栏使其重新加载
      ref.invalidate(videoSummarySessionHistoryProvider);
    } catch (e) {
      state = state.copyWith(errorMessage: UserFriendlyError.fromException(e));
    }
  }

  /// 重命名知识库。
  Future<void> renameLibrary(String kbid, String newName) async {
    try {
      final updated = await _repo.updateLibrary(kbid, name: newName);
      state = state.copyWith(
        libraries: state.libraries
            .map((l) => l.id == kbid ? updated : l)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: UserFriendlyError.fromException(e));
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  /// 进入/退出删除选择模式。
  void toggleSelectionMode() {
    if (state.isSelectionMode) {
      state = state.copyWith(isSelectionMode: false, selectedIds: {});
    } else {
      state = state.copyWith(isSelectionMode: true, selectedIds: {});
    }
  }

  /// 切换某个知识库的选中状态。
  void toggleSelect(String id) {
    final ids = Set<String>.from(state.selectedIds);
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
    state = state.copyWith(selectedIds: ids);
  }

  /// 批量删除选中的知识库。
  Future<void> deleteSelected() async {
    final ids = Set<String>.from(state.selectedIds);
    for (final id in ids) {
      try {
        await _repo.deleteLibrary(id);
      } catch (_) {}
    }
    state = state.copyWith(
      libraries: state.libraries.where((l) => !ids.contains(l.id)).toList(),
      isSelectionMode: false,
      selectedIds: {},
    );
    // 批量删除后级联删除关联任务，invalidate 侧边栏使其重新加载
    ref.invalidate(videoSummarySessionHistoryProvider);
  }
}

final libraryListControllerProvider =
    NotifierProvider<LibraryListController, LibraryListState>(
      LibraryListController.new,
    );

// ============================================================
// 2. SelectedLibraryController — 选中的知识库详情（Session/Chat/Sources 用）
// ============================================================

class SelectedLibraryState {
  const SelectedLibraryState({
    this.isLoading = false,
    this.selectedLibrary,
    this.errorMessage,
  });

  final bool isLoading;
  final KnowledgeBaseLibrary? selectedLibrary;
  final String? errorMessage;

  SelectedLibraryState copyWith({
    bool? isLoading,
    KnowledgeBaseLibrary? selectedLibrary,
    String? errorMessage,
    bool clearError = false,
    bool clearSelection = false,
  }) {
    return SelectedLibraryState(
      isLoading: isLoading ?? this.isLoading,
      selectedLibrary:
          clearSelection ? null : (selectedLibrary ?? this.selectedLibrary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class SelectedLibraryController extends Notifier<SelectedLibraryState> {
  KnowledgeBaseRepository get _repo => ref.read(knowledgeBaseRepositoryProvider);

  @override
  SelectedLibraryState build() {
    return const SelectedLibraryState();
  }

  Future<void> selectLibrary(String kbid) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final library = await _repo.getLibrary(kbid);
      state = state.copyWith(
        isLoading: false,
        selectedLibrary: library,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: UserFriendlyError.fromException(e),
      );
    }
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true);
  }

  /// 即时向当前知识库的对话列表中插入一条新会话。
  /// 用于用户发起提问后不等 AI 回复完成就在列表中显示该会话。
  void addConversation(KnowledgeConversationPreview conversation) {
    final library = state.selectedLibrary;
    if (library == null) return;
    // 避免重复插入（同一 chatId 已存在则不添加）
    final exists = library.conversations.any((c) => c.id == conversation.id);
    if (exists) return;
    final updated = KnowledgeBaseLibrary(
      id: library.id,
      title: library.title,
      meta: library.meta,
      description: library.description,
      sourceCount: library.sourceCount,
      sources: library.sources,
      conversations: [conversation, ...library.conversations],
      latestQuestion: library.latestQuestion,
    );
    state = state.copyWith(selectedLibrary: updated);
  }

  /// 从当前知识库中删除一个来源。
  Future<void> deleteSource(String sourceId) async {
    final library = state.selectedLibrary;
    if (library == null) return;
    try {
      await _repo.deleteSource(kbid: library.id, sourceId: sourceId);
      final updated = KnowledgeBaseLibrary(
        id: library.id,
        title: library.title,
        meta: library.meta,
        description: library.description,
        sourceCount: library.sourceCount - 1,
        sources: library.sources.where((s) => s.id != sourceId).toList(),
        conversations: library.conversations,
        latestQuestion: library.latestQuestion,
      );
      state = state.copyWith(selectedLibrary: updated);
    } catch (e) {
      state = state.copyWith(errorMessage: '删除来源失败，请重试');
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

final selectedLibraryControllerProvider =
    NotifierProvider<SelectedLibraryController, SelectedLibraryState>(
      SelectedLibraryController.new,
    );

// ============================================================
// 向后兼容别名（逐步迁移后删除）
// ============================================================

/// @deprecated 使用 [libraryListControllerProvider] 或 [selectedLibraryControllerProvider]
final knowledgeBaseControllerProvider = libraryListControllerProvider;
