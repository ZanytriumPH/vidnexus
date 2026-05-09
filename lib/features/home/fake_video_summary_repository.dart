import 'domain/video_summary_domain_models.dart';
import 'fake_video_summary_processing_event_source.dart';
import 'stream_backed_video_summary_repository.dart';
import 'video_summary_models.dart';

class FakeVideoSummaryRepository extends StreamBackedVideoSummaryRepository {
  const FakeVideoSummaryRepository();

  @override
  VideoAssetInfo getVideoAsset() {
    return const VideoAssetInfo(
      title: 'CS50x-2025-Artificial-Intelligence.mp4',
      durationLabel: '56m 00s',
      sourceLabel: 'CS50x-2025',
      fileName: 'CS50x-2025-Artificial-Intelligence.mp4',
    );
  }

  @override
  FakeVideoSummaryProcessingEventSource createProcessingEventSource() {
    return FakeVideoSummaryProcessingEventSource();
  }

  @override
  Future<VideoSummaryDraftData> fetchDraftResult() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return const VideoSummaryDraftData(
      paragraphs: [
        '''这段视频（CS50x 关于人工智能的讲座）在 **[28:15]** 左右引入了 **Minimax 算法**。以下是视频中关于该算法的核心知识点总结：

### 算法核心思想与命名
* Minimax 算法常用于计算机博弈（如井字棋 Tic-Tac-Toe）。其核心在于两名玩家的目标截然相反：一方致力于**最大化 (Maximize)** 得分，另一方致力于**最小化 (Minimize)** 得分。


### 状态量化与评分系统：
* 为了让计算机进行数学推理，算法为每种游戏结果设定了具体的数值。视频中给出的设定是：如果是 X 赢，棋盘分数为 **1**；如果是 O 赢，分数为 **-1**；如果是平局，分数为 **0**。
* 因此，玩家 X 的目标是选择能让最终分数趋近于 1 的步骤（最大化），而玩家 O 的目标是选择能让最终分数趋近于 -1 的步骤（最小化）。


### 决策树与逻辑推演 (Decision Tree)
* 在轮到某一方走棋时，计算机会在脑海中向下推演所有可能的“未来棋盘状态”。
* 计算机通过假设对手也会采取最优策略，一路推演到游戏结束，从而反推出当前每一步的“真实价值”。例如，玩家 O 会在多个选项中，比较不同走法最终导向的棋盘分数，并无情地选择那个分数最小（如导向 0 或 -1）的分支。


### 算法的优势：
* 使用 Minimax 算法虽然不能保证你永远获胜（取决于先后手和对手策略），但它能在逻辑上**保证你永远不会输**（最差也能逼平对手）。


### 指数级增长的算力瓶颈：
* **状态空间爆炸**：随着剩余步数的增加，决策树的规模会呈指数级增长。
* **适用场景限制**：对于井字棋，总共只有 255,000 种可能的游戏路径，现代计算机可以轻松遍历。但对于更复杂的棋类，例如国际象棋（仅前4回合就有 850 亿种可能）或围棋（266 亿亿种可能），纯粹的 Minimax 算法由于没有足够的内存和时间来计算所有的决策树，就会变得不可行，这也引出了后续对机器学习 (Machine Learning) 的需求。'''
      ],
    );
  }

  @override
  Future<VideoSummaryFinalResultData> generateFinalSummary({
    required String guidance,
    required List<String> draftParagraphs,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    return VideoSummaryFinalResultData(
      body:
          '''这段视频（CS50x 关于人工智能的讲座）在 **[28:15]** 左右引入了 **Minimax 算法**。以下是视频中关于该算法的核心知识点总结：

### 算法核心思想与命名
* Minimax 算法常用于计算机博弈（如井字棋 Tic-Tac-Toe）。其核心在于两名玩家的目标截然相反：一方致力于**最大化 (Maximize)** 得分，另一方致力于**最小化 (Minimize)** 得分。


### 状态量化与评分系统：
* 为了让计算机进行数学推理，算法为每种游戏结果设定了具体的数值。视频中给出的设定是：如果是 X 赢，棋盘分数为 **1**；如果是 O 赢，分数为 **-1**；如果是平局，分数为 **0**。
* 因此，玩家 X 的目标是选择能让最终分数趋近于 1 的步骤（最大化），而玩家 O 的目标是选择能让最终分数趋近于 -1 的步骤（最小化）。


### 决策树与逻辑推演 (Decision Tree)
* 在轮到某一方走棋时，计算机会在脑海中向下推演所有可能的“未来棋盘状态”。
* 计算机通过假设对手也会采取最优策略，一路推演到游戏结束，从而反推出当前每一步的“真实价值”。例如，玩家 O 会在多个选项中，比较不同走法最终导向的棋盘分数，并无情地选择那个分数最小（如导向 0 或 -1）的分支。


### 算法的优势：
* 使用 Minimax 算法虽然不能保证你永远获胜（取决于先后手和对手策略），但它能在逻辑上**保证你永远不会输**（最差也能逼平对手）。


### 指数级增长的算力瓶颈：
* **状态空间爆炸**：随着剩余步数的增加，决策树的规模会呈指数级增长。
* **适用场景限制**：对于井字棋，总共只有 255,000 种可能的游戏路径，现代计算机可以轻松遍历。但对于更复杂的棋类，例如国际象棋（仅前4回合就有 850 亿种可能）或围棋（266 亿亿种可能），纯粹的 Minimax 算法由于没有足够的内存和时间来计算所有的决策树，就会变得不可行，这也引出了后续对机器学习 (Machine Learning) 的需求。''',
      references: const [
        VideoSummaryReferenceRange(
          startSeconds: 12 * 60 + 30,
          endSeconds: 14 * 60,
          topic: '核心机制与工作流',
        ),
        VideoSummaryReferenceRange(
          startSeconds: 8 * 60 + 20,
          endSeconds: 10 * 60 + 40,
          topic: '工具调用与循环',
        ),
      ],
    );
  }

  @override
  Future<VideoSummaryChatReplyData> sendSummaryChatMessage(String message) async {
    await Future<void>.delayed(const Duration(milliseconds: 360));
    return const VideoSummaryChatReplyData(
      text: '''在这一段落中，主讲人通过引入井字棋（Tic-Tac-Toe）的具体残局推演，主要是为了达到以下几个循序渐进的教学目的：

* **将人类游戏转化为计算机可理解的“数学模型”：**
主讲人首先为游戏结果赋予了具体的数值（X赢设为1，O赢设为-1，平局设为0）。这样做的目的是向观众直观展示，计算机是如何将一个感性的胜负游戏，抽象为一个纯粹的“最大化（求1）”与“最小化（求-1）”的数学优化问题 。
* **直观演示算法的“状态评估”与“反向推演”逻辑：**
为了让听众理解 Minimax 是如何工作的，主讲人巧妙地设置了一个“只剩两处落子点”的简单残局 **。他带领观众代入玩家 O 的视角，演示了算法的思考过程：如果不走底部中间，对手下一步就会赢（导致这步棋的潜在积分为 1）；如果走底部中间，最终会平局（导致这步棋的潜在积分为 0）**。这清晰地说明了算法是如何通过穷举未来的结果，来给当前的各个选项“打分”并做出决策的 。
* **证明绝对理性的威力（建立不败策略）：**
通过这段严密的推导，主讲人向观众证明了一个结论：只要计算机能够穷举并遵循 Minimax 这种寻找最优解的逻辑路径，它就能完美避开所有导致输掉游戏（分数为1）的分支。这意味着该算法虽然不能保证把把必胜，但能在逻辑上保证“永远不会输” 。
* **为引出传统算法的“算力瓶颈”做极佳的铺垫：**
在成功演示了两步推演后，主讲人立刻话锋一转，指出即使是简单的井字棋，如果退回到剩三步、剩四步，决策树（Decision Tree）的分支就会成倍翻番，呈现**指数级增长** 。这个井字棋的例子让观众切身体会到了穷举法的繁琐，从而为紧接着讲授“为什么应对国际象棋和围棋时，必须抛弃这种确定性穷举，转而使用机器学习（Machine Learning）”做好了极为自然的过渡。''',
      reference: VideoSummaryReferenceRange(
        startSeconds: 12 * 60 + 30,
        endSeconds: 14 * 60,
        topic: '核心机制与工作流',
      ),
    );
  }
}
