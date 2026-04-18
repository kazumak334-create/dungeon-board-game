# Agent自律改善システム設計書

## 概要
Agent実行後のトークン使用量を自動監視し、異常を検知して改善を促すシステム。

---

## 1. agent_cost_monitor.py

### 目的
Agent実行完了時に自動実行し、トークン使用量を検証・警告。

### 実行タイミング
`.claude/hooks/agent-complete` フック経由で自動実行

### 入力
```bash
python tools/agent_cost_monitor.py --agent-id <agent-id>
```

### 処理フロー
1. `subagents/agent-<id>.jsonl` から `toolStats` を抽出
2. ベースライン比較
   - PMO（roadmap更新）: 通常 10,000-15,000トークン
   - implementer: 通常 20,000-40,000トークン
   - checker: 通常 5,000-10,000トークン
3. 閾値判定（ベースラインの2倍超過で警告）
4. 異常パターン検出
   - `editFileCount=0 かつ bashCount > 5` → "Edit tool未使用、sed多用の可能性"
   - `readCount > 10` → "重複読み込みの可能性"
   - `bashCount > 15` → "確認コマンド多用の可能性"
5. 警告出力

### 出力例
```
⚠️ Agent実行異常検知

Agent ID: a6a8ddb30f8d7ffb5
Agent Type: pmo
Task: roadmap.md更新

トークン使用量: 41,124（ベースライン: 15,000、2.7倍超過）

検出された問題:
- Edit tool未使用（editFileCount=0、bashCount=12）
- 推定原因: sedでファイル編集を実行
- 対応策: PMO agent定義にEdit toolを追加

ツール使用内訳:
- Read: 7回
- Grep: 1回
- Bash: 12回（sed × 5、確認コマンド × 7）
- Edit: 0回 ← 異常

詳細ログ: subagents/agent-a6a8ddb30f8d7ffb5.jsonl
```

### ベースライン設定ファイル
```json
// tools/agent_baselines.json
{
  "pmo": {
    "roadmap_update": {
      "baseline_tokens": 15000,
      "threshold_multiplier": 2.0,
      "expected_tools": ["Read", "Edit", "Grep"]
    }
  },
  "implementer": {
    "feature_implementation": {
      "baseline_tokens": 30000,
      "threshold_multiplier": 2.0,
      "expected_tools": ["Read", "Edit", "Glob", "Grep"]
    }
  },
  "checker": {
    "verification": {
      "baseline_tokens": 7500,
      "threshold_multiplier": 1.5,
      "expected_tools": ["Read", "Bash", "Grep"]
    }
  }
}
```

### 実装ファイル構成
```
tools/
├── agent_cost_monitor.py         # メインスクリプト
├── agent_baselines.json          # ベースライン定義
├── agent_cost_history.jsonl      # 実行履歴（学習用）
└── AGENT_MONITORING_DESIGN.md    # この設計書
```

---

## 2. validate_agent_definition.py

### 目的
Agent定義ファイル（.claude/agents/*.md）保存時に自動検証。

### 実行タイミング
`.claude/hooks/file-write` フック経由で自動実行（対象: .claude/agents/*.md）

### 入力
```bash
python tools/validate_agent_definition.py --file <file-path>
```

### 処理フロー
1. Agent定義ファイルのfrontmatter解析
   - `description` から責務を抽出
   - `tools` リストを取得
2. 責務とツールセットの整合性チェック
   - 「ファイル編集」「更新」→ Edit tool必須
   - 「検索」「探索」→ Grep tool必須
   - 「ファイル作成」→ Write tool必須
   - 「コマンド実行」→ Bash tool必須
3. 警告出力

### チェックルール定義
```json
// tools/agent_validation_rules.json
{
  "required_tools": {
    "file_edit_keywords": ["編集", "更新", "変更", "修正", "ファイル編集"],
    "requires": ["Edit"],
    "severity": "error"
  },
  "file_search_keywords": ["検索", "探索", "find"],
  "requires": ["Grep"],
  "severity": "warning"
  },
  {
    "file_creation_keywords": ["作成", "新規", "生成"],
    "requires": ["Write"],
    "severity": "warning"
  }
}
```

### 出力例
```
❌ Agent定義検証エラー

File: .claude/agents/pmo.md
Agent: pmo

問題:
- description に「ファイル編集」「更新」が含まれるが、tools に Edit が含まれていない
- 責務: 「docs/roadmap.md の維持・更新」
- 現在のtools: [Read, Bash, Glob, Grep]
- 推奨tools: [Read, Edit, Bash, Glob, Grep]

保存を続けますか？ [y/N]
```

---

## 3. フック設定

### .claude/hooks/agent-complete
```bash
#!/bin/bash
# Agent実行完了時に自動実行

AGENT_ID=$1

# トークン監視
python tools/agent_cost_monitor.py --agent-id "$AGENT_ID"
```

### .claude/hooks/file-write
```bash
#!/bin/bash
# ファイル保存時に自動実行

FILE_PATH=$1

# Agent定義ファイルの場合のみ検証
if [[ "$FILE_PATH" == *.claude/agents/*.md ]]; then
  python tools/validate_agent_definition.py --file "$FILE_PATH"
fi
```

---

## 4. 学習機能（将来拡張）

### agent_cost_history.jsonl
Agent実行履歴を記録し、ベースラインを動的調整。

```jsonl
{"agent_type": "pmo", "task_type": "roadmap_update", "tokens": 14523, "tool_stats": {...}, "timestamp": "2026-04-18T12:00:00Z"}
{"agent_type": "pmo", "task_type": "roadmap_update", "tokens": 41124, "tool_stats": {...}, "timestamp": "2026-04-18T11:05:33Z", "anomaly": true}
```

### ベースライン自動調整
- 直近10回の実行の中央値をベースラインに設定
- 異常値（3σ超過）は除外

---

## 5. 実装優先度

### Phase 1（即座実施済み）
- ✅ PMO agent行動規則の具体化
- ✅ agent_prompt_templates.md作成

### Phase 2（次回実装）
- agent_cost_monitor.py 基本機能
- agent_baselines.json 初期設定
- フック設定（手動実行から開始）

### Phase 3（将来拡張）
- validate_agent_definition.py
- agent_cost_history.jsonl 学習機能
- ベースライン自動調整

---

## 6. 期待効果

### 即座効果（Phase 1）
- PMO agentのトークン使用量 60-70%削減
- Agent呼び出し時の曖昧さ排除

### Phase 2効果
- 異常実行の即座検知（人間が気づく前）
- 原因候補の自動提示（診断時間削減）

### Phase 3効果
- Agent定義の品質向上（設計時に防止）
- ベースライン自動最適化（メンテナンスフリー）

---

## 7. 参照

- feedback_pmo_edit_tool.md: PMOトークン消費問題の教訓
- agent_prompt_templates.md: Agent呼び出しテンプレート
