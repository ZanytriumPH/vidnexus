import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'video_service.dart';
import 'task_service.dart';
import 'knowledge_base_service.dart';

/// VideoService provider。
final videoServiceProvider = Provider<VideoService>((ref) => const VideoService());

/// TaskService provider。
final taskServiceProvider = Provider<TaskService>((ref) => const TaskService());

/// KnowledgeBaseService provider。
final knowledgeBaseServiceProvider = Provider<KnowledgeBaseService>(
  (ref) => const KnowledgeBaseService(),
);
