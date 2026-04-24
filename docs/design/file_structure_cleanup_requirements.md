# ファイル構成最適化 要件定義書

## 1. 概要
ルート汚染・scripts/フラット83ファイル・バックアップ残骸・docs散在を解消し、保守性を向上させる。

## 2. 実施フェーズ概要

| フェーズ | 内容 | リスク |
|---------|------|--------|
| A | 破損ファイル削除・バックアップ削除・ルートtest系移動 | なし |
| B | scripts/ サブディレクトリ分類 | 中（参照追従必要） |
| C | check_*.sh を tools/ci/ へ集約 | 低（ドキュメント更新多数） |
| D | docs/ 整理 | 低 |

---

## フェーズA（影響なし・即実行可）

### A-1. 破損ファイル削除

以下のファイルはパス文字列が破損しており、正規版が scripts/ に存在するため削除する。

**対象ファイル（4件）：**
- `C:Userskazumdungeon-board-gamescriptsProgressBar.gd`
- `C:Userskazumdungeon-board-gamescriptsProgressBar.gd.uid`
- `C:Userskazumdungeon-board-gamescriptsWaveManager.gd`
- `C:Userskazumdungeon-board-gamescriptsWaveManager.gd.uid`

**正規版の存在確認：**
- `scripts/ProgressBar.gd` ← 正規版
- `scripts/WaveManager.gd` ← 正規版

**影響範囲：** なし（破損パスであり参照不可能）

**追従更新が必要な参照元：** なし

**検証方法：**
- ファイルが存在しないことを確認（ls またはGlob）
- `bash check_syntax.sh` でエラー増加がないことを確認

---

### A-2. バックアップファイル削除

**対象ファイル（11件）：**

`data/` 配下：
- `data/cards.json.backup_*`（9ファイル、glob: `data/cards.json.backup_*`）

`scripts/` 配下：
- `scripts/DeckPrepBoard.gd.bak`
- `scripts/EventQueue.gd.backup`

`docs/` 配下：
- `docs/roadmap.md.bak`

**影響範囲：** なし（バックアップファイルはGodotプロジェクトから参照されない）

**追従更新が必要な参照元：** なし

**検証方法：**
- ファイルが存在しないことを確認
- `bash check_syntax.sh` でエラー増加がないことを確認

---

### A-3. ルートtest系ファイル移動

**移動先：** `tests/`（ディレクトリが存在しない場合は作成）

**対象ファイル（11件）：**

| 移動元 | 移動先 |
|--------|--------|
| `test_all_v2.gd` | `tests/test_all_v2.gd` |
| `test_all_v2.gd.uid` | `tests/test_all_v2.gd.uid` |
| `test_mana_only.gd` | `tests/test_mana_only.gd` |
| `test_mana_only.gd.uid` | `tests/test_mana_only.gd.uid` |
| `test_map_isolation.gd` | `tests/test_map_isolation.gd` |
| `test_map_isolation.gd.uid` | `tests/test_map_isolation.gd.uid` |
| `test_syntax.gd` | `tests/test_syntax.gd` |
| `test_syntax.gd.uid` | `tests/test_syntax.gd.uid` |
| `test_runner_script.gd` | `tests/test_runner_script.gd` |
| `test_runner_script.gd.uid` | `tests/test_runner_script.gd.uid` |
| `test_scene.tscn` | `tests/test_scene.tscn` |

**影響範囲：** 参照なし確認済み

**追従更新が必要な参照元：**
- `test_scene.tscn` はフェーズB記載の `.claude/settings.local.json` に記載があれば更新（フェーズB実施後に確認）
- `.uid` ファイルはGodotが自動再生成するため移動のみで可

**検証方法：**
- `bash check_syntax.sh` でエラー増加がないことを確認
- Godotエディタ起動でエラーが出ないことをユーザーが確認

---

### A-4. docs/archive/ と docs/sprints/ の整合性確認

**対象：**
- `docs/archive/` ディレクトリ全体
- `docs/sprints/`（1ファイルのみ）

**実施内容：**
- `docs/sprints/` の1ファイルが `docs/archive/` に統合可能か確認
- 統合可否をフェーズDの判断材料として記録

**影響範囲：** 確認のみ。実施はフェーズD

**追従更新が必要な参照元：** フェーズD実施時に判断

**検証方法：** 目視確認のみ

---

## フェーズB（参照追従必要・中リスク）

### B-1. scripts/ サブディレクトリ分類

#### 推奨ディレクトリツリー

```
scripts/
├── autoload/          ← autoload登録済みスクリプト（ConfigLoader/GameSession/DebugPanel/SceneManager/CardDB）
├── debug/             ← Debug*、AutoTest、TestBattle*、TestDBIntegrity、DeckTestTool、RunTests、TestRunner
├── ui/                ← 既存ui/配下 + CardSlot、CardUIComponent、CommonTaskbar
├── deck_prep/         ← DeckPrep*系全部
└── system/            ← BoardManager、CombatSystem、DeckManager、BossReward、WaveManager、ProgressBar など
```

#### 選択肢提示

**選択肢A（フル分類）：** 上記ツリー全体を適用。autoloadパス変更が伴うため project.godot も更新必要。リスク高め。

**選択肢B（段階的・推奨）：** autoload は `scripts/` 直下に維持。`debug/` と `tests/` 相当のみ移動。autoloadパス変更なし。リスク低め。

実装者は選択肢AまたはBをユーザーに確認してから実施すること。

#### 追従更新が必要な参照元（選択肢A採用時）

| ファイル | 更新内容 |
|---------|---------|
| `project.godot` | autoloadセクションのパス更新（autoload/ 移動時のみ） |
| `scripts/Main.gd` | `load()` / `preload()` のパス更新 |
| `scripts/TestRunner.gd` | 参照パス更新 |
| `scenes/tools/DeckTestTool.tscn` | スクリプト参照パス更新 |
| `tests/test_scene.tscn` | フェーズA移動後のパス更新 |
| `.claude/settings.local.json` | パス設定があれば更新 |

#### 追従更新が必要な参照元（選択肢B採用時）

| ファイル | 更新内容 |
|---------|---------|
| `scripts/TestRunner.gd` | debug/ 移動ファイルの参照パス更新 |
| `scenes/tools/DeckTestTool.tscn` | debug/ 移動ファイルの参照パス更新 |

**検証方法：**
- `bash check_syntax.sh` でエラー0件を確認
- Godotエディタ起動でエラーが出ないことをユーザーが確認
- `grep -r "scripts/" project.godot` でautoloadパスが正しいことを確認（選択肢A時）

---

## フェーズC（ドキュメント更新多数・低リスク）

### C-1. check_*.sh を tools/ci/ へ集約

**移動対象（5件）：**

| 移動元 | 移動先 |
|--------|--------|
| `check_syntax.sh` | `tools/ci/check_syntax.sh` |
| `check_gameplay.sh` | `tools/ci/check_gameplay.sh` |
| `check_godot_health.sh` | `tools/ci/check_godot_health.sh` |
| `check_runtime_errors.sh` | `tools/ci/check_runtime_errors.sh` |
| `check_ui_inheritance.sh` | `tools/ci/check_ui_inheritance.sh` |

`tools/ci/` ディレクトリが存在しない場合は作成する。

### C-2. 追従更新が必要な参照元（21件）

**ルート直下：**
- `check_syntax.sh` → 自己参照箇所（他のcheck_*.shを呼び出している場合）
- `check_godot_health.sh` → 自己参照箇所

**ドキュメント（19件）：**

| ファイル | 更新内容 |
|---------|---------|
| `CLAUDE.md` | `bash check_syntax.sh` → `bash tools/ci/check_syntax.sh` |
| `.claude/agents/checker.md` | check_syntax.sh 参照パス更新 |
| `README_UI_CHECK.md` | check_ui_inheritance.sh 参照パス更新 |
| `docs/CHANGELOG.md` | 記載がある場合のみ更新 |
| `docs/design/design_principles.md` | check_*.sh 参照パス更新 |
| `docs/design/glossary.md` | check_*.sh 参照パス更新 |
| `docs/design/terminology_inconsistencies.md` | check_*.sh 参照パス更新 |
| `docs/design/pve_wave_pending_issues.md` | check_*.sh 参照パス更新 |
| `docs/design/pve_wave_compatibility_check.md` | check_*.sh 参照パス更新 |
| `docs/design/` その他8件 | check_*.sh 参照パス更新（grep確認後に対象確定） |
| `docs/meta/agents.md` | check_*.sh 参照パス更新 |
| `docs/meta/agents_v2.md` | check_*.sh 参照パス更新 |
| `docs/dev/ui_inheritance_check.md` | check_ui_inheritance.sh 参照パス更新 |
| `docs/archive/sprint1_deckprep_ux_item2.md` | check_*.sh 参照パス更新 |

**実施前確認：**
```bash
grep -rl "check_syntax.sh\|check_gameplay.sh\|check_godot_health.sh\|check_runtime_errors.sh\|check_ui_inheritance.sh" .
```
このgrepで実際の参照元を確定してから更新すること。

**検証方法：**
- `bash tools/ci/check_syntax.sh` が正常実行できることを確認
- 更新後ドキュメントの参照パスが正しいことをgrepで確認
- Godotエディタ起動でエラーが出ないことをユーザーが確認

---

## フェーズD（docs整理・低リスク）

### D-1. docs/sprints/ と docs/archive/ の統合

**前提：** フェーズA-4の確認結果をもとに判断する。

**実施内容：**
- `docs/sprints/` 配下の1ファイルを `docs/archive/` へ移動
- `docs/sprints/` ディレクトリを削除（空になる場合）

**影響範囲：** 参照がある場合のみ更新（フェーズA-4確認後に特定）

**追従更新が必要な参照元：**
- `docs/roadmap.md` に sprints/ への参照がある場合は更新
- `CLAUDE.md` に記載がある場合は更新

**検証方法：** 目視確認 + grep で参照なしを確認

---

### D-2. docs/ 直下33ファイルの分類整理提案

**実施内容：** 現状の33ファイルを以下の基準で分類し、移動先を提案する（実施はユーザー承認後）。

**分類基準：**

| カテゴリ | 移動先 | 対象の目安 |
|---------|--------|-----------|
| 設計文書 | `docs/design/`（既存） | *_design.md、*_spec.md |
| 開発記録 | `docs/dev/`（既存） | *_check.md、*_report.md |
| 運営計画 | `docs/meta/`（既存） | agents.md、roadmap.md 等 |
| 過去記録 | `docs/archive/`（既存） | 完了フェーズ記録等 |
| ルート維持 | `docs/` 直下 | GAME_DESIGN.md、roadmap.md、CHANGELOG.md など常時参照 |

**追従更新が必要な参照元：**
- `CLAUDE.md`（参照ファイルリスト）
- `docs/meta/agents.md`（全Agent必読ファイルリスト）

**検証方法：**
- `grep -r "docs/" CLAUDE.md` で参照パスが正しいことを確認
- Godotエディタ起動でエラーが出ないことをユーザーが確認

---

## 5. 制約・注意事項

- **実装順序は A → B → C → D の順で実施すること**（依存関係あり）
- **フェーズBの選択肢A/Bはユーザーに確認してから着手すること**
- **各フェーズ完了後に必ず `bash tools/ci/check_syntax.sh`（フェーズC完了前は `bash check_syntax.sh`）を実行すること**
- **ロールバック手順：** 各フェーズ完了後に `git commit` し、問題発生時は `git revert` または `git checkout` で復元する
- `.uid` ファイルはGodotが自動再生成するため、移動後にGodotエディタを起動すれば整合性が回復される
- `project.godot` の autoload パス変更は特にリスクが高いため、変更前後で必ずGodot起動確認を実施すること
