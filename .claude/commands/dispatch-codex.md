# /dispatch-codex

Codex への自動dispatchは停止済み。必要なときだけ、対象requestを明示して手動起動する。

## 使い方

1. 実装依頼を `docs/tasks/codex_request_YYYYMMDD_NNN.md` として作成する。
2. 変更範囲、禁止ファイル、検証条件、結果ファイル名をrequest内に明記する。
3. 以下を実行する。

```bash
python .claude/hooks/dispatch_codex.py docs/tasks/codex_request_YYYYMMDD_NNN.md
```

## 注意

- Codex作業中は同じ対象ファイルをClaudeCode側で編集しない。
- Codex完了後は `docs/tasks/codex_result_YYYYMMDD_NNN.md` を読んでレビューする。
- 自動hookではないため、`Write` / `Edit` してもCodexは起動しない。
