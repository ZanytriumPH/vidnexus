import 'package:flutter/material.dart';

import '../../../app/routing/app_router.dart';
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
        _videos = resp.data;
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
        _RecentVideosHeader(onRefresh: _loadVideos),
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
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _videos.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
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

class _RecentVideosHeader extends StatelessWidget {
  const _RecentVideosHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '最近上传',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: onRefresh,
          visualDensity: VisualDensity.compact,
          tooltip: '刷新列表',
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
    final dateLabel = video.createdAt ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      title: Text(
        video.fileName.isNotEmpty ? video.fileName : video.videoId,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        dateLabel.isNotEmpty ? dateLabel : video.videoId,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      trailing: taskCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF3FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$taskCount个任务',
                style: const TextStyle(fontSize: 11, color: Color(0xFF2F69E8)),
              ),
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}
