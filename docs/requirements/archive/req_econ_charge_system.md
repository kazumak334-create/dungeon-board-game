STATUS: 廃止（→ docs/requirements/REQUIREMENTS_SPRINT_7.md）
最終更新: 2026-05-04

# 要件定義書: EconMVP 一斉突撃システム

更新日: 2026-05-01 (rev2: スタック上限チェック追加)
STATUS: Draft

企画書: ユーザー指示 2026-05-01

---

## 0. スコープ

EconMVP に「一斉突撃システム」を追加する。

### 核となる体験との整合性
- アイドリング→一斉突撃の瞬間が「配分の答え合わせ」体験を強化する
- KISS原則: is_idle 1フィールド追加で既存の自動突撃ロジックを再利用

### 対象ファイル
- scripts/econ_mvp/EconUnit.gd（363行）
- scripts/econ_mvp/EconMain.gd（1012行）
- scripts/econ_mvp/EconBattle.gd（147行）
- scripts/econ_mvp/EconAI.gd（142行）
- scripts/econ_mvp/EconGrid.gd（集結点描画のみ）

---

## 1. EconUnit.gd への変更

### 1-1. is_idle フィールド追加

変更箇所: 26行目（var is_alive: bool = true の直後）

追加コード:
    var is_idle: bool = true
    var _spawn_building_pos: Vector2i = Vector2i(-1, -1)

### 1-2. update() 関数シグネチャ変更

74行目のシグネチャを変更:
    func update(delta: float, enemies: Array, enemy_buildings: Array, enemy_harvesters: Array, grid: EconGrid, all_units: Array, economy: EconEconomy = null, rally_point: Vector2i = Vector2i(-1, -1)) -> void:

### 1-3. update() 内アイドリング分岐

_select_target() 呼び出し（103行目）の直前に挿入:
    if is_idle:
        if rally_point != Vector2i(-1, -1) and grid_pos != rally_point:
            _try_move_toward(delta, grid, all_units, rally_point)
        return

注意: returnで抜けることで攻撃・ターゲット選択をスキップ。
空腹システム（79-94行目）はreturnより前なので継続動作する。

### 1-4. _draw() アイドリングアイコン追加

338行目 draw_circle(Vector2.ZERO, 18.0, _unit_color) の後に追加:
    if is_idle:
        draw_circle(Vector2(12, -12), 5.0, Color(1.0, 1.0, 1.0, 0.85))

---

## 2. EconBattle.gd への変更

### 2-1. player_rally_point フィールド追加

19行目（is_running フィールド）の後に追加:
    var player_rally_point: Vector2i = Vector2i(-1, -1)

### 2-2. spawn_player_unit() 変更

シグネチャ変更:
    func spawn_player_unit(col: int, row: int, unit_type: int, charge_mode: bool = false) -> void:

unit.position 設定後（97行目）、player_units.append(unit) の前に追加:
    unit.is_idle = not charge_mode
    unit._spawn_building_pos = Vector2i(col, row)

### 2-3. spawn_enemy_unit() 変更

enemy_units.append(unit)（119行目）の前に追加:
    unit.is_idle = true
    unit._spawn_building_pos = pos

### 2-4. update() player_units ループ変更

55行目を変更:
現在:
    u.update(delta, enemy_units, enemy_buildings, enemy_harvesters, grid, all_units, economy)
変更後:
    u.update(delta, enemy_units, enemy_buildings, enemy_harvesters, grid, all_units, economy, player_rally_point)

---

## 3. EconGrid.gd への変更（集結点描画）

### 3-1. rally_point フィールド追加

既存フィールド群末尾に追加:
    var rally_point: Vector2i = Vector2i(-1, -1)

### 3-2. _draw() 末尾に集結点描画追加

    if rally_point != Vector2i(-1, -1):
        var rpx: Vector2 = hex_to_pixel(rally_point.x, rally_point.y)
        draw_string(ThemeDB.fallback_font, rpx + Vector2(-10, 8), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)

注意: 絵文字の代わりに "F"（Flag略）を使用（フォント互換性のため）

---

## 4. EconAI.gd への変更

### 4-1. フィールド追加

_diag_timer の後に追加:
    var _ai_charge_timer: float = 0.0
    var _player_charged: bool = false
    const AI_COUNTER_DELAY: float = 20.0

### 4-2. update() カウンターロジック追加

update() 冒頭（while _construction_queue より前）に追加:
    # カウンター突撃ロジック
    if not _player_charged:
        for pu in _battle.player_units:
            if pu.is_alive and not pu.is_idle and pu.grid_pos.x > 8:
                _player_charged = true
                _ai_charge_timer = 0.0
                break
    if _player_charged:
        _ai_charge_timer += delta
        var enemy_alive: int = _battle.enemy_units.filter(func(u): return u.is_alive).size()
        var player_alive: int = _battle.player_units.filter(func(u): return u.is_alive).size()
        if _ai_charge_timer >= AI_COUNTER_DELAY or enemy_alive >= player_alive:
            _player_charged = false
            for eu in _battle.enemy_units:
                if eu.is_alive and eu.is_idle:
                    eu.is_idle = false
            _battle.log_message.emit("Enemy: Counter Charge!")

---

## 5. EconMain.gd への変更

### 5-1. フィールド追加

_place_hint_label フィールドの後に追加:
    var _charge_mode: bool = false
    var _rally_point: Vector2i = Vector2i(-1, -1)
    var _charge_btn: Button = null

### 5-2. _input() 右クリック処理追加

変更箇所: 693行目（if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT の行）を置き換え:
    if not event.pressed:
        return
    if event.button_index == MOUSE_BUTTON_RIGHT:
        var local_pos2: Vector2 = _grid.to_local(get_global_mouse_position())
        var rcell := _pixel_to_hex(local_pos2)
        if rcell != Vector2i(-1, -1):
            _rally_point = rcell
            _battle.player_rally_point = rcell
            _grid.rally_point = rcell
            _grid.queue_redraw()
            _add_log("Rallying at (%d,%d)" % [rcell.x, rcell.y])
        return
    if event.button_index != MOUSE_BUTTON_LEFT:
        return

### 5-3. 旗ボタン UI 追加

_setup_ui() 内、205行目の btn_start_hdr の前に追加:
    var hdr_vsep4 := VSeparator.new()
    hdr_vsep4.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hdr_hbox.add_child(hdr_vsep4)
    _charge_btn = Button.new()
    _charge_btn.text = "[Wait] Idle"
    _charge_btn.pressed.connect(_on_charge_btn_pressed)
    hdr_hbox.add_child(_charge_btn)

### 5-4. _on_charge_btn_pressed() 関数追加

_on_start_pressed() の直後（687行目）に追加:
    func _on_charge_btn_pressed() -> void:
        _charge_mode = not _charge_mode
        if _charge_mode:
            _charge_btn.text = "[Atk] CHARGE!"
            for u in _battle.player_units:
                if u.is_alive and u.is_idle:
                    u.is_idle = false
            _add_log("ALL CHARGE!")
        else:
            _charge_btn.text = "[Wait] Idle"
            _add_log("Idle mode (new units will wait)")

### 5-5. unit_produced コールバック修正

_place_building() 内のラムダ（847行目）を変更:
現在:
    _battle.spawn_player_unit(pos.x, pos.y, utype)
変更後:
    _battle.spawn_player_unit(pos.x, pos.y, utype, _charge_mode)

---

## 6. 制約・注意事項

- 生産建物ごとスタック上限3体のチェックロジック: **実装済み**（バグ修正 2026-05-01）
  - charge_mode=true時はチェックをスキップ（突撃モードは制限なし）
  - charge_mode=false時はidle_count >= EconGrid.MAX_STACK(=3)ならスポーンしない
- 集結点の六角形展開は現フェーズ実装しない
- 実装後は bash check_syntax.sh でエラー0件を確認すること

---

## 7. 実装順序

1. EconUnit.gd: is_idle フィールド + update() アイドリング分岐 + _draw() アイコン
2. EconBattle.gd: player_rally_point フィールド + spawn_*_unit 変更 + update() ループ変更
3. EconGrid.gd: rally_point フィールド + _draw() 集結点描画
4. EconAI.gd: フィールド追加 + update() カウンターロジック
5. EconMain.gd: フィールド追加 + _input() 右クリック + 旗ボタン + コールバック修正
