import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../services/global_qa_service.dart';
import '../../../services/sse/sse_models.dart';
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

/// 管理知识库内单个会话的 QA 请求与轮询逻辑。
///
/// 由 [ChangeNotifier] 驱动 UI 重建；Screen 通过 [addListener] / [AnimatedBuilder]
/// 或手动在回调中 [setState] 读取最新状态。
class KnowledgeBaseChatController extends ChangeNotifier {
  KnowledgeBaseChatController({
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

  KnowledgeBaseChatState _state;
  KnowledgeBaseChatState get state => _state;

  List<KnowledgeChatMessage> get messages => _state.messages;
  bool get isWaitingForAnswer => _state.isWaitingForAnswer;

  void _emit(KnowledgeBaseChatState newState) {
    _state = newState;
    notifyListeners();
  }

  /// 在 initState 时调用，判断当前会话的初始动作。
  ///
  /// - 临时 chatId（creating- / new- 前缀）：跳过
  /// - messages 为空：加载历史 QA
  /// - 最后一条是用户消息：自动发起 QA
  void triggerInitialQA() {
    if (_chatId.startsWith('creating-') || _chatId.startsWith('new-')) {
      return;
    }

    if (_state.messages.isEmpty) {
      _loadQaHistory();
      return;
    }

    final lastMessage = _state.messages.last;
    if (lastMessage.sender == KnowledgeChatSender.user) {
      final userMessages = _state.messages
          .where((m) => m.sender == KnowledgeChatSender.user)
          .toList();
      _emit(_state.copyWith(messages: userMessages));
      _sendChatMessage(lastMessage.text);
    }
  }

  /// 用户发送新消息。
  void sendMessage(String text) {
    if (text.isEmpty || _state.isWaitingForAnswer) return;

    _emit(_state.copyWith(
      messages: [
        ..._state.messages,
        KnowledgeChatMessage(sender: KnowledgeChatSender.user, text: text),
      ],
    ));

    _sendChatMessage(text);
  }

  /// 发起真实 QA 请求并轮询等待回答。
  Future<void> _sendChatMessage(String text) async {
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

    final sseStream = _qaService.createQAStream(
      kbid: _kbid,
      chatId: _chatId,
      questionContent: text,
    );

    final answerBuffer = StringBuffer();

    try {
      await for (final event in sseStream) {
        if (event.type == SSEEventType.delta) {
          final delta = event.parseData<SSEDeltaData>(SSEDeltaData.fromJson);
          if (delta != null) {
            answerBuffer.write(delta.chunk);
            final currentMessages = List<KnowledgeChatMessage>.from(_state.messages);
            if (currentMessages.isNotEmpty) {
              final lastMsg = currentMessages.last;
              currentMessages[currentMessages.length - 1] = KnowledgeChatMessage(
                sender: lastMsg.sender,
                text: answerBuffer.toString(),
              );
              _emit(_state.copyWith(messages: currentMessages));
            }
          }
        } else if (event.type == SSEEventType.done) {
          final done = event.parseData<GlobalQADoneData>(GlobalQADoneData.fromJson);
          if (done?.answerContent != null && done!.answerContent!.isNotEmpty) {
            final currentMessages = List<KnowledgeChatMessage>.from(_state.messages);
            if (currentMessages.isNotEmpty) {
              final lastMsg = currentMessages.last;
              currentMessages[currentMessages.length - 1] = KnowledgeChatMessage(
                sender: lastMsg.sender,
                text: done.answerContent!,
              );
              _emit(_state.copyWith(
                messages: currentMessages,
                isWaitingForAnswer: false,
              ));
            }
            return;
          }
        } else if (event.type == SSEEventType.error) {
          throw Exception(event.data?.toString() ?? 'SSE stream error');
        }
      }
      _emit(_state.copyWith(isWaitingForAnswer: false));
    } catch (e) {
      final currentMessages = List<KnowledgeChatMessage>.from(_state.messages);
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
          ));
        }
        if (dto.answerContent != null && dto.answerContent!.isNotEmpty) {
          messages.add(KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: dto.answerContent!,
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
}
