import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/global_qa_service.dart';
import '../../../services/models/global_chat_dto.dart';
import '../../../services/models/video_qa_dto.dart' show AttachmentInfo;
import '../../../services/sse/sse_models.dart';
import '../../home/video_summary_presentation_models.dart' show ChatAttachment;
import '../knowledge_base_models.dart';

/// 知识库会话控制器的状态快照。
class KnowledgeBaseChatState {
  const KnowledgeBaseChatState({
    this.messages = const [],
    this.isWaitingForAnswer = false,
  });

  final List<KnowledgeChatMessage> messages;
  final bool isWaitingForAnswer;

  KnowledgeBaseChatState copyWith({
    List<KnowledgeChatMessage>? messages,
    bool? isWaitingForAnswer,
  }) {
    return KnowledgeBaseChatState(
      messages: messages ?? this.messages,
      isWaitingForAnswer: isWaitingForAnswer ?? this.isWaitingForAnswer,
    );
  }
}

/// 按 (kbid, chatId) 缓存活跃的 controller 实例。
///
/// 当用户离开对话页面后，controller 仍保留在缓存中以维持 SSE 流的
/// 消费；返回时复用同一实例，实现无缝衔接。
final _activeControllers = <({String kbid, String chatId}), KnowledgeBaseChatController>{};

/// 获取或创建知识库聊天 controller。
///
/// 同一 (kbid, chatId) 的多次调用返回同一实例，确保 SSE 流跨页面导航
/// 不被中断。initialMessages 仅在首次创建时生效。
KnowledgeBaseChatController getOrCreateKbChatController({
  required GlobalQAService qaService,
  required String kbid,
  required String chatId,
  List<KnowledgeChatMessage> initialMessages = const [],
}) {
  final key = (kbid: kbid, chatId: chatId);
  return _activeControllers.putIfAbsent(
    key,
    () => KnowledgeBaseChatController._(
      qaService: qaService,
      kbid: kbid,
      chatId: chatId,
      initialMessages: initialMessages,
    ),
  );
}

/// 管理知识库内单个会话的 QA 请求与 SSE 流消费。
///
/// 使用 [getOrCreateKbChatController] 获取实例以实现跨页面导航的
/// 持久化。Controller 自身的 [dispose] 仅取消 SSE 流，不清除缓存条目。
/// 缓存条目由外部显式管理（如用户手动新建会话时）。
class KnowledgeBaseChatController extends ChangeNotifier {
  KnowledgeBaseChatController._({
    required GlobalQAService qaService,
    required String kbid,
    required String chatId,
    List<KnowledgeChatMessage> initialMessages = const [],
  })  : _qaService = qaService,
        _kbid = kbid,
        _chatId = chatId,
        _state = KnowledgeBaseChatState(messages: List.from(initialMessages));

  final GlobalQAService _qaService;
  final String _kbid;
  final String _chatId;

  /// 当前活跃会话标识。每次 [_sendChatMessage] 开始时捕获，SSE 事件消费前比对；
  /// 不匹配则中止，防止旧 SSE 流污染新会话状态。
  Object _activeSessionKey = Object();

  /// 当前活跃的 SSE 流订阅，用于显式取消。
  StreamSubscription<SSEEvent>? _currentSSESub;

  KnowledgeBaseChatState _state;
  KnowledgeBaseChatState get state => _state;

  List<KnowledgeChatMessage> get messages => _state.messages;
  bool get isWaitingForAnswer => _state.isWaitingForAnswer;

  void _emit(KnowledgeBaseChatState newState) {
    _state = newState;
    notifyListeners();
  }

  /// 取消当前 SSE 流订阅（如果有）。
  void _cancelSSE() {
    _currentSSESub?.cancel();
    _currentSSESub = null;
  }

  /// 在 initState 时调用，判断当前会话的初始动作。
  ///
  /// - 临时 chatId（creating- / new- 前缀）：跳过
  /// - messages 为空：加载历史 QA
  /// - 最后一条是用户消息且当前未在等待回答：自动发起 QA
  void triggerInitialQA() {
    if (_chatId.startsWith('creating-') || _chatId.startsWith('new-')) {
      return;
    }

    if (_state.messages.isEmpty) {
      _loadQaHistory();
      return;
    }

    // 若已在等待回答（SSE 流进行中），不再重复发起
    if (_state.isWaitingForAnswer) return;

    final lastMessage = _state.messages.last;
    if (lastMessage.sender == KnowledgeChatSender.user) {
      final userMessages = _state.messages
          .where((m) => m.sender == KnowledgeChatSender.user)
          .toList();
      _emit(_state.copyWith(messages: userMessages));
      _sendChatMessage(
        lastMessage.text,
        attachments: lastMessage.attachments
            .map((a) => AttachmentInfo(
                  name: a.name,
                  ossKey: a.ossKey,
                  mimeType: a.mimeType,
                  sizeBytes: 0,
                  presignedUrl: a.presignedUrl,
                ))
            .toList(),
      );
    }
  }

  /// 用户发送新消息。
  void sendMessage(String text, {List<AttachmentInfo> attachments = const []}) {
    if (text.isEmpty || _state.isWaitingForAnswer) return;

    _emit(_state.copyWith(
      messages: [
        ..._state.messages,
        KnowledgeChatMessage(
          sender: KnowledgeChatSender.user,
          text: text,
          attachments: attachments
              .map((a) => ChatAttachment(
                    name: a.name,
                    ossKey: a.ossKey,
                    mimeType: a.mimeType,
                    presignedUrl: a.presignedUrl,
                  ))
              .toList(),
        ),
      ],
    ));

    _sendChatMessage(text, attachments: attachments);
  }

  /// 发起真实 QA 请求并通过 SSE 流消费回答。
  Future<void> _sendChatMessage(String text) async {
    // 取消已有的 SSE 流（防御性：sendMessage 已有 isWaitingForAnswer 守卫，
    // 但 triggerInitialQA 的重发场景下旧流可能仍在）
    _cancelSSE();

    // 切换会话标识，使旧 SSE 流（若有）的后续事件失效
    final owningSessionKey = Object();
    _activeSessionKey = owningSessionKey;

    _emit(_state.copyWith(
      isWaitingForAnswer: true,
      messages: [
        ..._state.messages,
        KnowledgeChatMessage(
          sender: KnowledgeChatSender.system,
          text: '',
        ),
      ],
    ));

    final answerBuffer = StringBuffer();
    final completer = Completer<void>();

    try {
      final sseStream = _qaService.createQAStream(
        kbid: _kbid,
        chatId: _chatId,
        questionContent: text,
      );

      _currentSSESub = sseStream.listen(
        (event) {
          // 若会话标识已变更（新消息覆盖旧流），停止消费
          if (_activeSessionKey != owningSessionKey) {
            _cancelSSE();
            return;
          }

          if (event.type == SSEEventType.delta) {
            final delta =
                event.parseData<SSEDeltaData>(SSEDeltaData.fromJson);
            if (delta != null) {
              answerBuffer.write(delta.chunk);
              final currentMessages =
                  List<KnowledgeChatMessage>.from(_state.messages);
              if (currentMessages.isNotEmpty) {
                final lastMsg = currentMessages.last;
                currentMessages[currentMessages.length - 1] =
                    KnowledgeChatMessage(
                  sender: lastMsg.sender,
                  text: answerBuffer.toString(),
                );
                _emit(_state.copyWith(messages: currentMessages));
              }
            }
          } else if (event.type == SSEEventType.done) {
            final done = event.parseData<GlobalQADoneData>(
              GlobalQADoneData.fromJson,
            );
            if (done?.answerContent != null &&
                done!.answerContent!.isNotEmpty) {
              final currentMessages =
                  List<KnowledgeChatMessage>.from(_state.messages);
              if (currentMessages.isNotEmpty) {
                final lastMsg = currentMessages.last;

                // 解析 cited_sources（来自 SSE done 事件的原始 Map 列表）
                List<CitedSource>? citedSources;
                if (done.citedSources != null &&
                    done.citedSources!.isNotEmpty) {
                  citedSources = done.citedSources!
                      .map((m) => CitedSource.fromJson(m))
                      .toList();
                }

                currentMessages[currentMessages.length - 1] =
                    KnowledgeChatMessage(
                  sender: lastMsg.sender,
                  text: done.answerContent!,
                  citedSources: citedSources,
                );
                _emit(_state.copyWith(
                  messages: currentMessages,
                  isWaitingForAnswer: false,
                ));
              }
            }
            _currentSSESub = null;
            if (!completer.isCompleted) completer.complete();
          } else if (event.type == SSEEventType.progress) {
            final progressData = event.parseData<GlobalQAProgressData>(
              GlobalQAProgressData.fromJson,
            );
            if (progressData != null) {
              final currentMessages =
                  List<KnowledgeChatMessage>.from(_state.messages);
              if (currentMessages.isNotEmpty) {
                final lastMsg = currentMessages.last;
                final steps = [
                  ...?lastMsg.progressSteps,
                  KnowledgeProgressStep(
                    phase: progressData.phase,
                    message: progressData.message,
                    timestamp: DateTime.now(),
                  ),
                ];
                currentMessages[currentMessages.length - 1] =
                    KnowledgeChatMessage(
                  sender: lastMsg.sender,
                  text: lastMsg.text,
                  progressSteps: steps,
                );
                _emit(_state.copyWith(messages: currentMessages));
              }
            }
          } else if (event.type == SSEEventType.error) {
            _currentSSESub = null;
            if (!completer.isCompleted) {
              completer.completeError(
                Exception(event.data?.toString() ?? 'SSE stream error'),
              );
            }
          }
        },
        onError: (e) {
          _currentSSESub = null;
          if (!completer.isCompleted) completer.completeError(e);
        },
        onDone: () {
          _currentSSESub = null;
          if (!completer.isCompleted) {
            _emit(_state.copyWith(isWaitingForAnswer: false));
            completer.complete();
          }
        },
        cancelOnError: false,
      );

      await completer.future;
    } catch (e) {
      // 错误处理：当前会话仍然匹配时才更新 UI
      if (_activeSessionKey != owningSessionKey) return;

      final currentMessages =
          List<KnowledgeChatMessage>.from(_state.messages);
      if (currentMessages.isNotEmpty) {
        final lastMsg = currentMessages.last;
        currentMessages[currentMessages.length - 1] = KnowledgeChatMessage(
          sender: lastMsg.sender,
          text: '抱歉，回答生成失败：$e',
        );
        _emit(_state.copyWith(
          messages: currentMessages,
          isWaitingForAnswer: false,
        ));
      } else {
        _emit(_state.copyWith(isWaitingForAnswer: false));
      }
    } finally {
      _currentSSESub = null;
    }
  }

  /// 从服务端加载会话的 QA 历史。
  Future<void> _loadQaHistory() async {
    _emit(_state.copyWith(isWaitingForAnswer: true));

    try {
      final resp = await _qaService.listQAs(_kbid, _chatId);
      final messages = <KnowledgeChatMessage>[];
      for (final dto in resp.data) {
        if (dto.questionContent.isNotEmpty) {
          messages.add(KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: dto.questionContent,
            attachments: dto.attachments
                .map((a) => ChatAttachment(
                      name: a.name,
                      ossKey: a.ossKey,
                      mimeType: a.mimeType,
                      presignedUrl: a.presignedUrl,
                    ))
                .toList(),
          ));
        }
        if (dto.answerContent != null && dto.answerContent!.isNotEmpty) {
          messages.add(KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: dto.answerContent!,
            citedSources:
                dto.citedSources.isNotEmpty ? dto.citedSources : null,
          ));
        }
      }

      _emit(_state.copyWith(
        messages: messages,
        isWaitingForAnswer: false,
      ));
    } catch (_) {
      _emit(_state.copyWith(isWaitingForAnswer: false));
    }
  }

  @override
  void dispose() {
    _cancelSSE();
    super.dispose();
  }
}
