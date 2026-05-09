enum KnowledgeChatSender { user, system }

class KnowledgeChatMessage {
  const KnowledgeChatMessage({
    required this.sender,
    required this.text,
    this.timestampLabel,
  });

  final KnowledgeChatSender sender;
  final String text;
  final String? timestampLabel;
}

class KnowledgeConversationPreview {
  const KnowledgeConversationPreview({
    required this.id,
    required this.title,
    required this.preview,
    required this.dateLabel,
    required this.messages,
  });

  final String id;
  final String title;
  final String preview;
  final String dateLabel;
  final List<KnowledgeChatMessage> messages;
}

class KnowledgeSourceItem {
  const KnowledgeSourceItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kindLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final String kindLabel;
}

class KnowledgeBaseLibrary {
  const KnowledgeBaseLibrary({
    required this.id,
    required this.title,
    required this.meta,
    required this.description,
    required this.sourceCount,
    required this.sources,
    required this.conversations,
  });

  final String id;
  final String title;
  final String meta;
  final String description;
  final int sourceCount;
  final List<KnowledgeSourceItem> sources;
  final List<KnowledgeConversationPreview> conversations;
}

const List<KnowledgeBaseLibrary> demoKnowledgeBaseLibraries = [
  KnowledgeBaseLibrary(
    id: 'kb-ai-product',
    title: 'AI 产品调研库',
    meta: '18 份资料 · 最近追问“竞品如何构建记忆层？”',
    description: '收纳市场报告、论文、视频摘要与竞品评测。',
    sourceCount: 18,
    sources: [
      KnowledgeSourceItem(
        id: 'ai-src-1',
        title: '2026 AI 产品市场观察.pdf',
        subtitle: '行业报告 · 26 页 · 最近更新于昨天',
        kindLabel: 'PDF',
      ),
      KnowledgeSourceItem(
        id: 'ai-src-2',
        title: '竞品记忆层拆解笔记.md',
        subtitle: '研究笔记 · 14 段摘要 · 最近更新于4月17日',
        kindLabel: '笔记',
      ),
      KnowledgeSourceItem(
        id: 'ai-src-3',
        title: 'NotebookLM 体验录屏.mp4',
        subtitle: '视频摘要 · 18分24秒 · 已完成转写',
        kindLabel: '视频',
      ),
      KnowledgeSourceItem(
        id: 'ai-src-4',
        title: 'RAG 架构论文精选.docx',
        subtitle: '论文整理 · 8 篇归档 · 已结构化切片',
        kindLabel: '文档',
      ),
      KnowledgeSourceItem(
        id: 'ai-src-5',
        title: '竞品能力矩阵.xlsx',
        subtitle: '表格资料 · 3 个维度对比 · 可继续问答',
        kindLabel: '表格',
      ),
    ],
    conversations: [
      KnowledgeConversationPreview(
        id: 'ai-product-conv-1',
        title: '请总结这组竞品在记忆层上的共性设计',
        preview: '已归纳 4 类记忆策略，并拆出了“短期上下文”与“长期知识积累”的差异。',
        dateLabel: '昨天',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: '请总结这组竞品在记忆层上的共性设计',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text:
                '我把资料里的共性设计归为 4 类：短期对话缓存、长期用户画像、任务上下文拼接和外部知识回填。若继续追问，我可以逐条映射到具体竞品。',
          ),
        ],
      ),
      KnowledgeConversationPreview(
        id: 'ai-product-conv-2',
        title: '把论文里的 RAG 架构差异整理成表格',
        preview: '已按检索层、重排层和记忆策略生成结构化表格。',
        dateLabel: '4月17日',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: '把论文里的 RAG 架构差异整理成表格',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '我已经把不同论文的检索增强架构整理成 3 列对照：索引方式、重排逻辑和记忆注入点。',
          ),
        ],
      ),
    ],
  ),
  KnowledgeBaseLibrary(
    id: 'kb-architecture',
    title: '架构设计知识库',
    meta: '9 份资料 · 2 个导图摘要',
    description: '将录屏、设计文档和技术评审沉淀为可问答资产。',
    sourceCount: 9,
    sources: [
      KnowledgeSourceItem(
        id: 'arch-src-1',
        title: '系统演进路线图.pdf',
        subtitle: '架构文档 · 12 页 · 最近更新于昨天',
        kindLabel: 'PDF',
      ),
      KnowledgeSourceItem(
        id: 'arch-src-2',
        title: '架构评审录屏.mp4',
        subtitle: '视频资料 · 09分48秒 · 已生成摘要',
        kindLabel: '视频',
      ),
      KnowledgeSourceItem(
        id: 'arch-src-3',
        title: '事件总线风险清单.md',
        subtitle: '评审结论 · 11 条待决事项 · 支持追问',
        kindLabel: '笔记',
      ),
      KnowledgeSourceItem(
        id: 'arch-src-4',
        title: '服务拆分依赖图.drawio',
        subtitle: '图表资料 · 2 张导图 · 已抽出关键节点',
        kindLabel: '图表',
      ),
      KnowledgeSourceItem(
        id: 'arch-src-5',
        title: '稳定性治理周报.docx',
        subtitle: '文档资料 · 5 期汇总 · 最近更新于4月16日',
        kindLabel: '文档',
      ),
    ],
    conversations: [
      KnowledgeConversationPreview(
        id: 'architecture-conv-1',
        title: '梳理服务拆分边界和后续演进路线',
        preview: '已结合评审录屏和架构文档生成阶段化拆分建议。',
        dateLabel: '昨天',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: '梳理服务拆分边界和后续演进路线',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '从当前资料来看，建议先以域模型稳定性和依赖方向为主线进行拆分，再逐步抽离基础能力服务。',
          ),
        ],
      ),
      KnowledgeConversationPreview(
        id: 'architecture-conv-2',
        title: '解释这次评审里提到的事件总线风险',
        preview: '已抽出评审意见中的关键风险和替代方案。',
        dateLabel: '4月17日',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: '解释这次评审里提到的事件总线风险',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '核心风险主要在可观测性、失败重试和事件语义漂移，我可以继续按评审原文逐条展开。',
          ),
        ],
      ),
    ],
  ),
  KnowledgeBaseLibrary(
    id: 'kb-requirements',
    title: '需求分析课程库',
    meta: '5 份资料 · 最近追问“核心用例描述维度指南？”',
    description: '将课程、案例和评审笔记整理成稳定的知识单元。',
    sourceCount: 5,
    sources: [
      KnowledgeSourceItem(
        id: 'req-src-1',
        title: '需求分析课程讲义.pdf',
        subtitle: '课程资料 · 32 页 · 已完成段落切片',
        kindLabel: 'PDF',
      ),
      KnowledgeSourceItem(
        id: 'req-src-2',
        title: '课堂案例整理.md',
        subtitle: '案例笔记 · 19 条观察 · 最近更新于昨天',
        kindLabel: '笔记',
      ),
      KnowledgeSourceItem(
        id: 'req-src-3',
        title: '课程录屏精华.mp4',
        subtitle: '视频资料 · 22分05秒 · 已生成摘要',
        kindLabel: '视频',
      ),
      KnowledgeSourceItem(
        id: 'req-src-4',
        title: '需求评审模板.docx',
        subtitle: '模板文档 · 适合团队内部复用',
        kindLabel: '文档',
      ),
      KnowledgeSourceItem(
        id: 'req-src-5',
        title: '检查项清单.xlsx',
        subtitle: '表格资料 · 会前核对用 · 可继续追问',
        kindLabel: '表格',
      ),
    ],
    conversations: [
      KnowledgeConversationPreview(
        id: 'requirements-conv-1',
        title: '核心用例描述要覆盖哪些维度？',
        preview: '已按目标、参与者、边界、例外流和验收标准整理为清单。',
        dateLabel: '昨天',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: '核心用例描述要覆盖哪些维度？',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '建议至少覆盖目标、触发条件、参与者、主流程、例外流和验收标准 6 个维度，这样后续讨论和评审都更稳定。',
          ),
        ],
      ),
      KnowledgeConversationPreview(
        id: 'requirements-conv-2',
        title: '帮我从课程里提炼需求评审的检查项',
        preview: '已整理成一份适合会前快速过表的评审清单。',
        dateLabel: '4月17日',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: '帮我从课程里提炼需求评审的检查项',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '我已经整理出目标一致性、范围边界、优先级、依赖项和验收标准 5 个核心检查项。',
          ),
        ],
      ),
      KnowledgeConversationPreview(
        id: 'requirements-conv-3',
        title: '把课堂案例改写成团队内部模板',
        preview: '已生成一版更适合内部协作的模板草案。',
        dateLabel: '4月16日',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: '把课堂案例改写成团队内部模板',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '我已经把课堂案例调整成适合团队内部复用的模板结构，后续可以继续按场景精简或扩展。',
          ),
        ],
      ),
      KnowledgeConversationPreview(
        id: 'requirements-conv-4',
        title: '课程里如何定义“需求完成”？',
        preview: '已抽出定义条件和验收视角的关键句。',
        dateLabel: '4月16日',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: '课程里如何定义“需求完成”？',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '资料里的定义强调“用户目标达成 + 验收标准明确 + 依赖方一致理解”，而不是单纯写完文档。',
          ),
        ],
      ),
    ],
  ),
  KnowledgeBaseLibrary(
    id: 'kb-cs50x-2025',
    title: 'CS50x-2025课程库',
    meta: '4 个视频来源 · 最近追问“Minimax 算法为什么能保证不败？”',
    description: '收集课程视频，支持按讲次回看知识点与历史问答。',
    sourceCount: 4,
    sources: [
      KnowledgeSourceItem(
        id: 'cs50x-src-1',
        title: 'CS50x-2025-Artificial-Intelligence.mp4',
        subtitle: '视频资料 · AI 课程讲解 · 56:00',
        kindLabel: '视频',
      ),
      KnowledgeSourceItem(
        id: 'cs50x-src-2',
        title: 'CS50x 2025 - Lecture 1 - C.mp4',
        subtitle: '视频资料 · Week 1 · 2:34:31',
        kindLabel: '视频',
      ),
      KnowledgeSourceItem(
        id: 'cs50x-src-3',
        title: 'CS50x 2025 - Lecture 2 - Arrays.mp4',
        subtitle: '视频资料 · Week 2 · 2:10:18',
        kindLabel: '视频',
      ),
      KnowledgeSourceItem(
        id: 'cs50x-src-4',
        title: 'CS50x 2025 - Lecture 3 - Algorithms.mp4',
        subtitle: '视频资料 · Week 3 · 2:06:35',
        kindLabel: '视频',
      ),
    ],
    conversations: [
      KnowledgeConversationPreview(
        id: 'cs50x-conv-1',
        title: 'Minimax 算法为什么能保证最差情况下不输？',
        preview: '已结合 AI 课程视频解释极大极小值回推逻辑，并说明“不败”来自最优对抗假设。',
        dateLabel: '今天',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: 'Minimax 算法为什么能保证最差情况下不输？',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '''核心原因是：算法会先把所有可达终局映射成分数，再假设对手总会做出**对你最不利**的选择。

### 推理过程
- 对当前玩家来说，每一步都不是看“最好结果”，而是看这一步在**最坏回应**下还能拿到什么结果。
- 然后它会从这些“最坏结果”里，再挑出相对**最优**的那一步。

### 结论
这样就能主动避开那些一定会导致失败的走法。在井字棋这类可以穷举状态空间的博弈里，Minimax 对应的效果就是：**最差也能逼平，所以不会输。**''',
          ),
        ],
      ),
      KnowledgeConversationPreview(
        id: 'cs50x-conv-2',
        title: 'Lecture 2 里数组和链表的取舍该怎么理解？',
        preview: '已从访问效率、插入删除成本和内存连续性三方面对比两种结构。',
        dateLabel: '昨天',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: 'Lecture 2 里数组和链表的取舍该怎么理解？',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '这节课的核心取舍是“读快写慢”和“写灵活读跳转”。数组依赖连续内存，随机访问快，但中间插入或删除需要整体移动；链表插入删除更灵活，不过访问第 n 个元素必须顺着指针逐步走。课程里想强调的是，数据结构选择取决于操作模式，而不是谁绝对更先进。',
          ),
        ],
      ),
      KnowledgeConversationPreview(
        id: 'cs50x-conv-3',
        title: 'Lecture 3 的排序算法部分适合怎么复习？',
        preview: '已按“思路、复杂度、适用场景”整理为复习顺序，并区分选择排序与归并排序。',
        dateLabel: '5月2日',
        messages: [
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.user,
            text: 'Lecture 3 的排序算法部分适合怎么复习？',
          ),
          KnowledgeChatMessage(
            sender: KnowledgeChatSender.system,
            text: '可以按三步复习：先记住每种排序如何移动元素，再对照最好/平均/最坏时间复杂度，最后补上适用场景。比如选择排序易理解但总要反复扫描，归并排序利用分治把复杂度稳定在 O(n log n)，更适合作为“为什么算法设计会改变规模成本”的代表例子。',
          ),
        ],
      ),
    ],
  ),
];
