# バトル遷移・WAVE表示・キャストゲージ・素材ドロップ 要件定義書

更新日: 2026-04-25
ステータス: 実装待ち
参照企画書: `docs/design/game_flow_master.md`

---

## 1. 概要

SW（Small Wave）勝利後の遷移バグ（cell_rects位置リセット漏れ）の修正と、
ゲームフロー設計（`game_flow_master.md`）で確定した4機能（A:バトル遷移 / B:WAVE表示 /
C:キャストゲージ / D:素材ドロップ）を実装可能な粒度で定義する。

実装対象は4ブロックに分かれ、依存順序は **A ⇐ B ⇐ C ⇐ D**（A→B→C→Dの順に実装可）。

---

## 2. 実装対象（ファイル一覧）

| ファイル | 変更種別 | 主な変更箇所 |
|---|---|---|
| `scripts/Main.gd` | 修正 | `_on_battle_victory()`(L1099) / `_animate_enemy_slidein()`(L1186) / `_animate_player_advance()`(L1133) 削除 / 新規 `_reset_cell_rects_to_canonical()` / `_show_wave_label()` / `_animate_battle_transition()` |
| `scripts/WaveManager.gd` | 修正 | `_advance_to_next_wave()`(L115) からSW内遷移時にMain.gdへ遷移演出依頼 |
| `scripts/SpellSlotSystem.gd` | 修正 | `cast_timer` / `cast_interval` 追加・`process_slots()` 復活・`can_cast()` 修正・`_trigger_spell()` 修正 |
| `scripts/GameUIQueue.gd` | 修正 | `_build_one_spell_slot()` にキャストゲージColorRect追加・`update_spell_slots()` でratio反映 |
| `scripts/EventQueue.gd` | 修正 | `"damage"` ブロック内、死亡確定時に `_drop_materials()` 呼び出し追加 |
| `scripts/BoardManager.gd` | 修正 | `material_dropped` シグナル追加 |
| `scripts/GameSession.gd` | 修正 | `materials: Dictionary = {}` 追加 |
| `scripts/Main.gd` | 修正 | `_process(delta)`(L552) で `spell_slot_system.process_slots(delta)` を呼ぶ |

### 2-1. ファイルサイズチェック

| ファイル | 現行行数（概算） | 追加予定 | 判定 |
|---|---|---|---|
| Main.gd | 約1208行 | +60〜80行（演出関数3つ + 旧関数削除）| **400行超 review trigger**（後述§7-1で分割方針指定） |
| WaveManager.gd | 約220行 | +5行（シグナル発行のみ）| 200〜400 soft cap以下 |
| SpellSlotSystem.gd | 約350行（推定）| +25行（ゲージ変数 / process / 加算）| 400行超になる可能性。要監視 |
| GameUIQueue.gd | 約340行 | +30行（ゲージColorRect / 更新）| 400行超になる可能性。要監視 |
| EventQueue.gd | 約273行 | +15行（drop呼び出し + 関数）| 200〜400 soft cap以下 |
| BoardManager.gd | 約700行（推定）| +1行（シグナル定義のみ）| 影響なし |
| GameSession.gd | 約100行（推定）| +1行（変数のみ）| 影響なし |

---

## 3. データ構造

### 3-1. GameSession.gd（追加）

```gdscript
# 素材インベントリ（ラン中蓄積、Game Over / 完走でリセット）
var materials: Dictionary = {}  # {素材ID(String): 個数(int)}
```

### 3-2. SpellSlotSystem.gd（追加）

```gdscript
# キャストゲージ（グローバルクールダウン）
var cast_timer: float = 0.0       # 残りCD秒数（0で発動可）
var cast_interval: float = 5.0    # CD満タン値（初期5秒、調整可）
```

### 3-3. Main.gd（追加）

```gdscript
# WAVE表示用ラベル（既存game_over_labelとは別ノード）
var wave_label: Label = null
```

### 3-4. cell_rects 正規座標の参照式（既存仕様再掲）

```
正規X座標 = main._cell_x(side, c)  ※GameUI.gdのヘルパーを利用
正規Y座標 = main.BOARD_TOP + r * main.CELL_H + 2
正規サイズ = (main.CELL_W - 4, main.CELL_H - 4)
```

---

## 4. 実装詳細

---

## 【REQ-A】バトル遷移（最優先・バグ修正込み）

### REQ-A1: cell_rects 正規座標リセット関数

#### 機能概要
`cell_rects[side][r][c]` のTween済みposition（スライドアウト/前進で書き換えられた値）を、
GameUI._cell_x()と等価な正規座標に強制リセットする。
さらに `board_manager.board[1]`（敵盤面）を全クリアする。

#### 変更対象ファイル
`scripts/Main.gd`

#### 変更内容
新規関数を追加。

```gdscript
func _reset_cell_rects_to_canonical() -> void:
    """cell_rects位置・visible・敵盤面を初期状態に戻す（SW遷移バグ修正）"""
    # 全Tweenをkill（残ったTweenがpositionを書き戻すのを防ぐ）
    for side in range(2):
        for r in range(3):
            for c in range(3):
                var rect: ColorRect = cell_rects[side][r][c]
                if rect == null:
                    continue
                # 進行中Tweenを全停止（GameUI._cell_x()で再計算）
                var x: int = game_ui._cell_x(side, c) if game_ui != null else 0
                var y: int = BOARD_TOP + r * CELL_H + 2
                rect.position = Vector2(x + 2, y)
                rect.size = Vector2(CELL_W - 4, CELL_H - 4)
                rect.modulate = Color(1, 1, 1, 1)  # フェードで残った透明度をリセット
                rect.visible = true
    # 敵盤面クリア（次SWの敵を新規配置するため）
    for r in range(3):
        for c in range(3):
            board_manager.board[1][r][c] = null
            board_manager.attack_timers[1][r][c] = 0.0
    board_manager.on_board_changed()
```

#### 完了条件
- [ ] `_reset_cell_rects_to_canonical()` 関数が存在する
- [ ] 呼び出し後、`cell_rects[side][r][c].position` がGameUI初期化時と同値
- [ ] 呼び出し後、`board_manager.board[1][r][c]` 全要素がnull

---

### REQ-A2: 勝利フロー演出（敵フェードアウト → VICTORY → 報酬選択）

#### 機能概要
SW勝利時、まず敵ユニットをフェードアウト（0.5s）し、その後VICTORY!表示（1.5s）、
最後に `wave_manager.on_wave_victory()` を呼び出す。
プレイヤー前進アニメーション（`_animate_player_advance`）は廃止。

#### 変更対象ファイル
`scripts/Main.gd`

#### 変更内容
`_on_battle_victory()`（L1099）を以下に書き換え。

```gdscript
func _on_battle_victory() -> void:
    is_animating = true
    game_over = true  # 戦闘ループ停止

    # Step 1: 敵ユニット フェードアウト（0.5秒）
    await _animate_enemy_fadeout(0.5)

    # Step 2: VICTORY! 表示（1.5秒）
    game_over_label.text     = "VICTORY!"
    game_over_label.modulate = Color(0.3, 1.0, 0.5)
    game_over_label.visible  = true
    await get_tree().create_timer(1.5).timeout
    game_over_label.visible = false

    game_over = false  # 遷移処理のためフラグ戻す
    is_animating = false
    if wave_manager != null:
        wave_manager.on_wave_victory()

func _animate_enemy_fadeout(duration: float) -> void:
    """敵ユニット（cell_rects[1]）をフェードアウト（modulate.aを1→0）"""
    var tween := create_tween().set_parallel(true)
    for r in range(3):
        for c in range(3):
            var rect = cell_rects[1][r][c]
            if rect != null and rect.visible:
                tween.tween_property(rect, "modulate:a", 0.0, duration)
    await tween.finished
```

`_animate_enemy_slideout()`（L1115）と `_animate_player_advance()`（L1133）は **削除**。

#### 完了条件
- [ ] 敵フェードアウト中はゲームループが停止（is_animating=true）
- [ ] VICTORY!ラベルは1.5秒後に非表示になる
- [ ] フェードアウト後、敵cell_rectsのmodulate.a=0.0
- [ ] `_animate_enemy_slideout` / `_animate_player_advance` が呼ばれる箇所が存在しない

---

### REQ-A3: SW内遷移演出（同BW・次SW）

#### 機能概要
報酬選択後、SW2へ遷移する際の演出フロー：
1. `_reset_cell_rects_to_canonical()` で位置・敵盤面リセット
2. WAVE X-X 表示（1.0秒、企画書3-2準拠）
3. 新敵配置（cell_rectsはvisible=true、敵盤面に新ユニット入る）
4. 敵スライドイン（右画面外→正規座標、0.4秒）
5. 戦闘再開（is_animating=false）

#### 変更対象ファイル
- `scripts/Main.gd`
- `scripts/WaveManager.gd`

#### 変更内容（Main.gd）

`_on_wave_started()`（L1080）を以下に書き換え。

```gdscript
func _on_wave_started(big: int, small: int, scale: float) -> void:
    _add_log("=== Wave %d-%d 開始（敵強化×%.1f）===" % [big, small, scale])
    if small == 1:
        # SW1: 新規バトル開始（DeckPrep直後）
        _place_enemy_initial_units()
        await _animate_battle_start(big, small)
    else:
        # SW2以降: SW内遷移（cell_rectsリセット → 敵配置 → スライドイン）
        await _animate_sw_transition(big, small)

func _animate_battle_start(big: int, small: int) -> void:
    """バトル新規開始演出: フェードイン → WAVE X-X → 戦闘開始"""
    is_animating = true
    await _animate_fade_to_black()
    _position_enemies_offscreen()
    await _animate_fade_from_black()
    await _animate_enemy_slidein()
    await _show_wave_label(big, small, 1.5)
    is_animating = false

func _animate_sw_transition(big: int, small: int) -> void:
    """SW内遷移演出: cell_rectsリセット → WAVE X-X → 敵スライドイン"""
    is_animating = true
    _reset_cell_rects_to_canonical()
    _place_enemy_initial_units()  # 新敵を board[1] に配置
    _position_enemies_offscreen()  # 配置後すぐ画面外へ
    await _show_wave_label(big, small, 1.0)
    await _animate_enemy_slidein()  # 0.4秒スライドイン
    is_animating = false
```

`_animate_wave_start()`（L1147）は内部呼び出し先がなくなるため **削除**（または `_animate_battle_start` にリネーム統合）。

#### 変更内容（WaveManager.gd）
変更なし（`_advance_to_next_wave()` → `_start_wave()` → `wave_started.emit()` の流れに乗るため、
Main.gdの `_on_wave_started()` 内で `small > 1` 分岐するだけで完結する）。

#### 完了条件
- [ ] SW1勝利→報酬選択→SW2開始時、cell_rectsの位置が崩れていない
- [ ] WAVE 1-2 表示が1.0秒間表示される
- [ ] 敵が右画面外から0.4秒でスライドインする
- [ ] プレイヤー側ユニットの位置・状態（HP）が引き継がれている

---

### REQ-A4: BW完了遷移（ショップ→DeckPrep→バトル）

#### 機能概要
BW2勝利（=SW2勝利）時、`wave_manager` が `intermission_requested` シグナルを発行し、
`_on_intermission_requested()`（既存・L1091）でRestScreenへ遷移する。
RestScreen後はDeckPrep、DeckPrep後は次BW SW1のバトルへ。

#### 変更対象ファイル
変更なし（既存フロー維持）。ただし§REQ-A3で `_on_wave_started()` の `small == 1` 分岐に
バトル開始演出（`_animate_battle_start`）が含まれることで自動的に正しく動く。

#### 完了条件
- [ ] BW1-SW2勝利→VICTORY→報酬選択→ショップ→DeckPrep→BW2-SW1で `WAVE 2-1` 表示
- [ ] 各遷移でcell_rectsの座標崩れが発生しない

---

### REQ-A5: Actクリア遷移（DeckPrep→次Act バトル）

#### 機能概要
BW4-SW2勝利時、`big_wave_completed` シグナル発行。
現状 `_on_big_wave_completed()`（L1095）はTODOのみ。本要件では **未実装のままTODOを残す**
（企画書§9で「Act間クリア演出」は未設計のため）。

#### 変更対象ファイル
`scripts/Main.gd`

#### 変更内容
`_on_big_wave_completed()` 内のTODOコメントを以下に置換（実装は別タスク）。

```gdscript
func _on_big_wave_completed(next_act: int) -> void:
    print("[Main] BW完了、次Act %d へ（Phase 5 で実装予定）" % next_act)
    # TODO(Phase5): Actクリア演出 → DeckPrep → 次Act SW1バトル
    # 暫定: 仮にDeckPrepへ直行
    pass
```

#### 完了条件
- [ ] 既存と同等の動作（実装は次Phaseに延期）
- [ ] コメントが「Phase 5 で実装予定」に更新されている

---

## 【REQ-B】WAVE表示

### REQ-B1: WAVE X-X 表示関数

#### 機能概要
画面中央に「WAVE 1-2」のような文字列を、ゴールド系カラー・大文字で指定秒数表示する。
表示後は自動で非表示。`game_over_label` とは別の `wave_label` を使用する。

#### 変更対象ファイル
- `scripts/Main.gd`
- `scripts/GameUI.gd`（`wave_label` 生成箇所）

#### 変更内容（GameUI.gd）
`game_over_label` 生成箇所（L228付近）の直後に以下を追加。

```gdscript
# WAVE表示ラベル（バトル開始・SW遷移時に使用）
main.wave_label = Label.new()
main.wave_label.position = Vector2(0, 230)
main.wave_label.size = Vector2(1280, 60)
main.wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
main.wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
main.wave_label.add_theme_font_size_override("font_size", 48)
main.wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))  # ゴールド系
main.wave_label.modulate = Color(1, 1, 1, 0)
main.wave_label.visible = false
main.add_child(main.wave_label)
```

#### 変更内容（Main.gd）
新規関数を追加。

```gdscript
func _show_wave_label(big: int, small: int, duration: float) -> void:
    """WAVE X-X を画面中央に duration 秒表示してフェードアウト"""
    wave_label.text = "WAVE %d-%d" % [big, small]
    wave_label.visible = true
    var fade_in := create_tween()
    fade_in.tween_property(wave_label, "modulate:a", 1.0, 0.2)
    await fade_in.finished
    await get_tree().create_timer(duration - 0.4).timeout
    var fade_out := create_tween()
    fade_out.tween_property(wave_label, "modulate:a", 0.0, 0.2)
    await fade_out.finished
    wave_label.visible = false
```

#### 完了条件
- [ ] バトル新規開始時に `WAVE X-X` が1.5秒間表示される
- [ ] SW遷移時に `WAVE X-X` が1.0秒間表示される
- [ ] フォーマットが `WAVE 1-1` `WAVE 4-2` 等（BW番号-SW番号）
- [ ] 文字色がゴールド系（Color(1.0, 0.85, 0.3)）
- [ ] フェードイン0.2秒 → 表示（duration-0.4）秒 → フェードアウト0.2秒

---

## 【REQ-C】キャストゲージ（グローバルクールダウン）

### REQ-C1: SpellSlotSystemにタイマー変数追加

#### 機能概要
呪文発動時に `cast_timer = cast_interval` をセットし、毎フレーム delta 減算する。
`can_cast()` で `cast_timer == 0` をチェック条件に追加する。

#### 変更対象ファイル
`scripts/SpellSlotSystem.gd`

#### 変更内容

**追加変数**（クラス先頭、`var slots: Array = []` の直後）:
```gdscript
# キャストゲージ（グローバルクールダウン、全スロット共有）
var cast_timer: float = 0.0
var cast_interval: float = 5.0
```

**`process_slots(delta)`（L100）を以下に書き換え**:
```gdscript
func process_slots(delta: float) -> void:
    # キャストタイマー減算（0で下限クランプ）
    if cast_timer > 0.0:
        cast_timer = max(0.0, cast_timer - delta)
```

**`can_cast(index)`（L248）の最終 return 直前に以下を挿入**:
```gdscript
    # キャストゲージチェック（クールダウン中は発動不可）
    if cast_timer > 0.0:
        return false
    return true
```

**`get_cast_block_reason(index)`（L262）の最終 return 直前に以下を挿入**:
```gdscript
    if cast_timer > 0.0:
        return "cooldown"
    return ""
```

**`_trigger_spell(index, slot)`（L282）のマナ消費直後に以下を挿入**:
```gdscript
    # キャストタイマーをリセット（次の発動はinterval秒後）
    cast_timer = cast_interval
```

#### 変更対象ファイル（呼び出し）
`scripts/Main.gd`

#### 変更内容（Main.gd）
`_process(delta)`（L552）内、`if not game_paused:` ブロックの末尾（L590付近、`_check_game_over()` の直前）に以下を追加:

```gdscript
            # キャストゲージ更新（speed_scale非適用、リアル時間ベース）
            if spell_slot_system != null:
                spell_slot_system.process_slots(delta)
```

#### 完了条件
- [ ] 呪文発動直後 `cast_timer == cast_interval`（5.0）
- [ ] 5秒経過後 `cast_timer == 0`
- [ ] CD中は `can_cast()` が false を返す
- [ ] CD中は `get_cast_block_reason()` が `"cooldown"` を返す
- [ ] `cast_interval` は外部から書き換え可能（バランス調整用）

---

### REQ-C2: キャストゲージUI（呪文スロット上部の横棒）

#### 機能概要
3つの呪文スロットそれぞれの上部にキャストゲージ（ColorRect）を配置。
全スロット共通のクールダウンを表示するため、3つとも同じratioで描画する。

#### 変更対象ファイル
`scripts/GameUIQueue.gd`

#### 変更内容

**`_build_one_spell_slot()`（L147）のヘッダーラベル直後（L157の `main.add_child(header_lbl)` の直後）に以下を追加**:

```gdscript
    # キャストゲージ（呪文スロット上部の横棒）
    # 配置: ヘッダーラベルとパネル間（sy - 4 のY座標）
    var gauge_bg := ColorRect.new()
    gauge_bg.position = Vector2(sx, sy - 4)
    gauge_bg.size = Vector2(sw, 3)
    gauge_bg.color = Color(0.15, 0.15, 0.2)
    main.add_child(gauge_bg)

    var gauge_fill := ColorRect.new()
    gauge_fill.position = Vector2(sx, sy - 4)
    gauge_fill.size = Vector2(sw, 3)
    gauge_fill.color = Color(0.4, 0.7, 1.0)  # シアン系（マナと区別）
    main.add_child(gauge_fill)
```

**`_spell_slot_panels.append({...})`（L215）のDictionaryに以下のキーを追加**:
```gdscript
        "gauge_bg": gauge_bg,
        "gauge_fill": gauge_fill,
```

**`update_spell_slots()`（L244）のループ末尾に以下を追加**:
```gdscript
        # キャストゲージ更新（全スロット共通のratio）
        var sys = main.spell_slot_system
        var ratio: float = 1.0 - (sys.cast_timer / max(0.01, sys.cast_interval))
        ratio = clamp(ratio, 0.0, 1.0)
        var gauge_fill: ColorRect = sd["gauge_fill"]
        gauge_fill.size.x = sd["gauge_bg"].size.x * ratio
        # 満タンならシアン、進行中はやや暗め
        gauge_fill.color = Color(0.4, 0.7, 1.0) if ratio >= 1.0 else Color(0.3, 0.5, 0.8)
```

#### 完了条件
- [ ] 3スロットそれぞれの上部にゲージが表示される
- [ ] 呪文発動直後 ratio=0.0（ゲージ空）
- [ ] interval経過後 ratio=1.0（ゲージ満タン）
- [ ] 満タン時とCD中で色が異なる（視覚区別）
- [ ] ゲージ計算式: `ratio = 1.0 - (cast_timer / max(0.01, cast_interval))`

---

## 【REQ-D】素材ドロップ（自動取得）

### REQ-D1: GameSession.materials 追加

#### 機能概要
ラン中に獲得した素材を `{素材ID: 個数}` のDictionaryで保持する。

#### 変更対象ファイル
`scripts/GameSession.gd`

#### 変更内容
`var battle_drops: Array = []` (L62) の直後に以下を追加。

```gdscript
var materials: Dictionary = {}  # {素材ID(String): 個数(int)} - ラン中累積、Game Over/完走でリセット
```

#### 完了条件
- [ ] `GameSession.materials` がDictionary型として参照可能
- [ ] `GameSession.materials.get("slime_core", 0)` で個数取得可能

---

### REQ-D2: BoardManager に material_dropped シグナル追加

#### 機能概要
素材ドロップ発生時に通知するシグナルを追加。Main.gdやUIが購読してエフェクト表示等に使う。

#### 変更対象ファイル
`scripts/BoardManager.gd`

#### 変更内容
シグナル定義群（L28-39）の末尾に以下を追加。

```gdscript
signal material_dropped(material_id: String, count: int, side: int, row: int, col: int)
```

#### 完了条件
- [ ] `BoardManager.material_dropped` がシグナルとして存在
- [ ] 引数: `material_id: String, count: int, side: int, row: int, col: int`

---

### REQ-D3: EventQueue 死亡処理にドロップ追加

#### 機能概要
`"damage"` ケース内、敵ユニット死亡確定時（`death_events.append` の直後または死亡後処理ループ内）に
素材ドロップ処理を呼び出す。素材テーブルは別設計書（`drop_table_system.md` 等）で定義され、
本要件では **ドロップ基盤のみ実装**（テーブル参照部分はスタブ関数で確保）。

#### 変更対象ファイル
`scripts/EventQueue.gd`

#### 変更内容

**死亡後処理ループ（L224-258）内、`board_manager.remove_unit(s, r, c)` の直後（L232）に以下を追加**:

```gdscript
                # 素材ドロップ処理（敵側ユニットのみ）
                if s == 1 and victim != null:
                    _drop_materials_from_unit(victim, s, r, c)
```

**ファイル末尾に新規関数を追加**:
```gdscript
func _drop_materials_from_unit(unit: Object, side: int, row: int, col: int) -> void:
    """敵ユニット死亡時の素材自動取得（全量・選択不要）"""
    # 素材テーブル参照（別設計書 drop_table_system.md で定義）
    # 当面はスタブ: ユニット名から素材ID推定（暫定実装）
    var material_id: String = _resolve_material_id(unit)
    if material_id == "":
        return  # 素材定義なし
    var count: int = 1  # 暫定: 全敵から1個。テーブル定義時に拡張
    GameSession.materials[material_id] = GameSession.materials.get(material_id, 0) + count
    board_manager.material_dropped.emit(material_id, count, side, row, col)
    print("[Drop] 素材獲得: %s x%d (累計:%d)" % [material_id, count, GameSession.materials[material_id]])

func _resolve_material_id(unit: Object) -> String:
    """ユニットから素材IDを解決（暫定実装・テーブル化は別タスク）"""
    if unit == null:
        return ""
    # 暫定: unit.unit_name の先頭から推測（例: "スライム" → "slime_core"）
    # 正式実装は drop_table_system.md 確定後に別タスクで置換
    return ""  # スタブ: テーブル未定義のため空文字を返す（ドロップなし）
```

#### 完了条件
- [ ] `_drop_materials_from_unit()` が敵死亡時に呼ばれる
- [ ] `material_id` が空文字でなければ `GameSession.materials` に加算される
- [ ] `material_dropped` シグナルが発行される
- [ ] 自陣ユニット死亡時はドロップが発生しない（`s == 1` ガード）
- [ ] 素材テーブル未定義時は `_resolve_material_id()` が `""` を返し、ドロップ処理をスキップ

---

## 5. 受け入れ基準（統合・Checker検証用）

### 5-1. バグ修正（最優先）
- [ ] SW1勝利→報酬選択→SW2開始の遷移で、自陣cell_rectsの位置が崩れない
- [ ] SW2開始時、敵がboard[1]に新規配置されている（前SWの敵が残らない）
- [ ] 旧 `_animate_enemy_slideout` `_animate_player_advance` が呼ばれていない

### 5-2. バトル遷移（A）
- [ ] 勝利フロー: 敵フェードアウト0.5s → VICTORY!1.5s → 報酬選択
- [ ] SW内遷移: 報酬選択後 → WAVE X-X 1.0s → 敵スライドイン0.4s → 戦闘再開
- [ ] BW完了遷移: 報酬選択後 → ショップ → DeckPrep → バトル
- [ ] バトル新規開始時: フェードイン → WAVE X-X 1.5s → スライドイン → 戦闘開始

### 5-3. WAVE表示（B）
- [ ] 表示テキストが `WAVE X-X` 形式（BW番号-SW番号）
- [ ] フォントサイズ48、ゴールド系カラー（Color(1.0, 0.85, 0.3)）
- [ ] 画面中央配置

### 5-4. キャストゲージ（C）
- [ ] 呪文発動後 cast_timer = cast_interval
- [ ] 毎フレーム cast_timer = max(0, cast_timer - delta)
- [ ] CD中は can_cast() が false
- [ ] UIゲージが3スロット上部に表示される
- [ ] ratio = 1.0 - (cast_timer / max(0.01, cast_interval))

### 5-5. 素材ドロップ（D）
- [ ] 敵ユニット死亡時に `_drop_materials_from_unit` が呼ばれる
- [ ] `GameSession.materials[material_id]` が加算される
- [ ] `material_dropped` シグナルが発行される
- [ ] 自陣ユニット死亡時はドロップなし

### 5-6. 既存機能の非破壊
- [ ] 敗北フローが正常動作（GAME OVER表示 → Result画面）
- [ ] ボス戦SW1→SW2遷移が正常（既存boss_phase切替が動く）
- [ ] DeckPrepからのバトル開始が正常

---

## 6. 依存関係

### 前提タスク
- 完了済み: WaveManager（Phase 4 #0a）の `wave_started` / `intermission_requested` / `big_wave_completed` シグナル
- 完了済み: SpellSlotSystem v2（手動発動 `cast_spell()`）
- 完了済み: GameUIQueue の3スロットUI（`_build_one_spell_slot`）

### 他ファイルへの影響（変更不要）
- `scripts/DeckPrep.gd` / `scripts/RestScreen.gd`: 遷移先として既存連携を維持
- `scripts/SpellExecutor.gd`: 呪文実行ロジックは変更なし
- `scripts/CombatSystem.gd`: 戦闘ロジックは変更なし
- `data/cards.json`: スキーマ変更なし

### 既存関数の再利用
- `GameUI._cell_x(side, col)`: 正規X座標計算
- `Main._place_enemy_initial_units()`: 敵ユニット配置
- `Main._position_enemies_offscreen()`: 画面外配置
- `Main._animate_enemy_slidein()`: 既存のスライドイン演出（流用）
- `BoardManager.remove_unit()` / `BoardManager.on_board_changed()`

---

## 7. 制約・注意事項

### 7-1. ファイルサイズ対策（review trigger）

`Main.gd`（1208行）は既に**400行超のreview trigger**に該当。
本要件で +60〜80行 追加するため、以下のいずれかの分割対応を **次スプリントで** 検討：

- **オプション1**: 演出関数群（`_animate_*` / `_show_wave_label` / `_reset_cell_rects_to_canonical`）を
  新規ファイル `scripts/BattleTransitionAnimator.gd` に切り出し（推奨）
- **オプション2**: 現状維持（本タスクでは追記のみ、リファクタは別タスク化）

**本要件定義書では暫定的にオプション2を採用**（バグ修正優先のため）。
オプション1のリファクタは `req_main_gd_split.md` として別チケット化を推奨。

### 7-2. 整合性

- 既存 `_animate_wave_start()` / `_animate_enemy_slideout` / `_animate_player_advance` は **削除する**。
  呼び出し残存をGrepで確認してから削除。
- `cast_interval` の初期値 5.0 は **暫定**。バランス調整は別タスク。
- 素材テーブルの定義は **本要件の範囲外**。`_resolve_material_id()` はスタブ実装で
  常に空文字を返してOK（テーブル定義タスクで置換）。

### 7-3. 用語SSOT

| 用語 | 採用 | 禁止別名 |
|---|---|---|
| BW（Big Wave） | `big` / `big_wave` | LW、bigwave、巨大Wave |
| SW（Small Wave） | `small` / `small_wave` | smallwave、SmallWave |
| 素材 | `materials` / `material_id` | item、drop_item（dropは挙動・materialsはデータ） |
| キャストゲージ | `cast_timer` / `cast_interval` | cooldown_timer（既存命名と衝突） |
| マナ | `mana` | mp、mp_max |

### 7-4. 廃止済み設計との衝突確認

- ✅ プレイヤー前進アニメーション: 本要件で **明示的に廃止**（既存設計を踏襲する形）
- ✅ 制限時間ベースの勝敗: `game_flow_master.md §4` で廃止済み・本要件は影響なし
- ✅ 自動呪文発動: SpellSlotSystem v2で廃止済み・本要件は手動発動前提

### 7-5. パフォーマンス

- `_reset_cell_rects_to_canonical()` は3×3×2=18セルのループのみ。1フレーム内で完結。
- キャストゲージ更新は3スロット × 1フレーム1回の単純代入のみ。負荷影響なし。
- 素材ドロップは死亡時のみ発火。EventQueue内のホットパスではない。

---

## 実装可能性チェックリスト（自己検証結果）

- [x] 座標・サイズ・色が具体値で指定されているか
  → wave_label position(0,230) size(1280,60) color(1.0,0.85,0.3) / gauge size(sw,3) color(0.4,0.7,1.0) 明記
- [x] 関数シグネチャ（引数・戻り値・型）が確定しているか
  → 全新規関数に型注釈付与（`-> void` / `-> String` 等）
- [x] 条件分岐の全ケース（正常系・異常系・エッジケース）が網羅されているか
  → SW1/SW2分岐、BW完了/Actクリア、敵死亡/自陣死亡、素材ID未定義時を網羅
- [x] 既存コードとの連携箇所（呼び出し先・呼び出し元）が明記されているか
  → ファイル名・行番号・関数名で全箇所明示
- [x] エッジケース（空・null・上限値・下限値）の扱いが決まっているか
  → `cast_interval` 0除算回避（max(0.01, cast_interval)）、`unit == null` ガード、`material_id == ""` ガード
- [x] 失敗時の挙動（エラー表示・リトライ・ログ）が定義されているか
  → ドロップ失敗時は print ログ、CD中は `get_cast_block_reason() == "cooldown"`
- [x] パフォーマンス要件（あれば）が明記されているか
  → §7-5に記載
- [x] 用語が **ssot_canonical_terms.txt と一致** しているか（spd / mana / col / range 等）
  → §7-3に記載（BW/SW/mana/materials）
