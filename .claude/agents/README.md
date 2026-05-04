# ClaudeCode Agents

更新日: 2026-05-02

## Active Agents

- `ceo.md`: ユーザー指示の整理、振り分け、承認
- `pmo.md`: タスク分解、roadmap/CHANGELOG更新候補、Codex request作成
- `architect.md`: 企画を実装可能な要件定義へ変換
- `designer.md`: UI/UX企画・レビュー
- `checker.md`: Codex結果や小規模差分の軽量レビュー
- `gdscript-checker.md`: Godot/GDScript構文・頻出エラー確認
- `godot-debugger.md`: Godot実行・ログ確認補助

## Archived

以下は通常運用から外し、`.local/agent_archive_20260502/` に退避。

- `implementer.md`
- `planning.md`
- `marketing.md`
- `pr.md`

## Rule

実装は原則 `docs/tasks/codex_request_*.md` を作成してCodexへ明示dispatchする。
ClaudeCodeは企画、要件定義、PMO、レビューを担当する。
