# ClaudeCode Token Budget Rules

更新日: 2026-05-02

## 目的

ClaudeCode のトークン消費を抑え、Codex と並行作業しても衝突しにくい運用にする。

## 通常読むファイル

新規セッション・通常タスクでは、まず以下だけを読む。

- `CLAUDE.md`
- `docs/session_handover.md`
- `docs/GAME_DESIGN_V0_2_MVP.md`
- `docs/requirements/REQUIREMENTS_V0_2_MVP.md`
- `docs/tasks/codex_request_*.md`
- `docs/tasks/codex_result_*.md`
- `docs/meta/claudecode_workflow.md`
- `docs/meta/codex_system_prompt.md`

## 明示がある時だけ読むファイル・ディレクトリ

以下は通常探索対象にしない。ユーザー、CEO、PMO、または task file が明示した場合だけ読む。

- `docs/archive/`
- `docs/research/`
- `docs/design/`
- `docs/CHANGELOG.md`
- `docs/card_database.md`
- `docs/requirements/req_*.md`
- `.claude/hooks/*.log`
- `.claude/hooks/_tmp_prompt.md`
- `mcp.log`

## 実装対象スコープ

現在の主対象は Econ MVP。

- 通常対象: `scripts/econ_mvp/`, `scenes/econ_mvp/`, `data/cards_econ.json`
- 明示がある時だけ参照: `scripts/poc/`, `scripts/poc2/`, `scripts/hex_mvp/`, 旧 `scripts/*.gd`

## Codex 並行作業中のルール

- Codex が実装中の `docs/tasks/codex_request_*.md` と `docs/tasks/codex_result_*.md` は上書きしない。
- Codex が触っている可能性のある `scripts/econ_mvp/` と `project.godot` は、Codex完了報告まで変更しない。
- 並行してできる作業は、要件整理、PMO分解、読取範囲ルール更新、次タスクのrequest作成まで。
- 大きな整理、ファイル移動、削除、EconMain分割はCodex作業完了後に行う。

## 読み方

- 大きいファイルは全量読まず、`grep` / `Select-String` で該当見出しだけ読む。
- request file に「根拠」として書かれたファイルだけを追加で読む。
- 不明点が出たら、関連候補を全部読む前にユーザーまたはPMOへ確認する。
