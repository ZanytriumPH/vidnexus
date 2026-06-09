# Knowledge QA Progress Streaming

## Purpose

Enable the knowledge base QA frontend to receive and display intermediate ReAct agent progress events via SSE, replacing the generic "AI 正在思考" indicator with specific, actionable status messages during the agent's think-search-analyze-generate loop.

## Requirements

### Requirement: SSE progress event parsing

The system SHALL parse the `event: progress` SSE message and extract its `phase` and `message` fields into a typed data object.

#### Scenario: SseClient dispatches progress event

- **WHEN** the SSE stream receives `event: progress` followed by `data: {"phase": "searching", "message": "正在检索相关内容..."}`
- **THEN** `SseClient._dispatch()` returns an `SSEEvent` with `type: SSEEventType.progress` and `data` parsed as a `Map<String, dynamic>` containing `phase` and `message`

#### Scenario: Unknown event is silently skipped

- **WHEN** the SSE stream receives an event with an unknown `event:` field
- **THEN** `SseClient._dispatch()` returns `null` and the event is skipped without error

#### Scenario: Backward compatibility — no progress events

- **WHEN** the SSE stream contains only `start`, `delta`, `done` events (no `progress` events)
- **THEN** the controller processes all events normally and the UI displays the existing "AI 正在思考" indicator

---

### Requirement: Live progress display in waiting indicator

The system SHALL display the most recent progress message in the waiting indicator during the QA request lifecycle, replacing the generic "AI 正在思考" text.

#### Scenario: First progress event updates indicator text

- **WHEN** the first `progress` event arrives with `message: "正在分析你的问题..."`
- **THEN** the `AppTypingIndicator` displays "正在分析你的问题..." with breathing animation dots

#### Scenario: Subsequent progress events update indicator text

- **WHEN** a second `progress` event arrives with `message: "正在从知识库检索相关内容..."`
- **THEN** the `AppTypingIndicator` text updates to "正在从知识库检索相关内容..."

#### Scenario: No progress message falls back to default

- **WHEN** no `progress` event has arrived and `AppTypingIndicator` is rendered without a `message` parameter
- **THEN** it displays the default text "AI 正在思考"

---

### Requirement: Progress steps preserved in chat history

The system SHALL accumulate progress steps on the system answer message and render them as a collapsible "思考过程" section above the answer text, visible after the answer begins streaming and available in scroll-back history.

#### Scenario: Progress steps accumulate on system message

- **WHEN** three `progress` events arrive during a QA request
- **THEN** the system message's `progressSteps` list contains three `KnowledgeProgressStep` entries, each with `phase`, `message`, and `timestamp`

#### Scenario: Collapsible section displays after delta arrives

- **WHEN** the first `delta` event arrives and the system message has accumulated progress steps
- **THEN** the chat bubble renders a collapsible "思考过程 (N 步)" header above the streamed answer text

#### Scenario: Default collapsed state

- **WHEN** a completed answer with progress steps is displayed in the chat history
- **THEN** the "思考过程" section is collapsed by default

#### Scenario: Expand and collapse interaction

- **WHEN** the user taps the "思考过程" header
- **THEN** the list of progress steps expands with animated transition, showing each step's phase icon, message text, and relative timestamp

#### Scenario: No progress steps — no section rendered

- **WHEN** a system message has `progressSteps` equal to `null` or empty
- **THEN** no "思考过程" section is rendered in the chat bubble

---

### Requirement: Phase icon mapping

The system SHALL render a distinct icon for each `phase` value in the "思考过程" step list.

#### Scenario: thinking phase

- **WHEN** a progress step has `phase: "thinking"`
- **THEN** the step displays the `Icons.psychology` icon

#### Scenario: searching phase

- **WHEN** a progress step has `phase: "searching"`
- **THEN** the step displays the `Icons.search` icon

#### Scenario: retrieved phase

- **WHEN** a progress step has `phase: "retrieved"`
- **THEN** the step displays the `Icons.check_circle_outline` icon

#### Scenario: loading phase

- **WHEN** a progress step has `phase: "loading"`
- **THEN** the step displays the `Icons.hourglass_bottom` icon

#### Scenario: generating phase

- **WHEN** a progress step has `phase: "generating"`
- **THEN** the step displays the `Icons.auto_awesome` icon

#### Scenario: Unknown phase falls back

- **WHEN** a progress step has an unrecognized `phase` value
- **THEN** the step displays the `Icons.info_outline` icon
