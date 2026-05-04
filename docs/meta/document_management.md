# ドキュメント管理 — フォルダ構成・ファイル命名規則・バージョン管理プロセス

**文書作成日：2026-05-04 by Claude Code**
**対象版：Econ MVP v0.2**

---

## 全体原則

| 原則 | 説明 |
|-----|------|
| **Single Source of Truth（SSoT）** | 各機能について、最新の企画・要件・設計ファイルはただ1つだけ存在する |
| **明確な廃止マーク** | 旧ファイルには先頭に `STATUS: 廃止（→ 新ファイルパス）` を必須で記入 |
| **ファイル命名の一貫性** | 同一機能の企画・要件・設計ファイルは命名で関連性が明確に分かること |
| **スプリント単位の管理** | Sprint ごとの企画・要件・実装依頼は1セット = 1つのSprint番号で統一 |

---

## フォルダ構成

```
docs/
├── meta/
│   ├── document_management.md           ← このファイル
│   ├── ai_development_rules.md          ← AI/テスト観点ルール
│   └── ...その他メタドキュメント...
│
├── requirements/
│   ├── REQUIREMENTS_SPRINT_{N}.md       ← **ACTIVE: Sprint {N} の要件定義書（SSoT）**
│   ├── REQUIREMENTS_V0_2_MVP.md         ← **ACTIVE: Econ MVP 全体統合版**
│   └── archive/                         ← 廃止済みファイル（参考のため保持・参照禁止）
│       └── req_econ_*.md
│
├── design/
│   ├── sprint{N}_designer_plan.md       ← **ACTIVE: Sprint {N} の UI/UX企画書（SSoT）**
│   ├── design_principles.md             ← 設計判断基準
│   ├── glossary.md                      ← 用語定義
│   └── archive/                         ← 廃止済みファイル
│       └── ...
│
├── tasks/
│   ├── codex_request_sprint{N}.md       ← **ACTIVE: Sprint {N} の実装依頼（SSoT）**
│   ├── codex_result_sprint{N}.md        ← 実装完了報告（参考）
│   └── archive/                         ← 廃止済み実装依頼（参考・参照禁止）
│       └── codex_request_sprint{N}_old.md
│
├── reviews/
│   ├── sakurai_sprint{N}_gate.md        ← SakuraiAgent ゲートレビュー
│   ├── sakurai_phase{N}_review.md       ← Phase 完了時体験レビュー
│   └── ...その他レビュー記録...
│
├── sprint{N}_*_final.md                 ← **ACTIVE: Sprint {N} の企画書（Google Drive から保存）**
├── GAME_DESIGN_V0_2_MVP.md             ← **ACTIVE: Econ MVP 全体仕様（SSoT）**
├── master_roadmap_*.md                  ← **ACTIVE: ロードマップ（最新版）**
├── CHANGELOG.md                         ← 実装履歴（PMO 管理）
├── roadmap.md                           ← 実装状態追跡（PMO 管理）
│
└── archive/                             ← 旧 v0.1・参考資料
    ├── GAME_DESIGN.md                   ← 旧 v0.1 仕様（参考のみ・参照禁止）
    └── ...その他旧ドキュメント...
```

**重要：**
- `ACTIVE` = 現在有効・参照すべき
- `archive/` = 廃止済み・参照禁止・Git履歴として保持
- `archive/` 内のファイルはファイルリストから物理的に分離（見つけにくい）

---

## ファイル命名規則

**基本原則：**
- ファイル名から「これが最新か」「どのファイルと対応しているか」が一目瞭然であること
- 同一機能の企画・要件・実装依頼は **同じ Sprint番号** で統一
- 廃止済みファイルは `archive/` フォルダに移動・Git 履歴として保持

### 1. Sprint 企画書（Google Drive から保存）

**命名:** `sprint{N}_{feature_slug}_final.md`

```
examples:
  sprint7_initial_deck_building_base_final.md
  sprint8_ui_logs_debug_final_revised.md
  sprint9_reward_milestone_chest_final.md
```

**SSoT:** ✅ はい。このファイルを基に Designer → Architect が動く  
**保存先:** `docs/sprint{N}_*.md`（ルート直下）  
**廃止方法:** Google Drive で新ファイルが来たら、旧ファイルの先頭に `STATUS: 廃止（新版は sprint{N}_*_final.md）` を記入

---

### 2. UI/UX 企画書（Designer 出力）

**命名:** `docs/design/sprint{N}_designer_plan.md`

**SSoT:** ✅ はい。レイアウト・色彩・コンポーネント・インタラクションの詳細定義  
**入力:** `sprint{N}_*_final.md`（企画書）  
**作成者:** Designer Agent (Opus)  
**完了条件：** UI基準6項目クリア、CEOの承認  
**廃止方法:** 新版企画が来たら、旧ファイルに `STATUS: 廃止（→ sprint{N}_designer_plan.md）` を記入

---

### 3. 要件定義書（Architect 出力・SSoT）

**命名:** `docs/requirements/REQUIREMENTS_SPRINT_{N}.md`

**SSoT:** ✅ はい。実装チェックリスト・データ構造・実装スコープの最高権威  
**入力:** 
- `sprint{N}_*_final.md`（企画書）
- `docs/design/sprint{N}_designer_plan.md`（Designer 企画）

**作成者:** Architect Agent (Opus)  
**完了条件：** 30項目チェックリスト定義、受入条件・非実装項目・テスト観点・ログ設計を含む  
**廃止方法：** 新版企画が来たら、旧 `REQUIREMENTS_SPRINT_{N}.md` ファイルの先頭に記入  

**重要：旧 `req_econ_*.md` ファイル（個別要件）は廃止対象**
- 現在存在する `req_econ_initial_deck_sprint7.md` など26ファイルは段階的に廃止
- 先頭に `STATUS: 廃止（→ docs/requirements/REQUIREMENTS_SPRINT_{N}.md）` を記入
- Git 削除はしない（履歴を保持）

---

### 4. 実装依頼（Codex 向け）

**命名:** `docs/tasks/codex_request_sprint{N}.md`

**SSoT:** ✅ はい。実装チームが見るべき最新指示  
**入力:** `docs/requirements/REQUIREMENTS_SPRINT_{N}.md`（要件定義書）  
**作成者：** Architect or CEO（Codex リクエスト自動生成 or CEO 手動作成）  
**完了条件：**
- 対応 REQUIREMENTS_SPRINT_{N} から引用
- 実装範囲・禁止ファイル・検証条件を明記
- 既存実装との依存関係を列挙

**廃止方法：** 実装完了後、先頭に `STATUS: 完了（→ codex_result_sprint{N}.md）` を記入

---

### 5. 実装完了報告（参考用）

**命名:** `docs/tasks/codex_result_sprint{N}.md`

**SSoT:** ❌ いいえ。参考記録のみ（実装依頼・要件定義が SSoT）  
**作成者：** Codex  
**用途：** 変更ファイル・変更行数・検証結果の記録  
**廃止方法：** 古い result は削除せず、コメント行で日付ごとに区分

---

### 6. レビュー記録

**命名:** 
- `docs/reviews/sakurai_sprint{N}_gate.md`（ゲートレビュー）
- `docs/reviews/sakurai_phase{N}_review.md`（Phase 完了時体験レビュー）

**SSoT:** ❌ いいえ。参考記録  
**作成者：** SakuraiAgent  
**保持期間：** Phase 終了まで。次 Phase で新規に上書き可

---

## バージョン管理・更新プロセス

### シーン1：新 Sprint 企画が Google Drive に来た

```
1. ユーザーが「Skill使って」と指示
   ↓
2. monitor-sprint-plan-updates が Google Drive 監視
   → sprint{N}_*_final.md を検出
   → docs/ に保存
   ↓
3. Designer Agent (Opus)
   → docs/design/sprint{N}_designer_plan.md を新規作成
   ↓
4. Architect Agent (Opus)
   → docs/requirements/REQUIREMENTS_SPRINT_{N}.md を新規作成
   → 旧 req_econ_*.md に廃止マーク追記（if exists）
   ↓
5. CEO or Skill
   → docs/tasks/codex_request_sprint{N}.md を生成
   ↓
6. ユーザー承認
   → Codex へ dispatch
```

**重要：**
- 旧ファイル廃止マーク追記は Architect の必須手順（agent.md に明記済み）
- Codex に投げる前に Sakurai ゲート（Phase 1.5）を通す

---

### シーン2：既存 Sprint の要件が仕様変更で修正される

```
1. ユーザーが「〇〇を変更したい」と指示
   ↓
2. Architect が該当 REQUIREMENTS_SPRINT_{N}.md を直接編集（新ファイル作成禁止）
   → 冒頭「更新日」をリセット
   → 変更箇所を明記（行番号 or セクション）
   ↓
3. 該当 req_econ_*.md が存在する場合、廃止マーク記入
   （REQUIREMENTS_SPRINT_{N} が SSoT になったため）
   ↓
4. CEO が修正内容を確認 → Sakurai レビュー（/sakurai-review）
   ↓
5. 承認後 Codex へ再依頼
```

**禁止：** 新ファイル作成（req_econ_***_v2.md のような派生ファイルは作らない）

---

### シーン3：旧ドキュメントを参考にしたい

```
旧ファイルの先頭に STATUS: 廃止 があれば参考のみ
REQUIRES_SPRINT_*.md / codex_request_sprint*.md / sprint*_final.md を参照
```

---

## 廃止対象ファイル（2026-05-04 実施済み）

以下のファイルは **`docs/requirements/archive/`、`docs/tasks/archive/`** に移動済み。
実装・CEO が参照禁止。Git 履歴として保持。

### 個別要件ファイル（req_econ_*.md など・計26ファイル）

移動先：`docs/requirements/archive/req_*.md`

**参照禁止理由：** `REQUIREMENTS_SPRINT_{N}.md` が SSoT に統一された。旧ファイルは参考のみ。

### 旧実装依頼ファイル（codex_request_sprint3-6・計5ファイル）

移動先：`docs/tasks/archive/codex_request_sprint{N}_old.md`

**参照禁止理由：** 最新のファイルは `codex_request_sprint{N}.md`（archive フォルダの外）

---

## 実装・CEO・Checker のファイル参照ルール

| 役割 | 参照すべきファイル | 参照禁止 |
|-----|------------------|---------|
| **Implementer（実装）** | • REQUIREMENTS_SPRINT_{N}.md（SSoT） | • req_econ_*.md（旧） |
| | • codex_request_sprint{N}.md | • GAME_DESIGN.md（旧 v0.1） |
| | • GAME_DESIGN_V0_2_MVP.md | • 他の旧ファイル |
| **CEO** | • REQUIREMENTS_SPRINT_{N}.md | • req_econ_*.md（旧） |
| | • sprint{N}_*_final.md（企画） | • GAME_DESIGN.md（旧 v0.1） |
| | • roadmap.md（進捗） | |
| **Checker** | • codex_result_sprint{N}.md（実装報告） | • req_econ_*.md（旧） |
| | • REQUIREMENTS_SPRINT_{N}.md（検証基準） | • 旧設計ファイル |
| | • GAME_DESIGN_V0_2_MVP.md | |

---

## チェックリスト：この定義を遵守するための実装手順

### 直ちに実施（全員必須）

- [ ] このファイルを `.claude/` に保存済みである（agent・CEO・implementer が参照可能）
- [ ] このファイルを CLAUDE.md 「参照すべきファイル」セクションに追加
- [ ] 全26個の旧 req_econ_*.md ファイルの先頭に `STATUS: 廃止（→ ...）` を追記
- [ ] 旧 GAME_DESIGN.md の先頭に `STATUS: 廃止（→ GAME_DESIGN_V0_2_MVP.md）` を記入
- [ ] Architect Agent 定義に「新要件定義書作成時は旧ファイルに廃止マーク追記」を追加（既済）
- [ ] これ以降、新しい req_*.md ファイルを作成しない

### 確認（CEO 責任）

- [ ] roadmap.md と最新 Sprint 企画が一致しているか
- [ ] codex_request_sprint{N}.md が対応する REQUIREMENTS_SPRINT_{N}.md を引用しているか
- [ ] Checker が古いファイルを参照していないか（参照禁止リスト共有）

### 継続（毎 Sprint）

- [ ] 新 Sprint 企画が来たら、Architect が REQUIREMENTS_SPRINT_{N}.md を作成する際に廃止マーク追記を実行
- [ ] 実装依頼は REQUIREMENTS_SPRINT_{N} から直接引用する（独立した req_*.md は作らない）

---

## FAQ

**Q: 旧 req_econ_*.md ファイルは削除すべき？**  
A: いいえ。Git 履歴を保持するため削除しません。先頭に廃止マーク記入のみ。

**Q: REQUIREMENTS_V0_2_MVP.md の役割は？**  
A: Sprint ごと REQUIREMENTS_SPRINT_{N}.md の統合版。Phase 完了時に全 Sprint 要件を1ファイルで検証したいときに使用。個別更新は REQUIREMENTS_SPRINT_{N} で実施。

**Q: 修正依頼が来たときは？**  
A: 新ファイル（req_econ_***_fix.md）を作らず、該当 REQUIREMENTS_SPRINT_{N}.md を直接編集。更新日をリセット。

**Q: Codex への実装依頼の根拠は何？**  
A: codex_request_sprint{N}.md。ただし、その根拠は REQUIREMENTS_SPRINT_{N}.md の引用で明記。req_econ_*.md からの引用は禁止。

---

## 自動検査ルール（check_syntax.sh に統合）

### Codex 依頼の検査

`check_syntax.sh` に以下の検査を追加（2026-05-04実施済み）：

```bash
# 廃止ファイル参照チェック
for req_file in docs/tasks/codex_request_sprint*.md; do
  if grep -q "archive/" "$req_file"; then
    echo "❌ FATAL: $req_file に廃止ファイル参照"
    exit 1
  fi
  if grep -qE "req_econ_|req_economy_|req_enemyless_" "$req_file"; then
    echo "❌ WARNING: 個別要件ファイル参照"
    exit 1
  fi
done
```

**実行タイミング：**
- Codex 依頼ファイル作成後
- git commit 前
- Codex dispatch 前

**失敗時の対応：**
- 廃止ファイル参照を削除
- `REQUIREMENTS_SPRINT_{N}.md` からの直接引用に置き換え
- 修正後に check_syntax.sh を再実行

---

## 次のアクション

1. **即座（今セッション内）:** 
   - 旧 req_econ_*.md 26ファイルすべてに廃止マーク追記
   - GAME_DESIGN.md に廃止マーク追記
   - document_management.md を CLAUDE.md に追加

2. **確認タスク（PMO 責任）:** 
   - git status で廃止マーク追記ファイル確認
   - roadmap.md と最新 Sprint 番号の一致確認

3. **次 Sprint 時：** 
   - このプロセスを厳格に遵守
   - Architect が廃止マーク追記を自動実行
   - Codex request は REQUIREMENTS_SPRINT_{N} 引用を必須チェック
