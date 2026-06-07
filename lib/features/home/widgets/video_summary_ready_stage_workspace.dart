import 'package:flutter/material.dart';

import '../../../app/routing/app_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../services/models/common_dto.dart';
import '../../../services/models/video_resource_dto.dart';
import '../../../services/video_service.dart';
import '../video_summary_models.dart';
import 'video_summary_processing_widgets.dart';

class ReadyStageWorkspace extends StatefulWidget {
  const ReadyStageWorkspace({
    required this.highlighted,
    required this.videoAsset,
    required this.isGenerating,
    required this.onUploadCardPressed,
    required this.isUploading,
    required this.uploadProgress,
    super.key,
  });

  final bool highlighted;
  final VideoAssetInfo videoAsset;
  final bool isGenerating;
  final VoidCallback onUploadCardPressed;
  final bool isUploading;
  final double uploadProgress;

  @override
  State<ReadyStageWorkspace> createState() => _ReadyStageWorkspaceState();
}

class _ReadyStageWorkspaceState extends State<ReadyStageWorkspace> {
  final VideoService _videoService = const VideoService();

  List<VideoResourceResponseData> _videos = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await _videoService.listVideos(
        params: const PageParams(page: 1, pageSize: 20, sort: '-created_at'),
      );
      if (!mounted) return;
      setState(() {
        _videos = _deduplicateVideos(resp.data);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  /// 按 videoId 去重，保留列表中首次出现的条目。
  /// 由于 API 已按 -created_at 排序，首次出现即为最新记录。
  List<VideoResourceResponseData> _deduplicateVideos(
    List<VideoResourceResponseData> videos,
  ) {
    final seen = <String>{};
    return videos.where((v) => seen.add(v.videoId)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HeroCard(
          stage: VideoSummaryStage.ready,
          highlighted: widget.highlighted,
          videoAsset: widget.videoAsset,
          processingSnapshot: null,
          processingExpanded: false,
          isUploading: widget.isUploading,
          uploadProgress: widget.uploadProgress,
          onTap: widget.onUploadCardPressed,
        ),
        const SizedBox(height: 20),
        // 近期上传视频列表
        _RecentVideosHeader(onRefresh: _loadVideos, isLoading: _isLoading),
        const SizedBox(height: 8),
        Expanded(
          child: _buildVideoList(),
        ),
      ],
    );
  }

  Widget _buildVideoList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败：$_error', style: const TextStyle(color: Colors.red, fontSize: 12)),
            const SizedBox(height: 8),
            TextButton(onPressed: _loadVideos, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_videos.isEmpty) {
      return Center(
        child: Text(
          '暂无已上传视频',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4),
        itemCount: _videos.length,
        itemBuilder: (context, index) {
          final video = _videos[index];
          return _VideoListItem(
            video: video,
            onTap: () {
              AppNavigator.openVideoDetail(context, videoId: video.videoId);
            },
          );
        },
      ),
    );
  }
}

class _RecentVideosHeader extends StatefulWidget {
  const _RecentVideosHeader({required this.onRefresh, required this.isLoading});

  final VoidCallback onRefresh;
  final bool isLoading;

  @override
  State<_RecentVideosHeader> createState() => _RecentVideosHeaderState();
}

class _RecentVideosHeaderState extends State<_RecentVideosHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(_RecentVideosHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) {
      _spinController.repeat();
    } else if (!widget.isLoading && oldWidget.isLoading) {
      _spinController.stop();
      // 将图标归位到初始角度
      _spinController.animateBack(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '最近上传',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.isLoading ? null : widget.onRefresh,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: RotationTransition(
              turns: _spinController,
              child: const Icon(
                Icons.refresh_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoListItem extends StatelessWidget {
  const _VideoListItem({required this.video, required this.onTap});

  final VideoResourceResponseData video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final taskCount = video.taskRefCount ?? 0;
    final dateLabel = _fmtTime(video.createdAt);
    final fileName =
        video.fileName.isNotEmpty ? video.fileName : video.videoId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFEEF0F4)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                // 视频图标
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    size: 20,
                    color: Color(0xFF4B6BF5),
                  ),
                ),
                const SizedBox(width: 12),
                // 标题 + 日期
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dateLabel.isNotEmpty ? dateLabel : video.videoId,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // 任务数徽章
                if (taskCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF3FE),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$taskCount',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2F69E8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ISO 8601 → "yyyy-MM-dd HH:mm"（精确到分）。
String _fmtTime(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso);
    final y = dt.year.toString();
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$y-$mo-$d $h:$mi';
  } catch (_) {
    return iso;
  }
}
