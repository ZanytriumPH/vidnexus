import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

class VideoSummaryDrawerSessionItem {
  const VideoSummaryDrawerSessionItem({
    required this.id,
    required this.title,
    required this.durationLabel,
    required this.detail,
    required this.isActive,
  });

  final String id;
  final String title;
  final String durationLabel;
  final String detail;
  final bool isActive;
}

class VideoSummaryHistoryDrawer extends StatelessWidget {
  const VideoSummaryHistoryDrawer({
    required this.sessions,
    required this.onNewSessionPressed,
    required this.onSessionSelected,
    required this.onSettingsPressed,
    super.key,
  });

  final List<VideoSummaryDrawerSessionItem> sessions;
  final VoidCallback onNewSessionPressed;
  final ValueChanged<String> onSessionSelected;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 320,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '会话中心',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _VideoSummarySearchScreen(
                            sessions: sessions,
                            onSessionSelected: onSessionSelected,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: onNewSessionPressed,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 48,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '＋',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '新建视频总结会话',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '历史会话',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: sessions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    return _DrawerSessionCard(
                      session: session,
                      onTap: () => onSessionSelected(session.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: onSettingsPressed,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  height: 52,
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          size: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '设置',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                            Text(
                              '调整会话默认行为',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerSessionCard extends StatelessWidget {
  const _DrawerSessionCard({required this.session, required this.onTap});

  final VideoSummaryDrawerSessionItem session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: session.isActive ? const Color(0xFFF3F7FF) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: session.isActive
                ? const Color(0xFFBFD3FF)
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${session.title} / ${session.durationLabel}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (session.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '当前',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              session.detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoSummarySearchScreen extends StatefulWidget {
  const _VideoSummarySearchScreen({
    required this.sessions,
    required this.onSessionSelected,
  });

  final List<VideoSummaryDrawerSessionItem> sessions;
  final ValueChanged<String> onSessionSelected;

  @override
  State<_VideoSummarySearchScreen> createState() =>
      _VideoSummarySearchScreenState();
}

class _VideoSummarySearchScreenState extends State<_VideoSummarySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<VideoSummaryDrawerSessionItem> _filteredSessions = [];

  @override
  void initState() {
    super.initState();
    _filteredSessions = [];
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredSessions = [];
      } else {
        _filteredSessions = widget.sessions.where((session) {
          return session.title.toLowerCase().contains(query) ||
              session.detail.toLowerCase().contains(query) ||
              session.durationLabel.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        titleSpacing: 12,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索历史会话...',
            border: InputBorder.none,
            hintStyle: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, color: AppColors.textSecondary),
              onPressed: () {
                _searchController.clear();
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _searchController.text.isEmpty
          ? const SizedBox.shrink()
          : _filteredSessions.isEmpty
              ? Center(
                  child: Text(
                    '暂无匹配结果',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  itemCount: _filteredSessions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = _filteredSessions[index];
                    return _DrawerSessionCard(
                  session: session,
                  onTap: () {
                    // Close the search screen
                    Navigator.of(context).pop();
                    // Select the session (which will subsequently close the drawer)
                    widget.onSessionSelected(session.id);
                  },
                );
              },
            ),
    );
  }
}
