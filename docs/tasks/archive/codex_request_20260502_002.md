STATUS: 廃止（→ docs/tasks/archive/）
最終更新: 2026-05-04

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
