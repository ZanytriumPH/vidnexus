import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/service_providers.dart';
import '../http_knowledge_base_repository.dart';
import '../knowledge_base_models.dart';
import '../knowledge_base_repository.dart';

/// Repository Provider。
final knowledgeBaseRepositoryProvider = Provider<KnowledgeBaseRepository>((ref) {
  return HttpKnowledgeBaseRepository(
    kbService: ref.watch(knowledgeBaseServiceProvider),
  );
});

/// 知识库列表状态。
class KnowledgeBaseState {
  const KnowledgeBaseState({
    this.isLoading = false,
    this.libraries = const [],
    this.selectedLibrary,
    this.errorMessage,
  });

  final bool isLoading;
  final List<KnowledgeBaseLibrary> libraries;
  final KnowledgeBaseLibrary? selectedLibrary;
  final String? errorMessage;

  KnowledgeBaseState copyWith({
    bool? isLoading,
    List<KnowledgeBaseLibrary>? libraries,
    KnowledgeBaseLibrary? selectedLibrary,
    String? errorMessage,
    bool clearError = false,
    bool clearSelection = false,
  }) {
    return KnowledgeBaseState(
      isLoading: isLoading ?? this.isLoading,
      libraries: libraries ?? this.libraries,
      selectedLibrary:
          clearSelection ? null : (selectedLibrary ?? this.selectedLibrary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 知识库主控制器。
class KnowledgeBaseController extends Notifier<KnowledgeBaseState> {
  KnowledgeBaseRepository get _repo => ref.read(knowledgeBaseRepositoryProvider);

  @override
  KnowledgeBaseState build() {
    _loadLibraries();
    return const KnowledgeBaseState();
  }

  /// 加载知识库列表。
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
        errorMessage: e.toString(),
      );
    }
  }

  /// 刷新列表。
  Future<void> refresh() => _loadLibraries();

  /// 选中并加载知识库详情（含来源列表）。
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
        errorMessage: e.toString(),
      );
    }
  }

  /// 创建知识库。
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
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  /// 删除知识库。
  Future<void> deleteLibrary(String kbid) async {
    try {
      await _repo.deleteLibrary(kbid);
      state = state.copyWith(
        libraries: state.libraries.where((l) => l.id != kbid).toList(),
        clearSelection: state.selectedLibrary?.id == kbid,
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// 清除错误。
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// Controller Provider。
final knowledgeBaseControllerProvider =
    NotifierProvider<KnowledgeBaseController, KnowledgeBaseState>(
      KnowledgeBaseController.new,
    );
