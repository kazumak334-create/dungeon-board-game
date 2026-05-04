# ClaudeCode ワークフロー定義

更新日: 2026-05-02

## 役割分担

| 役割 | 担当 | 禁止 |
|------|------|------|
| CEO判断・企画・要件定義・PMO | ClaudeCode | コード実装・GDScript修正 |
| 実装・構文チェック・バグ修正 | Codex | 仕様判断・要件定義 |

## Handoff フロー

ClaudeCode → docs/tasks/codex_request_YYYYMMDD_NNN.md 作成
Codex が request を読んで実装・検証
Codex → docs/tasks/codex_result_YYYYMMDD_NNN.md 作成
ClaudeCode が result を受け取り PMO 更新

## 現在の進捗（2026-05-02）

### 完了済み（Agent方式で実施済み）

| Task | 内容 | 状態 |
|------|------|------|
| 0-1 | TBDコスト確定・cards_econ.json更新 | 完了 |
| 1-1 | EconEconomy.gd ティック処理実装 | 完了 |
| 1-2 | 幸福度システム実装 | 完了 |
| 1-3 | 人口・配分バー実装 | 完了 |
| 2-1 | 広場・住居完全実装 | 完了 |

### 未着手（Codex handoff 方式で実施予定）

| Task | 内容 | 優先度 |
|------|------|--------|
| 2-2 | 交換所(EXCHANGE)実装 | Medium |
| 2-3 | 防衛拠点・鍛冶屋実装 | Medium |
| 3-2 | ターンドロー・リロードCT厳密化 | High |
| 4-1 | セミリアルタイムターン進行 | High |
| 4-2 | 最終突撃フェーズ実装 | High |
| 4-3 | 1ラン5戦構造 | Medium |
| 6-1 | ヘッダーUI | Medium |
| 6-2 | フッターUI・手札表示 | Medium |
