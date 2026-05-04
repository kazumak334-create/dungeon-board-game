# Sprint計画自動化Workflow設計

**作成日:** 2026-05-04  
**対象:** マスター計画更新・Sprint企画設計・要件定義書化の自動化  
**実装形態:** ClaudeCode Skill (定型作業・定期実行型)

---

## 1. Workflow概要

### 1.1 目的

Sprint企画の受け取り → デザイン企画 → 要件定義書 の3ステップを**自動化**し、手作業の繰り返しを削減。

### 1.2 実装パターン

**パターンA: マスター計画受け取り自動化**
```
Google Drive (G:\マイドライブ\ざったなファイル\...)
  ↓
[定期チェック Skill] 新規 MDファイル検出
  ↓
ファイル読み込み → docs/ へ保存
  ↓
読み込み済フォルダへ移動
  ↓
roadmap.md 更新
```

**パターンB: Sprint企画受け取り → Design + Req自動化**
```
Google Drive に新規 Sprint#N_xxx_final.md 配置
  ↓
[定期チェック Skill] ファイル検出
  ↓
docs/ へ保存 → 読み込み済へ移動
  ↓
Designer Agent (Opus) 起動 → sprint#N_designer_plan.md 生成
  ↓
Architect Agent (Opus) 起動 → REQUIREMENTS_SPRINT_#N.md 生成
  ↓
ユーザーに「完了通知」で実装ステップに移行
```

---

## 2. Skill実装仕様

### 2.1 Skill #1: Master計画自動更新スキル

**名称:** `update-master-roadmap`  
**トリガー:** 定期実行（週1回・金曜10:00）

**実装内容:**
```
1. Google Drive 監視ディレクトリをチェック
   - パス: G:\マイドライブ\ざったなファイル\ゲームアイデア系\v0.2_MVP用\
   - ファイルパターン: master_roadmap_*.md

2. 新規ファイル検出時
   - docs/ 配下へ複製（UTF-8保存）
   - 読み込み済フォルダへ移動
   - filename の version 番号を記録 (v1.2 → v1.3 等)

3. roadmap.md 更新処理
   - 既存の「Master Roadmap v1.2」セクションを新版で置換
   - 更新日を current date に変更
   - 旧版セクションはコメントアウト保存（Git履歴重視）

4. 完了ログ
   - ファイル名・版番号・更新内容をテンポラリ記録
   - ユーザー通知: "Master Roadmap v1.X に更新しました"
```

**実装参考パス:**
- `skills/update-master-roadmap.yaml` (Skill定義)
- `scripts/roadmap_update.py` (Python実装)

---

### 2.2 Skill #2: Sprint企画自動設計化スキル

**名称:** `process-sprint-plan`  
**トリガー:** 手動起動 or Google Drive 監視 (新規 Sprint企画ファイル検出時)

**入力:**
- `sprint_number`: Sprint番号 (9, 10, ...)
- `source_path`: Google Drive パス or docs 内パス

**実装内容:**

```
[Phase 1] 入力ファイル処理
  1. Google Drive からファイルを読み込み
  2. docs/sprint#N_xxx_final.md として保存
  3. Google Drive の読み込み済フォルダへ移動

[Phase 2] Designer企画生成（Opus Agent呼び出し）
  1. input: docs/sprint#N_xxx_final.md
  2. Agent呼び出し:
     subagent_type: "designer"
     model: "opus"
     prompt: (本Skill内に埋め込み)
  3. output: docs/design/sprint#N_designer_plan.md
  4. ユーザー通知: "Designer企画書を生成しました"

[Phase 3] Architect要件定義生成（Opus Agent呼び出し）
  1. input:
     - docs/sprint#N_xxx_final.md (企画書)
     - docs/design/sprint#N_designer_plan.md (Designer企画)
  2. Agent呼び出し:
     subagent_type: "architect"
     model: "opus"
     prompt: (本Skill内に埋め込み)
  3. output: docs/requirements/REQUIREMENTS_SPRINT_#N.md
  4. ユーザー通知: "要件定義書を生成しました"

[Phase 4] 実装準備通知
  1. 3つのファイル生成完了を確認
  2. ユーザーへ:
     "Sprint #N の企画→デザイン→要件定義が完了しました。
      次: Implementer での実装着手"
```

**実装参考パス:**
- `skills/process-sprint-plan.yaml`
- `scripts/sprint_process.py`

---

## 3. Google Drive 監視の実装方法

### 3.1 方式A: 定期ポーリング（推奨・シンプル）

```python
# pseudocode
def monitor_google_drive():
    source_dir = "G:\\マイドライブ\\ざったなファイル\\ゲームアイデア系\\v0.2_MVP用"
    processed_dir = os.path.join(source_dir, "読み込み済")
    
    # ファイル一覧取得
    current_files = os.listdir(source_dir)
    
    # 既処理ファイル一覧取得
    processed_files = os.listdir(processed_dir)
    
    # 差分 = 新規ファイル
    new_files = [f for f in current_files if f not in processed_files and f.endswith('.md')]
    
    for file in new_files:
        process_file(file)
```

**実装:**
- CronCreate で `0 10 * * 5` (毎週金曜10:00)
- or Bash `watch -n 3600 'python scripts/monitor_drive.py'` (1時間ごと)

### 3.2 方式B: 即時トリガー

ユーザーが以下のSlash Commandで手動実行：
```
/process-sprint sprint=9 source=docs/sprint9_reward_milestone_chest_final.md
```

→ Skill が Master Agent に受け渡し

---

## 4. Agent 呼び出し時の Prompt テンプレート

### 4.1 Designer Skill Prompt Template

```markdown
# Input
- Sprint企画書: {source_file_path}
- 参考: CLAUDE.md / docs/design/design_principles.md

# Task
このSprint企画書に基づいて、Designer視点でUI/UX企画書を完成させてください。

## Output
- ファイル名: docs/design/sprint{N}_designer_plan.md
- 構成: [このSkillに埋め込まれたテンプレート参照]
- 出力形式: Markdown

## Constraints
- 既存UI基準6項目（docs/design/design_principles.md）を遵守
- 新規色定義は禁止（KISS原則）
- 核となる体験との整合確認必須
```

### 4.2 Architect Skill Prompt Template

```markdown
# Input
- Sprint企画書: {source_file_path}
- Designer企画: docs/design/sprint{N}_designer_plan.md

# Task
Designer企画書に基づいて、Architect視点で要件定義書を作成してください。

## Output
- ファイル名: docs/requirements/REQUIREMENTS_SPRINT_{N}.md
- 構成: [このSkillに埋め込まれたテンプレート参照]
- 出力形式: Markdown

## Constraints
- 完了条件: 企画書と完全一致
- 用語統一: 企画書の用語をそのまま採用
- 実装フロー: 依存関係を明示
```

---

## 5. エラーハンドリング

| エラーパターン | 対応 |
|---|---|
| Google Drive ファイル読み込み失敗 | ユーザーへ通知、手動確認待ち |
| Designer / Architect Agent タイムアウト | ユーザーへ「トークン枯渇」通知、手動再実行 |
| ファイル出力パス権限エラー | ユーザーへ「パス確認」通知 |
| Markdown 形式エラー | ユーザーへ「要件定義書に形式エラー」通知 |

---

## 6. 実装ロードマップ

### Phase 1: 基盤構築（2週間）
- [ ] Skill #1 実装: `update-master-roadmap`
- [ ] Python 監視スクリプト作成
- [ ] Google Drive ポーリング テスト

### Phase 2: Sprint処理自動化（2週間）
- [ ] Skill #2 実装: `process-sprint-plan`
- [ ] Designer/Architect Agent Prompt チューニング
- [ ] 通しテスト (Sprint 9 テンプレート使用)

### Phase 3: 運用開始（1週間）
- [ ] 定期スケジュール登録
- [ ] ユーザーマニュアル作成
- [ ] 初回実行テスト

---

## 7. 今後の拡張案

### 7.1 Implementer 自動実装（未来）
```
要件定義書完成
  ↓
Implementer Agent (Sonnet) 起動
  ↓
実装 → Checker 検証 → 自動コミット
```

### 7.2 テスト自動化（未来）
```
実装完了
  ↓
テストスイート自動生成
  ↓
CI/CD パイプライン統合
```

---

## 8. セットアップ手順（ユーザー向け）

### 8.1 Skill インストール

```bash
# Claude Code CLI
claude skill install process-sprint-plan
claude skill install update-master-roadmap
```

### 8.2 Google Drive パス設定

`.claude/skills/config.json`:
```json
{
  "google_drive_root": "G:\\マイドライブ\\ざったなファイル\\ゲームアイデア系\\v0.2_MVP用",
  "docs_root": "C:\\Users\\kazum\\dungeon-board-game\\docs",
  "processed_folder": "読み込み済"
}
```

### 8.3 初回実行テスト

```bash
claude skill run process-sprint sprint=9 source=docs/sprint9_reward_milestone_chest_final.md
```

---

## 9. 参考: Sprint 9 で確認した手作業フロー

```
[マニュアル版] (2時間 × 2Agent)
1. 10分: Google Drive からファイル読み込み
2. 5分: docs/ 配置・読み込み済へ移動
3. 60分: Designer Agent (Opus) 実行 → sprint9_designer_plan.md
4. 60分: Architect Agent (Opus) 実行 → REQUIREMENTS_SPRINT_9.md
5. 15分: 出力ファイルチェック・通知

[自動化版] (30分)
1. ユーザーが /process-sprint sprint=9 実行
2. Skill が全フェーズを自動処理
3. 完了通知受け取り
4. Implementer 着手
```

→ **毎Sprint で 1.5時間削減 × 30 Sprints = 45時間削減**

---

## 付録: YAML Skill定義例

```yaml
# .claude/skills/process-sprint-plan.yaml
name: process-sprint-plan
category: sprint-automation
description: "Sprint企画書受け取り → Designer → Architect → 要件定義書自動生成"
version: 1.0

inputs:
  sprint_number:
    type: integer
    description: "Sprint番号 (9, 10, ...)"
  source_path:
    type: string
    description: "Google Drive or docs パス"

workflow:
  - phase: prepare
    steps:
      - read_file: "source_path"
      - save_to_docs: "sprint{N}_xxx_final.md"
      - move_to_processed: "読み込み済へ移動"
  
  - phase: design
    steps:
      - agent_call:
          subagent_type: "designer"
          model: "opus"
          output: "docs/design/sprint{N}_designer_plan.md"
  
  - phase: requirements
    steps:
      - agent_call:
          subagent_type: "architect"
          model: "opus"
          output: "docs/requirements/REQUIREMENTS_SPRINT_{N}.md"
  
  - phase: notify
    steps:
      - notify_user: "3つのファイル生成完了。Implementer着手待ち"

on_error:
  notify_user: true
  retry: false
```
