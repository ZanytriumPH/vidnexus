import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'video_service.dart';
import 'task_service.dart';
import 'knowledge_base_service.dart';
import 'global_chat_service.dart';
import 'global_qa_service.dart';
import 'video_qa_service.dart';
import 'attachment_service.dart';
import 'upload_service.dart';
import 'device_service.dart';

/// VideoService provider。
final videoServiceProvider = Provider<VideoService>((ref) => const VideoService());

/// TaskService provider。
final taskServiceProvider = Provider<TaskService>((ref) => const TaskService());

/// KnowledgeBaseService provider。
final knowledgeBaseServiceProvider = Provider<KnowledgeBaseService>(
  (ref) => const KnowledgeBaseService(),
);

/// GlobalChatService provider。
final globalChatServiceProvider = Provider<GlobalChatService>(
  (ref) => const GlobalChatService(),
);

/// GlobalQAService provider。
final globalQAServiceProvider = Provider<GlobalQAService>(
  (ref) => const GlobalQAService(),
);

/// VideoQAService provider。
final videoQAServiceProvider = Provider<VideoQAService>(
  (ref) => const VideoQAService(),
);

/// AttachmentService provider（new.md 新增）。
final attachmentServiceProvider = Provider<AttachmentService>(
  (ref) => const AttachmentService(),
);

/// UploadService provider（new.md 新增）。
final uploadServiceProvider = Provider<UploadService>(
  (ref) => const UploadService(),
);

/// DeviceService provider（new.md 新增）。
final deviceServiceProvider = Provider<DeviceService>(
  (ref) => const DeviceService(),
);
