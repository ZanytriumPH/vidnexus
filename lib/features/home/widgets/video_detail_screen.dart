import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routing/app_router.dart';
import '../../../services/api/api_client.dart';
import '../../../services/api/error_messages.dart';
import '../../../services/models/common_dto.dart';
import '../../../services/models/video_resource_dto.dart';
import '../../../services/models/video_summary_task_dto.dart';
import '../../../services/service_providers.dart';
import '../../../services/task_service.dart';
import '../../../services/video_service.dart';
import '../../knowledge_base/application/knowledge_base_controller.dart';
import 'video_player_page.dart';
import 'video_summary_processing_widgets.dart';

/// 视频详情页：展示视频信息 + 关联任务列表 + 发起新任务。
class VideoDetailScreen extends ConsumerStatefulWidget {
  const VideoDetailScreen({required this.videoId, super.key});

  final String videoId;

  @override
  ConsumerState<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends ConsumerState<VideoDetailScreen> {
  final VideoService _videoService = const VideoService();
  final TaskService _taskService = const TaskService();

  VideoResourceResponseData? _video;
  List<VideoSummaryTaskResponseData> _tasks = [];
  int _taskTotalCount = 0;
  bool _isLoading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _cancelPreprocessingPoll();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _videoService.getVideo(widget.videoId),
        _taskService.listVideoTasks(
          widget.videoId,
          params: const PageParams(page: 1, pageSize: 50, sort: '-created_at'),
        ),
      ]);
      if (!mounted) return;
      final videoResp = results[0] as ApiResponse<VideoResourceResponseData>;
      final tasksResp =
          results[1] as ApiListResponse<VideoSummaryTaskResponseData>;
      setState(() {
        _video = videoResp.data;
        _tasks = tasksResp.data;
        _taskTotalCount = tasksResp.pagination?.total ?? tasksResp.data.length;
        _isLoading = false;
      });
      _startPreprocessingPollIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = UserFriendlyError.fromException(e);
      });
    }
  }

  /// 视频预处理是否已完成（转录 + 关键帧提取均已结束）。条件来自 API 规范 new.md:298。
  bool _isVideoReady(VideoResourceResponseData? video) {
    if (video == null) return false;
    return video.transcribeStatus == 'COMPLETED' &&
        video.frameExtractionStatus == 'COMPLETED' &&
        video.extractCompletedAt != null;
  }

  /// 视频预处理是否已失败。
  bool _isPreprocessingFailed(VideoResourceResponseData? video) {
    if (video == null) return false;
    return video.transcribeStatus == 'FAILED' ||
        video.frameExtractionStatus == 'FAILED';
  }

  /// 若视频预处理未完成且无已有任务，启动 5 秒间隔轮询。
  void _startPreprocessingPollIfNeeded() {
    _cancelPreprocessingPoll();
    // 已有任务或已完成/已失败 → 无需轮询
    if (_tasks.isNotEmpty || _isVideoReady(_video) || _isPreprocessingFailed(_video)) {
      return;
    }
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      try {
        final resp = await _videoService.getVideo(widget.videoId);
        if (!mounted) return;
        final video = resp.data;
        setState(() => _video = video);
        if (_isVideoReady(video) || _isPreprocessingFailed(video)) {
          _cancelPreprocessingPoll();
        }
      } catch (_) {
        // 单次轮询失败静默跳过，下次继续
      }
    });
  }

  /// 取消预处理状态轮询。
  void _cancelPreprocessingPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _deleteVideo() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('删除视频'),
        content: const Text(
          '确定要删除此视频吗？删除后不可恢复，关联的所有任务也将一并移除。',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await _videoService.deleteVideo(widget.videoId);
      if (!mounted) return;
      // 回到上一页（主页面）
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败：${UserFriendlyError.fromException(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '视频详情',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            color: Colors.red.shade400,
            onPressed: _deleteVideo,
            tooltip: '删除视频',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '加载失败：$_error',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _loadData, child: const Text('重试')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _buildVideoInfoCard(),
                  const SizedBox(height: 24),
                  _buildTasksSection(),
                ],
              ),
            ),
      bottomNavigationBar: _isLoading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: _buildBottomButton(context),
                ),
              ),
            ),
    );
  }

  Widget _buildVideoInfoCard() {
    final v = _video;
    if (v == null) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      color: const Color(0xFFF7F9FC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE8ECF1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    '文件名',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
                Expanded(
                  child: Text(
                    v.fileName,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            WhiteButtonBar(
              label: '视频回放',
              leadingIcon: Icons.play_arrow_rounded,
              onTap: _openPlayback,
            ),
          ],
        ),
      ),
    );
  }

  /// 底部按钮：根据视频预处理状态和已有任务切换形态。
  Widget _buildBottomButton(BuildContext context) {
    // 已有任务 → 始终正常可用
    if (_tasks.isNotEmpty) {
      return _buildNormalButton(context);
    }

    // 预处理失败 → 红色禁用
    if (_isPreprocessingFailed(_video)) {
      return _buildFailedButton();
    }

    // 预处理完成 → 正常可用
    if (_isVideoReady(_video)) {
      return _buildNormalButton(context);
    }

    // 预处理进行中 → 灰色加载中
    return _buildProcessingButton();
  }

  /// 正常蓝色按钮：发起新任务。
  Widget _buildNormalButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showCreateTaskSheet(context),
      icon: const Icon(Icons.add, size: 20),
      label: const Text('发起新任务', style: TextStyle(fontSize: 15)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2F69E8),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }

  /// 灰色禁用按钮：预处理进行中。
  Widget _buildProcessingButton() {
    return ElevatedButton(
      onPressed: null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD1D5DB),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFD1D5DB),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8),
          Text('视频正在预处理中...', style: TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  /// 红色禁用按钮：预处理失败。
  Widget _buildFailedButton() {
    return ElevatedButton(
      onPressed: null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFEF4444),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFEF4444),
        disabledForegroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 18),
          SizedBox(width: 8),
          Text('预处理失败', style: TextStyle(fontSize: 15)),
        ],
      ),
    );
  }

  Future<void> _openPlayback() async {
    final v = _video;
    if (v == null) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var videoUrl = v.presignedUrl ?? '';
      final ossKey = v.ossKey;

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading

      // Local dev mode: presigned_url is file:// → convert to HTTP stream endpoint
      if (videoUrl.startsWith('file://') &&
          ossKey != null &&
          ossKey.isNotEmpty) {
        final baseUrl = ApiClient.instance.options.baseUrl;
        videoUrl =
            '$baseUrl/api/v1/files/stream?object_key=${Uri.encodeComponent(ossKey)}';
      }

      if (videoUrl.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('视频地址暂不可用，请稍后重试')),
        );
        return;
      }

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoPlayerPage(
            videoUrl: videoUrl,
            title: v.fileName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('获取视频播放地址失败：${UserFriendlyError.fromException(e)}')),
      );
    }
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '关联任务 ($_taskTotalCount)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (_tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Center(
              child: Text(
                '暂无任务，点击下方按钮发起',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            ),
          )
        else
          ..._tasks.map((task) => _buildTaskItem(task)),
      ],
    );
  }

  Widget _buildTaskItem(VideoSummaryTaskResponseData task) {
    final statusLabel = _workflowStateLabel(task.workflowState);
    final statusColor = _workflowStateColor(task.workflowState);
    final dateLabel = _formatDateTime(task.createdAt);

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFEEF0F4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          AppNavigator.goToHomeWithVideo(
            context,
            videoId: widget.videoId,
            taskId: task.taskId,
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _taskTitle(task),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        KbNameTag(
                          kbName: task.kbName ?? '',
                          kbid: task.kbid,
                        ),
                        if (dateLabel.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            dateLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 任务条目标题：
  /// 优先从 finalSummary 提取 # 标题，其次从 draftSummary 提取，否则回退原始标题。
  /// 提取后过滤 [xx:xx-yy:yy] 时间戳。
  String _taskTitle(VideoSummaryTaskResponseData task) {
    // 1. 最终稿
    if (task.workflowState == 'COMPLETED') {
      final title = _extractMarkdownTitle(task.finalSummary);
      if (title != null) return title;
    }
    // 2. 初稿
    final draftTitle = _extractMarkdownTitle(task.draftSummary);
    if (draftTitle != null) return draftTitle;
    // 3. 回退
    return task.title ?? task.videoId;
  }

  /// 从 markdown 文本提取第一个 # 标题，并过滤 [xx:xx-yy:yy] 时间戳。
  String? _extractMarkdownTitle(String? text) {
    if (text == null || text.isEmpty) return null;
    final match = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(text);
    if (match == null) return null;
    final raw = match.group(1)?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.replaceAll(RegExp(r'\s*\[\d{2}:\d{2}-\d{2}:\d{2}\]'), '').trim();
  }

  String _workflowStateLabel(String state) {
    return switch (state) {
      'COMPLETED' => '已完成',
      'WAITING_USER_APPROVAL' => '待审批',
      'DRAFT_GENERATING' => '生成中',
      'FINAL_GENERATING' => '终稿中',
      'FAILED' => '失败',
      _ => '处理中',
    };
  }

  Color _workflowStateColor(String state) {
    return switch (state) {
      'COMPLETED' => const Color(0xFF22C55E),
      'WAITING_USER_APPROVAL' => const Color(0xFFF59E0B),
      'FAILED' => const Color(0xFFEF4444),
      _ => const Color(0xFF2F69E8),
    };
  }

  /// 将 ISO 8601 时间字符串转为 "yyyy-MM-dd HH:mm" 格式。
  static String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoString);
      final y = dt.year.toString();
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final min = dt.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$min';
    } catch (_) {
      return isoString;
    }
  }

  // ──── 发起新任务 BottomSheet ────

  void _showCreateTaskSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return _CreateTaskBottomSheet(videoId: widget.videoId);
      },
    );
  }
}

/// 发起新任务的 BottomSheet：选 KB + 输入偏好 + 确认创建。
class _CreateTaskBottomSheet extends ConsumerStatefulWidget {
  const _CreateTaskBottomSheet({required this.videoId});

  final String videoId;

  @override
  ConsumerState<_CreateTaskBottomSheet> createState() =>
      _CreateTaskBottomSheetState();
}

class _CreateTaskBottomSheetState
    extends ConsumerState<_CreateTaskBottomSheet> {
  String? _selectedKbid;
  final TextEditingController _preferenceController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _preferenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kbState = ref.watch(libraryListControllerProvider);
    // 过滤：不显式过滤，用户可选择任意知识库（包括默认知识库）
    final libraries = kbState.libraries;

    // 等待 KB 列表加载
    if (kbState.isLoading && libraries.isEmpty) {
      ref.read(libraryListControllerProvider.notifier).refresh();
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: Text(
              '发起新任务',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          // KB 选择区域
          const Text(
            '选择知识库',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (kbState.isLoading && libraries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE8ECF1)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: libraries.length + 1, // +1 for "新建知识库"
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (context, index) {
                  if (index == libraries.length) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.add,
                        size: 20,
                        color: Color(0xFF2F69E8),
                      ),
                      title: const Text(
                        '新建知识库',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2F69E8),
                        ),
                      ),
                      onTap: _isCreating ? null : () => _createNewKb(context),
                    );
                  }
                  final kb = libraries[index];
                  final isSelected = kb.id == _selectedKbid;
                  return ListTile(
                    dense: true,
                    title: Text(kb.title, style: const TextStyle(fontSize: 14)),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            size: 20,
                            color: Color(0xFF2F69E8),
                          )
                        : null,
                    selected: isSelected,
                    onTap: _isCreating
                        ? null
                        : () {
                            setState(() {
                              _selectedKbid = kb.id;
                            });
                          },
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          // 偏好输入
          const Text(
            '总结偏好（可选）',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _preferenceController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: '例如：请按行业趋势、关键结论和行动建议展开',
              hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE8ECF1)),
              ),
              contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            ),
          ),
          const SizedBox(height: 20),
          // 创建按钮
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: (_selectedKbid == null || _isCreating)
                  ? null
                  : () => _createTask(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F69E8),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF8AAEF6),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('创建任务', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createTask(
    BuildContext context, {
    String? replaceExistingTaskId,
  }) async {
    if (_selectedKbid == null) return;

    setState(() => _isCreating = true);

    try {
      final taskService = ref.read(taskServiceProvider);
      final preference = _preferenceController.text.trim();

      // 1. 创建任务
      final createResp = await taskService.createTask(
        kbid: _selectedKbid!,
        videoId: widget.videoId,
        userInitialPreference: preference.isNotEmpty ? preference : null,
        replaceExistingTaskId: replaceExistingTaskId,
      );
      final taskId = createResp.data?.taskId;
      if (taskId == null || taskId.isEmpty) {
        throw Exception('任务创建失败，请稍后重试');
      }

      // 2. 触发分析
      try {
        await taskService.startAnalysis(taskId);
      } catch (_) {
        // 后端可能已自动启动，忽略错误
      }

      if (!mounted) return;

      // 3. 关闭 BottomSheet → 跳转首页
      Navigator.of(context).pop(); // close bottom sheet
      Navigator.of(context).pop(); // close detail page
      AppNavigator.goToHomeWithVideo(
        context,
        videoId: widget.videoId,
        taskId: taskId,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      if (e.response?.statusCode == 409) {
        // 409 Conflict: 同 (KB, video) 已有任务
        final conflict = TaskConflictData.tryExtract(e.response?.data);
        if (conflict != null) {
          if (!mounted) return;
          final replace = await _showReplaceConfirmationDialog(
            context,
            conflict,
          );
          if (replace == true && mounted) {
            _createTask(
              context,
              replaceExistingTaskId: conflict.existingTaskId,
            );
            return;
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('任务创建失败：${ApiError.fromDioException(e).userMessage}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('任务创建失败：${UserFriendlyError.fromException(e)}'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _createNewKb(BuildContext context) async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('新建知识库'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: '知识库名称'),
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.pop(ctx, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, nameController.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty || !mounted) return;

    setState(() => _isCreating = true);

    try {
      final controller = ref.read(libraryListControllerProvider.notifier);
      final newLibrary = await controller.createLibrary(name: name);
      if (newLibrary != null && mounted) {
        setState(() {
          _selectedKbid = newLibrary.id;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('创建知识库失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  /// 显示 409 冲突替换确认对话框，返回 true 表示用户同意替换。
  Future<bool> _showReplaceConfirmationDialog(
    BuildContext context,
    TaskConflictData conflict,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('任务已存在'),
        content: Text(
          conflict.message ?? '该知识库中已存在同一视频的摘要任务，是否替换？',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('替换', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
