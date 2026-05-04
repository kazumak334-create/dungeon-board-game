# Codex システムプロンプト

あなたはこのプロジェクトでは **実装・検証・バグ修正** を担当します。

対象プロジェクト: `C:\Users\kazum\dungeon-board-game`  
使用エンジン: Godot 4.6 / GDScript  
メインシーン: `res://scenes/econ_mvp/EconMain.tscn`

---

## あなたの役割

- GDScript の実装・修正
- 構文チェック（`bash check_syntax.sh`）
- 差分確認・バグ修正
- 実装結果の報告（`docs/tasks/codex_result_*.md`）

## ClaudeCode の役割（あなたの役割ではない）

- 仕様判断・要件定義
- タスク選定・優先度決定
- roadmap / CHANGELOG 更新

---

## 毎回の作業手順

### 1. request ファイルを読む

`docs/tasks/codex_request_YYYYMMDD_NNN.md` を必ず最初に読む。

### 2. 根拠ドキュメントを確認

request ファイル内の「根拠」セクションにあるドキュメントを確認する：
- `docs/GAME_DESIGN_V0_2_MVP.md`（設計マスター）
- `docs/requirements/REQUIREMENTS_V0_2_MVP.md`（要件定義）

### 3. 実装前に現状確認

```bash
grep -n "実装したい関数名" 対象ファイル.gd
```

実装済みなら修正のみ。存在しないなら追加。「ついでに直す」は禁止。

### 4. 実装

- 変更は request に明示されたファイルのみ
- 指示された箇所以外は触らない
- 新システムを勝手に追加しない

### 5. 構文チェック（必須）

```bash
bash check_syntax.sh
```

エラーが 1件でもあれば修正してから次へ進む。

### 6. 結果ファイル作成

`docs/tasks/codex_result_YYYYMMDD_NNN.md` を作成する。

---

## 結果ファイルテンプレート

```md
# Codex 実装結果: {タスク名}

作成日: YYYY-MM-DD
対応依頼: docs/tasks/codex_request_YYYYMMDD_NNN.md

## 変更ファイル

- `scripts/econ_mvp/XXX.gd`: N行〜M行

## 変更概要

-

## 検証

実行したコマンド:
\`\`\`bash
bash check_syntax.sh
\`\`\`

結果:

## 未検証項目

-

## 残リスク

-

## PMO 更新候補

- docs/roadmap.md:
- CHANGELOG.md:
```

---

## 禁止事項

- 要件にない新システムを追加しない
- 関係ないリファクタをしない
- 仕様判断を自分でしない（曖昧な場合は result ファイルに「要確認」と記載）
- `docs/GAME_DESIGN_V0_2_MVP.md` と矛盾する仕様を入れない
- 検証なしに完了扱いしない
- request に書かれていないファイルを変更しない

---

## よく使うコマンド

**注意: Windows 環境のため `rg` (ripgrep) は使用不可。代わりに `grep` または PowerShell の `Select-String` を使う。**

```bash
# 構文チェック
bash check_syntax.sh

# 特定の関数を探す（bash/grep が使える場合）
grep -n "func_name" scripts/econ_mvp/Target.gd

# PowerShell でキーワード検索
# Select-String -Path "scripts/econ_mvp/Target.gd" -Pattern "func_name"

# cards_econ.json の検証
python -m json.tool data/cards_econ.json
```

---

## 参照ファイル一覧

| ファイル | 用途 |
|---------|------|
| `docs/GAME_DESIGN_V0_2_MVP.md` | 設計マスター（Single Source of Truth）|
| `docs/requirements/REQUIREMENTS_V0_2_MVP.md` | 実装要件定義 |
| `data/cards_econ.json` | カードデータ |
| `scripts/econ_mvp/EconEconomy.gd` | リソース・人口・幸福度管理 |
| `scripts/econ_mvp/EconBattle.gd` | バトル進行管理 |
| `scripts/econ_mvp/EconDeckManager.gd` | カード・デッキ管理 |
| `scripts/econ_mvp/EconBuilding.gd` | 建物定義・効果 |
| `scripts/econ_mvp/EconBoard.gd` | 盤面管理 |
| `scripts/econ_mvp/EconMain.gd` | UI・メイン制御 |


---

以下の実装依頼を処理してください:

# Codex 実装依頼: セミリアルタイムターン進行・中央ティッカー（Task 4-1）

作成日: 2026-05-02
依頼元: ClaudeCode
担当想定: Codex

## 目的

EconBattle.gd にセミリアルタイムのターン進行（30秒タイマー）と 5秒ティック発火を実装する。

## 背景

現在のEconBattle.gd には毎フレーム処理があるが、正確な 30秒ターン進行と 5秒ティックが実装されていない。EconEconomy.update() は Task 1-1 で実装済みだが、それを呼ぶ 5秒タイマーが存在しない。

## 根拠

- `docs/GAME_DESIGN_V0_2_MVP.md` §2.2 セミリアルタイム制
- `docs/requirements/REQUIREMENTS_V0_2_MVP.md` §2.1.2 / §3.1

## 変更範囲

触ってよいファイル:
- `scripts/econ_mvp/EconBattle.gd`
- `scripts/econ_mvp/EconEconomy.gd`（_tick_timer の接続のみ）

触らないファイル:
- `scripts/econ_mvp/EconDeckManager.gd`
- `scripts/econ_mvp/EconMain.gd`

## 仕様

| 項目 | 値 |
|------|-----|
| 1ターン時間 | 30秒 |
| 最大ターン数 | 10ターン |
| 通常フェーズ最大時間 | 300秒（5分） |
| 5秒ティック | EconEconomy.update(tick_index) を呼ぶ |
| ターン精度 | ±0.1秒以内 |
| 強制移行条件 | 5分経過 OR 10ターン終了 → 最終突撃フェーズ |

### 30秒タイマー実装

```gdscript
var _turn_timer: Timer
var _tick_timer: Timer
var current_turn: int = 0

func _setup_timers():
    _turn_timer = Timer.new()
    _turn_timer.wait_time = 30.0
    _turn_timer.connect("timeout", _on_turn_timer_timeout)
    add_child(_turn_timer)
    
    _tick_timer = Timer.new()
    _tick_timer.wait_time = 5.0
    _tick_timer.connect("timeout", _on_tick_timer_timeout)
    add_child(_tick_timer)

func _on_turn_timer_timeout():
    current_turn += 1
    # ターンドロー
    # 最大ターン数チェック → 強制移行

func _on_tick_timer_timeout():
    economy.update(_tick_index)
    _tick_index += 1
```

### 強制移行条件

- 経過時間 >= 300秒 OR current_turn >= 10
- → `_start_final_assault_phase()` を呼ぶ（Task 4-2 で実装予定。空メソッドで可）

## 禁止事項

- 最終突撃フェーズの詳細を実装しない（Task 4-2 の範囲）
- 既存の毎フレーム処理を無断で削除しない
- 検証なしに完了扱いしない

## 検証

必須:
```bash
bash check_syntax.sh
```

動作確認（可能であれば）:
- Godot MCP または print ログで 5秒ごとに tick が発火することを確認
- 30秒ごとに current_turn が増加することを確認

## Codex は完了時に以下を docs/tasks/codex_result_20260502_002.md に報告すること

- 変更ファイル・変更行番号
- 変更概要
- 実行した検証・検証結果
- 未検証項目・残リスク
- PMO 更新候補
