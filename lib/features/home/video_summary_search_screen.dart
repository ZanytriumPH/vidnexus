import 'package:flutter/material.dart';

import '../../app/routing/app_router.dart';
import '../../app/theme/app_colors.dart';
import 'widgets/video_summary_drawer_shared.dart';

class VideoSummarySearchScreen extends StatefulWidget {
  const VideoSummarySearchScreen({required this.sessions, super.key});

  final List<VideoSummaryDrawerSessionItem> sessions;

  @override
  State<VideoSummarySearchScreen> createState() =>
      _VideoSummarySearchScreenState();
}

class _VideoSummarySearchScreenState extends State<VideoSummarySearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<VideoSummaryDrawerSessionItem> _filteredSessions = [];

  @override
  void initState() {
    super.initState();
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
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey[300]!, width: 1),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 0,
                vertical: 10,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 24,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 8, right: 4),
                child: Icon(
                  Icons.search_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
              ),
              suffixIconConstraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: InkResponse(
                        radius: 12,
                        onTap: _searchController.clear,
                        child: const Icon(
                          Icons.cancel_rounded,
                          color: Color(0xFFBFC7D3),
                          size: 18,
                        ),
                      ),
                    )
                  : const SizedBox(width: 4),
              hintText: '搜索历史会话...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              hintStyle: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
            ),
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w400,
            ),
            cursorColor: AppColors.textPrimary,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () => AppNavigator.popCurrent(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '取消',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  itemCount: _filteredSessions.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = _filteredSessions[index];
                    return VideoSummaryDrawerSessionCard(
                      session: session,
                      onTap: () {
                        AppNavigator.popCurrent(context, session.id);
                      },
                    );
                  },
                ),
    );
  }
}