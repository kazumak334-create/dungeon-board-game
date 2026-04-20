# Agent トラブルシューティング

## Agent定義更新が反映されない問題

### 症状
- `.claude/agents/*.md`を修正した
- しかし、Agent起動時に古い定義が使われる
- 例：Edit toolを追加したのに「Editツールはありません」

### 原因
**Agent定義のキャッシュ**

Claude Codeは`.claude/agents/*.md`をキャッシュしており、更新が即座に反映されない。

### 時系列例（2026-04-19）
```
15:13:17 - architect.mdにEdit tool追加
15:13:51 - Architect起動（34秒後）
         → 「Editツールはありません」（古い定義を使用）
```

### 対処方法

#### 方法1: Claude Code再起動（推奨）
```bash
# 現在のセッションを終了
exit

# Claude Codeを再起動
claude-code
```

#### 方法2: 待機（非推奨）
- キャッシュTTL（おそらく5分程度）が切れるまで待つ
- 不確実なので非推奨

#### 方法3: Agent定義更新後の確認
Agent起動前に、定義が正しく読み込まれるか確認：
```bash
# Agent定義ファイルの最終更新時刻確認
ls -l .claude/agents/architect.md

# 数分待ってからAgent起動
```

### CEOの対応フロー

**Agent定義を修正した場合**：
1. ✅ 修正後、**Claude Codeを再起動**
2. ✅ または、5分以上待ってからAgent起動
3. ❌ 修正直後にAgentを起動しない

**Agentが「ツールがない」と言った場合**：
1. ✅ Agent定義を確認（tools: [...] にツールが含まれているか）
2. ✅ 修正時刻を確認（直近の修正か？）
3. ✅ 直近の修正なら、キャッシュ問題を疑う
4. ✅ Claude Code再起動後、再試行

### 再発防止

**Agent定義修正ワークフロー**：
```
1. .claude/agents/*.mdを修正
2. Claude Code再起動（またはセッション終了→再起動）
3. 新しいセッションでAgent起動
```

**緊急時の対応**：
- Agent定義のキャッシュ問題でAgentが動かない場合
- CEOが緊急対応として直接実装する（CLAUDE.md確認の上）
- 後でワークフロー見直し

### 参考
- 2026-04-19: Architect Edit tool問題（キャッシュが原因）
- セッションID: e6f92042-7281-475d-b1db-bf66fa0c4c2b
- Agent ID: ab0b14e9ebff0b170
