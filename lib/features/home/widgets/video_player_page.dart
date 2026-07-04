import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// 全屏视频播放页，接收后端的预签名 URL 进行流式播放。
class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    required this.videoUrl,
    this.title,
    super.key,
  });

  final String videoUrl;
  final String? title;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController _controller;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        allowBackgroundPlayback: false,
      ),
    );

    _controller.addListener(_onControllerUpdate);
    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _initialized = true;
      });
      _controller.play();
    }).catchError((Object e) {
      if (!mounted) return;
      setState(() {
        _error = '视频加载失败，请检查网络后重试';
      });
    });
  }

  void _onControllerUpdate() {
    // 播放结束或出错时刷新 UI
    if (_controller.value.hasError) {
      setState(() {
        _error = _controller.value.errorDescription ?? '播放出错';
      });
    }
    if (mounted) {
      setState(() {}); // 驱动进度条等控件更新
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerUpdate);
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showSystemUI = MediaQuery.of(context).orientation == Orientation.portrait;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: showSystemUI
          ? AppBar(
              backgroundColor: Colors.black,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              title: Text(
                widget.title ?? '视频回放',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              systemOverlayStyle: SystemUiOverlayStyle.light,
            )
          : null,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildError();
    }

    if (!_initialized) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              '正在加载视频...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          // 播放/暂停按钮叠加层
          if (!_controller.value.isPlaying)
            const Center(
              child: Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 72),
            ),
          // 底部控制栏
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final position = _controller.value.position;
    final duration = _controller.value.duration;
    final buffered = _controller.value.buffered;
    final isLive = duration == Duration.zero;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black87,
            Colors.transparent,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLive) ...[
              // 进度条
              LayoutBuilder(
                builder: (context, constraints) {
                  final max = constraints.maxWidth;
                  final posFraction = duration.inMilliseconds > 0
                      ? position.inMilliseconds / duration.inMilliseconds
                      : 0.0;
                  final bufFraction = duration.inMilliseconds > 0
                      ? (buffered.isNotEmpty
                              ? buffered.last.end.inMilliseconds
                              : 0) /
                          duration.inMilliseconds
                      : 0.0;

                  return Stack(
                    children: [
                      // 缓冲进度
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: bufFraction.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white38),
                        ),
                      ),
                      // 播放进度
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: posFraction.clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: Colors.transparent,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                      // 可拖拽 seek
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            final fraction = details.localPosition.dx / max;
                            final seekTo = duration * fraction.clamp(0.0, 1.0);
                            _controller.seekTo(seekTo);
                          },
                          onHorizontalDragUpdate: (details) {
                            final fraction =
                                (details.localPosition.dx / max).clamp(0.0, 1.0);
                            final seekTo = duration * fraction;
                            _controller.seekTo(seekTo);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
            // 时间 / 播放暂停按钮行
            Row(
              children: [
                // 播放/暂停
                IconButton(
                  icon: Icon(
                    _controller.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: _togglePlayPause,
                ),
                if (!isLive) ...[
                  Text(
                    _formatDuration(position),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(duration),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ] else ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            Text(
              '视频播放失败',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              onPressed: () {
                setState(() {
                  _error = null;
                  _initialized = false;
                });
                _controller.initialize().then((_) {
                  if (!mounted) return;
                  setState(() {
                    _initialized = true;
                  });
                  _controller.play();
                }).catchError((Object e) {
                  if (!mounted) return;
                  setState(() {
                    _error = '视频加载失败，请检查网络后重试';
                  });
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
