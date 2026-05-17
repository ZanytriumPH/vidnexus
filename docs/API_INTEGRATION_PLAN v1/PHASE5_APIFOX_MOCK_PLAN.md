# Phase 5 Apifox Mock 方案：Chat & QA 接口

> **创建日期**: 2026-05-16 | **对应计划**: `docs/plan/API_INTEGRATION_PLAN.md` Phase 5 | **前置**: Phase 1-4 Apifox Mock 已就绪

---

## 0. 前置约定

### 0.1 全局 Mock 规则

| 规则项 | 配置 |
|--------|------|
| 响应延迟 | 200-500ms（`@integer(200, 500)` ms 模拟真实网络） |
| 鉴权 Header | Mock 不校验 `Authorization`，但建议在"期望"中配置 `Bearer {{token}}` 占位 |
| Content-Type | `application/json; charset=utf-8` |
| 基础 URL | `/api/v1` |

### 0.2 公共 Mock 变量（Apifox 脚本 → 环境变量）

在 Apifox "前置脚本"中设置以下变量，确保跨接口 ID 一致：

```javascript
// 前置脚本：初始化 Phase 5 Mock 公共 ID
pm.environment.set("mock_kbid", "kb_mock_001");
pm.environment.set("mock_chat_id", "chat_mock_001");
pm.environment.set("mock_task_id", "task_mock_001");
pm.environment.set("mock_video_id", "vid_mock_001");
pm.environment.set("mock_qa_id", "qa_mock_001");
pm.environment.set("mock_gqa_id", "gqa_mock_001");

// QA 轮询计数器：创建 QA 后重置，每次 GET 递增
if (pm.info.requestName === "POST 创建 QA") {
    pm.environment.set("qa_poll_count", 0);
}
```

### 0.3 公共响应信封

所有 Phase 5 接口使用统一信封（同 Phase 1-4）：

```json
// 单对象
{ "status": "success", "data": { ... }, "meta": { "request_id": "req-{{$guid}}", "timestamp": "{{$isoTimestamp}}" } }

// 列表
{ "status": "success", "data": [ ... ], "pagination": { ... }, "meta": { ... } }

// 错误
{ "detail": "错误描述" }
```

---

## 1. Video QA（5 端点）— `/api/v1/tasks/{task_id}/qa`

> **依赖**: 必须先有 Task（Phase 2 Mock 已创建 `task_mock_001`）

### 1.1 POST `/api/v1/tasks/{task_id}/qa` — 创建追问

**Mock 场景 1: 正常创建（默认）**

请求体校验：
- `task_id` 必须存在且与路径一致
- `question_content` 长度 1-2000

```json
{
  "status": "success",
  "data": {
    "qa_id": "qa_mock_001",
    "task_id": "task_mock_001",
    "start_time": null,
    "end_time": null,
    "question_content": "{{request.body.question_content}}",
    "answer_content": null,
    "attachments": [],
    "question_time": "{{$isoTimestamp}}"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

**Mock 场景 2: 带时间戳追问**

当 `start_time` 和 `end_time` 非空时，回显时间区间：

```json
{
  "status": "success",
  "data": {
    "qa_id": "qa_mock_002",
    "task_id": "task_mock_001",
    "start_time": "{{request.body.start_time}}",
    "end_time": "{{request.body.end_time}}",
    "question_content": "{{request.body.question_content}}",
    "answer_content": null,
    "attachments": [],
    "question_time": "{{$isoTimestamp}}"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

**Mock 场景 3: task_id 不匹配（400）**

```json
{
  "detail": "path task_id 'task_mock_001' does not match body task_id 'task_bad'"
}
```

> Apifox 期望条件：`请求体 task_id != 路径 task_id`

**关键行为**: `answer_content` 始终为 `null`（异步生成，需通过 GET 轮询获取）

---

### 1.2 GET `/api/v1/tasks/{task_id}/qa` — 分页列表

**Mock 数据（2 条）**:

```json
{
  "status": "success",
  "data": [
    {
      "qa_id": "qa_mock_002",
      "task_id": "task_mock_001",
      "start_time": "00:05:00",
      "end_time": "00:08:30",
      "question_content": "这一段在讲什么技术原理？",
      "answer_content": "这段视频介绍了 Transformer 架构中的自注意力机制（Self-Attention），核心思想是通过 Query、Key、Value 三个矩阵计算序列中每个 token 对其他 token 的注意力权重。具体来说：（1）输入序列先经过线性变换得到 Q、K、V；（2）通过 Q·K^T 计算注意力分数；（3）Softmax 归一化后加权求和 V。这种机制使得模型能够并行处理序列，同时捕捉长距离依赖。",
      "attachments": [],
      "question_time": "2026-05-15T14:30:00Z"
    },
    {
      "qa_id": "qa_mock_001",
      "task_id": "task_mock_001",
      "start_time": null,
      "end_time": null,
      "question_content": "总结一下这个视频的主要内容",
      "answer_content": "这个视频主要涵盖三个方面：（1）大语言模型的训练流程，包括预训练、SFT 监督微调、RLHF 人类反馈强化学习三个阶段；（2）模型评估方法，重点介绍了 MMLU、HumanEval 等基准测试；（3）实际部署中的推理优化策略，如量化（INT8/INT4）、KV Cache、Continuous Batching 等。整体时长约 45 分钟，适合有一定深度学习基础的开发者观看。",
      "attachments": [],
      "question_time": "2026-05-15T14:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 2,
    "has_next": false,
    "next_cursor": null
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

**空列表场景（期望：page=99）**:

```json
{
  "status": "success",
  "data": [],
  "pagination": {
    "page": 99,
    "page_size": 20,
    "total": 2,
    "has_next": false,
    "next_cursor": null
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

---

### 1.3 GET `/api/v1/tasks/{task_id}/qa/{qa_id}` — 获取单条（轮询关键接口）

**这是 Video QA 链路的核心——QAPoller 轮询此接口直到 `answer_content` 非空。**

**Apifox 高级 Mock 配置（多期望，按轮询次数切换）**:

| 期望 | 触发条件 | `answer_content` | 说明 |
|------|---------|-----------------|------|
| 期望1 | `X-Poll-Count` = 1 | `null` | 第1次轮询（~2s）：还在生成 |
| 期望2 | `X-Poll-Count` = 2 | `null` | 第2次轮询（~4s）：还在生成 |
| 期望3 | `X-Poll-Count` ≥ 3 | `"基于您对视频的追问，AI 分析如下：\n\n1. **核心技术点**：该视频重点讲解了 RAG（检索增强生成）的三大组件——Embedding 模型、向量数据库、上下文组装策略。\n\n2. **关键数据**：实验表明，引入 RAG 后模型在知识密集型任务上的准确率从 62% 提升至 89%。\n\n3. **实践建议**：建议采用 Hybrid Search（向量检索 + BM25 关键词检索）以获得最佳召回效果。\n\n需要进一步了解哪个方面？"` | 第3次轮询（~6s）：回答就绪 |

**期望3 完整响应**:

```json
{
  "status": "success",
  "data": {
    "qa_id": "qa_mock_001",
    "task_id": "task_mock_001",
    "start_time": null,
    "end_time": null,
    "question_content": "总结一下这个视频的主要内容",
    "answer_content": "基于您对视频的追问，AI 分析如下：\n\n1. **核心技术点**：该视频重点讲解了 RAG（检索增强生成）的三大组件——Embedding 模型、向量数据库、上下文组装策略。\n\n2. **关键数据**：实验表明，引入 RAG 后模型在知识密集型任务上的准确率从 62% 提升至 89%。\n\n3. **实践建议**：建议采用 Hybrid Search（向量检索 + BM25 关键词检索）以获得最佳召回效果。\n\n需要进一步了解哪个方面？",
    "attachments": [],
    "question_time": "2026-05-15T14:00:00Z"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

> **注意**: Flutter 端 `QAPoller` 会发送 `X-Poll-Count` header（从 1 开始递增），Apifox 根据该 header 值匹配对应期望。若第 3 次仍未返回答案，第 4 次及以后都走期望3。超时 60s 约等于 30 次轮询。

---

### 1.4 PATCH `/api/v1/tasks/{task_id}/qa/{qa_id}` — 触发重生成

```json
{
  "status": "success",
  "data": {
    "qa_id": "qa_mock_001",
    "task_id": "task_mock_001",
    "start_time": null,
    "end_time": null,
    "question_content": "总结一下这个视频的主要内容",
    "answer_content": null,
    "attachments": [],
    "question_time": "2026-05-15T14:00:00Z"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

> **语义**: PATCH `regenerate=true` 触发重生成意图，`answer_content` 重新置为 `null`。前端需重新走 `createQA → poll GET` 流程。

---

### 1.5 DELETE `/api/v1/tasks/{task_id}/qa/{qa_id}` — 删除追问

```json
{
  "status": "success",
  "data": {
    "qa_id": "qa_mock_001"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

---

## 2. Global Chat（5 端点）— `/api/v1/kbs/{kbid}/chats`

> **依赖**: 必须先有 KnowledgeBase（Phase 2 Mock 已创建 `kb_mock_001`）

### 2.1 POST `/api/v1/kbs/{kbid}/chats` — 创建会话

**Mock 场景 1: 正常创建（默认）**

```json
{
  "status": "success",
  "data": {
    "chat_id": "chat_mock_001",
    "kbid": "kb_mock_001",
    "chat_title": "{{request.body.chat_title}}",
    "created_at": "{{$isoTimestamp}}"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

**Mock 场景 2: kbid 不匹配（400）**

```json
{
  "detail": "path kbid 'kb_mock_001' does not match body kbid 'kb_bad'"
}
```

> Apifox 期望条件：`请求体 kbid != 路径 kbid`

---

### 2.2 GET `/api/v1/kbs/{kbid}/chats` — 会话列表

**Mock 数据（3 条）**:

```json
{
  "status": "success",
  "data": [
    {
      "chat_id": "chat_mock_003",
      "kbid": "kb_mock_001",
      "chat_title": "产品需求讨论",
      "created_at": "2026-05-16T09:00:00Z"
    },
    {
      "chat_id": "chat_mock_002",
      "kbid": "kb_mock_001",
      "chat_title": "技术方案评审",
      "created_at": "2026-05-15T16:30:00Z"
    },
    {
      "chat_id": "chat_mock_001",
      "kbid": "kb_mock_001",
      "chat_title": "研发周会问答",
      "created_at": "2026-05-15T12:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 3,
    "has_next": false,
    "next_cursor": null
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

**空列表场景（期望：新知识库无会话）**

```json
{
  "status": "success",
  "data": [],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 0,
    "has_next": false,
    "next_cursor": null
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

> Apifox 期望条件：`路径 kbid = "kb_empty"`（用一个不存在的 kbid 模拟空列表）

---

### 2.3 GET `/api/v1/kbs/{kbid}/chats/{chat_id}` — 会话详情

```json
{
  "status": "success",
  "data": {
    "chat_id": "chat_mock_001",
    "kbid": "kb_mock_001",
    "chat_title": "研发周会问答",
    "created_at": "2026-05-15T12:00:00Z"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

---

### 2.4 PATCH `/api/v1/kbs/{kbid}/chats/{chat_id}` — 重命名会话

```json
{
  "status": "success",
  "data": {
    "chat_id": "chat_mock_001",
    "kbid": "kb_mock_001",
    "chat_title": "{{request.body.chat_title}}",
    "created_at": "2026-05-15T12:00:00Z"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

> `chat_title` 直接回显请求体中的新标题。

---

### 2.5 DELETE `/api/v1/kbs/{kbid}/chats/{chat_id}` — 删除会话

```json
{
  "status": "success",
  "data": {
    "chat_id": "chat_mock_001"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

> **语义**: 后端级联删除该会话下所有 QA，Mock 不体现级联效果。

---

## 3. Global QA（5 端点）— `/api/v1/kbs/{kbid}/chats/{chat_id}/qa`

> **依赖**: 必须先有 Chat（即上文创建的 `chat_mock_001`）

### 3.1 POST `/api/v1/kbs/{kbid}/chats/{chat_id}/qa` — 创建全局问答

```json
{
  "status": "success",
  "data": {
    "qa_id": "gqa_mock_001",
    "chat_id": "chat_mock_001",
    "question_content": "{{request.body.question_content}}",
    "answer_content": null,
    "attachments": [],
    "cited_sources": [],
    "question_time": "{{$isoTimestamp}}"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

**关键行为**:
- `answer_content` 初始为 `null`（异步生成，与 Video QA 一致）
- `cited_sources` 为空数组（回答生成后才会填充引用）
- `attachments` 回显请求体中的附件（如有）

---

### 3.2 GET `/api/v1/kbs/{kbid}/chats/{chat_id}/qa` — QA 列表

**Mock 数据（3 条，含 cited_sources 的完整回答）**:

```json
{
  "status": "success",
  "data": [
    {
      "qa_id": "gqa_mock_003",
      "chat_id": "chat_mock_001",
      "question_content": "这三个视频中提到的架构方案哪个最适合初创团队？",
      "answer_content": "综合三个视频的讨论，对于初创团队我推荐**方案 B（微服务轻量化变体）**：\n\n| 维度 | 方案A（单体） | 方案B（轻量微服务） | 方案C（全量微服务） |\n|------|-------------|-------------------|-------------------|\n| 开发效率 | ⭐⭐⭐ | ⭐⭐ | ⭐ |\n| 运维成本 | ⭐⭐⭐ | ⭐⭐ | ⭐ |\n| 扩展性 | ⭐ | ⭐⭐ | ⭐⭐⭐ |\n| 团队门槛 | 低 | 中 | 高 |\n\n方案B 通过 API Gateway + 2-3 个核心服务的方式，在保持一定扩展性的同时不会过度增加运维负担，非常适合 5-15 人的初创团队。",
      "attachments": [],
      "cited_sources": [
        {
          "video_id": "vid_mock_001",
          "task_id": "task_mock_001",
          "time_range": "00:12:30-00:14:00",
          "quote": "对于小团队来说，微服务的运维开销往往被低估了",
          "score": 0.91
        },
        {
          "video_id": "vid_mock_002",
          "task_id": "task_mock_002",
          "time_range": "00:08:00-00:09:30",
          "quote": "我们推荐采用渐进的微服务化策略",
          "score": 0.85
        }
      ],
      "question_time": "2026-05-16T10:00:00Z"
    },
    {
      "qa_id": "gqa_mock_002",
      "chat_id": "chat_mock_001",
      "question_content": "这两个视频对 GPU 选型有什么不同建议？",
      "answer_content": "两个视频在 GPU 选型上存在有趣的对比：\n\n**视频A（技术架构）**建议优先考虑 NVIDIA A100，理由是：\n- 显存 80GB，适合大模型训练\n- 支持 MIG（多实例 GPU）技术\n- 在 Transformer 训练中比 V100 快 3-6 倍\n\n**视频B（成本优化）**则推荐消费级 RTX 4090，因为：\n- 单卡价格仅为 A100 的 1/10\n- 24GB 显存对 7B 模型微调足够\n- 性价比在推理场景中远超企业卡\n\n综合建议：训练用 A100，推理/微调用 RTX 4090。",
      "attachments": [],
      "cited_sources": [
        {
          "video_id": "vid_mock_001",
          "task_id": "task_mock_001",
          "time_range": "00:22:00-00:25:00",
          "quote": "A100 在大规模模型训练中仍然是首选",
          "score": 0.93
        },
        {
          "video_id": "vid_mock_002",
          "task_id": "task_mock_002",
          "time_range": "00:15:00-00:17:30",
          "quote": "RTX 4090 的性价比让我们重新思考 GPU 选型策略",
          "score": 0.88
        }
      ],
      "question_time": "2026-05-15T18:00:00Z"
    },
    {
      "qa_id": "gqa_mock_001",
      "chat_id": "chat_mock_001",
      "question_content": "请对比两个视频中的架构差异",
      "answer_content": "通过对比两个视频，我发现以下关键架构差异：\n\n1. **数据流方向**\n   - 视频A：采用管道式（Pipeline）架构，数据单向流动\n   - 视频B：采用事件驱动（Event-Driven）架构，组件通过消息队列解耦\n\n2. **扩展策略**\n   - 视频A：垂直扩展为主，通过增加单节点资源提升性能\n   - 视频B：水平扩展为主，通过增加服务实例数量应对负载\n\n3. **一致性保证**\n   - 视频A：强一致性，适合金融交易等场景\n   - 视频B：最终一致性，更适合内容分发等场景\n\n总结：没有银弹，需根据业务场景选择合适的架构范式。",
      "attachments": [],
      "cited_sources": [
        {
          "video_id": "vid_mock_001",
          "task_id": "task_mock_001",
          "time_range": "00:05:00-00:07:00",
          "quote": "管道架构的核心优势在于数据处理的确定性",
          "score": 0.92
        },
        {
          "video_id": "vid_mock_002",
          "task_id": "task_mock_002",
          "time_range": "00:03:00-00:05:00",
          "quote": "事件驱动让我们能够灵活地添加新的消费者",
          "score": 0.89
        }
      ],
      "question_time": "2026-05-15T14:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 3,
    "has_next": false,
    "next_cursor": null
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

---

### 3.3 GET `/api/v1/kbs/{kbid}/chats/{chat_id}/qa/{qa_id}` — 获取单条（轮询接口）

**与 Video QA 1.3 相同模式——多期望轮询**:

| 期望 | `X-Poll-Count` | `answer_content` | `cited_sources` |
|------|---------------|-----------------|-----------------|
| 期望1 | 1 | `null` | `[]` |
| 期望2 | 2 | `null` | `[]` |
| 期望3 | ≥ 3 | 完整回答文本 | 2 条引用 |

**期望3 完整响应**:

```json
{
  "status": "success",
  "data": {
    "qa_id": "gqa_mock_001",
    "chat_id": "chat_mock_001",
    "question_content": "请对比两个视频中的架构差异",
    "answer_content": "通过对比两个视频，我发现以下关键架构差异：\n\n1. **数据流方向**\n   - 视频A：采用管道式（Pipeline）架构，数据单向流动\n   - 视频B：采用事件驱动（Event-Driven）架构，组件通过消息队列解耦\n\n2. **扩展策略**\n   - 视频A：垂直扩展为主\n   - 视频B：水平扩展为主\n\n3. **一致性保证**\n   - 视频A：强一致性\n   - 视频B：最终一致性",
    "attachments": [],
    "cited_sources": [
      {
        "video_id": "vid_mock_001",
        "task_id": "task_mock_001",
        "time_range": "00:05:00-00:07:00",
        "quote": "管道架构的核心优势在于数据处理的确定性",
        "score": 0.92
      },
      {
        "video_id": "vid_mock_002",
        "task_id": "task_mock_002",
        "time_range": "00:03:00-00:05:00",
        "quote": "事件驱动让我们能够灵活地添加新的消费者",
        "score": 0.89
      }
    ],
    "question_time": "2026-05-15T14:00:00Z"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

---

### 3.4 PATCH `/api/v1/kbs/{kbid}/chats/{chat_id}/qa/{qa_id}` — 触发重生成

```json
{
  "status": "success",
  "data": {
    "qa_id": "gqa_mock_001",
    "chat_id": "chat_mock_001",
    "question_content": "请对比两个视频中的架构差异",
    "answer_content": null,
    "attachments": [],
    "cited_sources": [],
    "question_time": "2026-05-15T14:00:00Z"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

> 重生成后 `answer_content` 清空、`cited_sources` 清空，前端轮询重新等待。

---

### 3.5 DELETE `/api/v1/kbs/{kbid}/chats/{chat_id}/qa/{qa_id}` — 删除问答

```json
{
  "status": "success",
  "data": {
    "qa_id": "gqa_mock_001"
  },
  "meta": {
    "request_id": "req-{{$guid}}",
    "timestamp": "{{$isoTimestamp}}"
  }
}
```

---

## 4. Apifox 配置步骤

### 4.1 创建 Mock 分组

在 Apifox 中按以下结构创建接口：

```
VidNexus API Mock
├── video-qa                    # 新建分组
│   ├── POST /api/v1/tasks/{task_id}/qa
│   ├── GET /api/v1/tasks/{task_id}/qa
│   ├── GET /api/v1/tasks/{task_id}/qa/{qa_id}
│   ├── PATCH /api/v1/tasks/{task_id}/qa/{qa_id}
│   └── DELETE /api/v1/tasks/{task_id}/qa/{qa_id}
├── global-chat                 # 新建分组
│   ├── POST /api/v1/kbs/{kbid}/chats
│   ├── GET /api/v1/kbs/{kbid}/chats
│   ├── GET /api/v1/kbs/{kbid}/chats/{chat_id}
│   ├── PATCH /api/v1/kbs/{kbid}/chats/{chat_id}
│   └── DELETE /api/v1/kbs/{kbid}/chats/{chat_id}
└── global-qa                   # 新建分组
    ├── POST /api/v1/kbs/{kbid}/chats/{chat_id}/qa
    ├── GET /api/v1/kbs/{kbid}/chats/{chat_id}/qa
    ├── GET /api/v1/kbs/{kbid}/chats/{chat_id}/qa/{qa_id}
    ├── PATCH /api/v1/kbs/{kbid}/chats/{chat_id}/qa/{qa_id}
    └── DELETE /api/v1/kbs/{kbid}/chats/{chat_id}/qa/{qa_id}
```

### 4.2 轮询接口的"多期望"配置（关键步骤）

以 `GET /api/v1/tasks/{task_id}/qa/{qa_id}` 为例：

1. 进入接口 → "高级 Mock" → "期望"标签
2. 添加 3 条期望：

| 期望名称 | 触发条件 |
|---------|---------|
| `qa-polling-1` | Header `X-Poll-Count` = `1` |
| `qa-polling-2` | Header `X-Poll-Count` = `2` |
| `qa-polling-3` | Header `X-Poll-Count` ≥ `3`（使用正则 `^([3-9]|[1-9]\d+)$`） |

3. 期望1/2 返回 `answer_content: null`，期望3 返回完整回答

**同样配置应用于**:
- `GET /api/v1/kbs/{kbid}/chats/{chat_id}/qa/{qa_id}`（Global QA 轮询）

### 4.3 错误场景补充

| 接口 | 错误场景 | HTTP | 响应 |
|------|---------|------|------|
| 所有 | 未鉴权 | 401 | `{"detail": "Not authenticated"}` |
| GET 单个 | 资源不存在 | 404 | `{"detail": "QA record qa_bad not found"}` |
| POST 创建 | 空的 question_content | 422 | FastAPI 校验错误 |
| PATCH | regenerate 非 bool | 422 | FastAPI 校验错误 |

在 Apifox 中为每个接口添加"错误期望"，通过自定义脚本或条件匹配触发。

---

## 5. 数据一致性矩阵

为让 Mock 体验更真实，以下 ID 应在整个 Phase 5 Mock 中保持一致：

| 变量 | 值 | 首次出现 | 被引用 |
|------|-----|---------|--------|
| `mock_kbid` | `kb_mock_001` | Phase 2 | Global Chat/QA 路径 |
| `mock_chat_id` | `chat_mock_001` | POST Global Chat | Global QA 路径 |
| `mock_task_id` | `task_mock_001` | Phase 2 | Video QA 路径 |
| `mock_video_id` | `vid_mock_001` | Phase 2 | cited_sources 引用 |
| `mock_qa_id` | `qa_mock_001` | POST Video QA | GET/PATCH/DELETE |
| `mock_gqa_id` | `gqa_mock_001` | POST Global QA | GET/PATCH/DELETE |

---

## 6. Flutter 端验证清单

完成 Apifox Mock 配置后，按以下步骤验证 Phase 5 Flutter 代码：

| # | 验证项 | Service | 预期 |
|---|--------|---------|------|
| 1 | 创建 Video QA → `answer_content` 为 null | `VideoQAService.createQA()` | `data.answerContent == null` |
| 2 | 轮询 3 次后拿到回答 | `QAPoller.waitForAnswer()` | 返回 `VideoSummaryChatReplyData` 非空文本 |
| 3 | 超时 60s 抛异常 | `QAPoller` | 抛出 `QAPollingTimeoutException` |
| 4 | 分页列表含 2 条 QA | `VideoQAService.listQAs()` | 2 条 + pagination |
| 5 | PATCH regenerate 后 answer 清空 | `VideoQAService.updateQA()` | `answerContent == null` |
| 6 | 创建 Global Chat → 返回 chat_id | `GlobalChatService.createChat()` | `chat_id` 非空 |
| 7 | 会话列表含 3 条 | `GlobalChatService.listChats()` | 3 条 |
| 8 | Global QA 列表含 cited_sources | `GlobalQAService.listQAs()` | `citedSources` 数组非空 |
| 9 | `sendSummaryChatMessage()` 端到端 | `HttpVideoSummaryRepository` | 完整链路：createQA → poll → reply |
| 10 | flutter analyze | — | No issues found |

---

## 附录 A：Apifox Mock 响应模板变量速查

| 变量 | 含义 | 示例输出 |
|------|------|---------|
| `{{$guid}}` | 随机 GUID | `a1b2c3d4-e5f6-7890-abcd-ef1234567890` |
| `{{$isoTimestamp}}` | ISO 8601 时间戳 | `2026-05-16T08:30:00Z` |
| `{{$randomInt}}` | 随机整数 | `42` |
| `{{request.body.xxx}}` | 请求体字段回显 | 动态取值 |
| `{{request.path.xxx}}` | 路径参数回显 | 动态取值 |

## 附录 B：与 Phase 3 轮询 Mock 的差异

| 维度 | Phase 3 (TaskPoller) | Phase 5 (QAPoller) |
|------|---------------------|-------------------|
| 轮询目标 | `GET /tasks/{taskId}` | `GET /tasks/{taskId}/qa/{qaId}` |
| 判定字段 | `workflow_state` | `answer_content` |
| 终态条件 | `workflow_state ∈ {DRAFT_READY, COMPLETED, FAILED}` | `answer_content != null` |
| 轮询次数 | 4 次（DRAFT_GENERATING × 3 → DRAFT_READY） | 3 次（null × 2 → 有内容） |
| 超时 | 5 min | 60 s |
| Header | `X-Poll-Count` | `X-Poll-Count`（复用同一机制） |
