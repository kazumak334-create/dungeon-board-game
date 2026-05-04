STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# 要件定義書 バッチC: トリガー実装

## 調査済み実装状況

| トリガー | 状況 |
|---|---|
| on_ally_death | EventQueue.gd 240行目に実装済み（追加不要） |
| _skill_timers | UnitData.gd 84行目にフィールド定義済み（追加不要） |
| on_crit | 未実装 |
| on_damaged | 未実装 |
| on_battle_start | 未実装 |
| passive | 未実装（alwaysと同様に処理） |
| timer | 未実装（_skill_timersフィールドは存在） |

## 実装対象ファイルと変更内容

### 1. SupportSystem.gd: passiveトリガー処理

変更箇所: apply_support_effects()内の trigger == "always" チェック（40行目付近）

変更内容:
- 変更前: `if skill.get("trigger", "") == "always":`
- 変更後: `if skill.get("trigger", "") in ["always", "passive"]:`

これにより Thornbeast(atk_by_thorn_stacks)とRageveil(on_ally_death_heal_and_buff)のpassiveトリガーが既存SupportSystemで処理される。

注意: on_ally_death_heal_and_buff はpassiveトリガーだが on_ally_death_trigger typeなので
EffectExecutor.gdのmatch typeブロックにも追加が必要（バッチBで対応）。
passiveトリガーの扱いとしては、always同様にSupportSystemで処理するが、
on_ally_death_triggerタイプはSupportSystem経由では発火しない（型が合わない）。
そのため Rageveil は別途 on_ally_death トリガーが実際の発火点になる（既実装）。

### 2. Main.gd: on_battle_startトリガー発火

変更箇所: _start_battle()関数の末尾（wave_manager.start_wave_mode()の前後）

追加コード:
```
# on_battle_start トリガー発火
if board_manager.effect_executor != null:
    for s in range(2):
        for r in range(3):
            for c in range(3):
                var u = board_manager.board[s][r][c]
                if u == null:
                    continue
                for skill in u.skills:
                    if skill.get("trigger", "") == "on_battle_start":
                        var merged_obs: Dictionary = skill.get("params", {}).duplicate()
                        if skill.has("target"):
                            merged_obs["target"] = skill["target"]
                        board_manager.effect_executor.execute(skill["effect_id"], merged_obs, {
                            "trigger": "on_battle_start", "side": s, "row": r, "col": c,
                            "source": u, "target": null, "damage": 0,
                            "board_manager": board_manager,
                            "deck_manager": deck_manager, "enemy_ai": enemy_ai,
                            "event_queue": board_manager.event_queue
                        })
```

挿入位置: _start_battle()の末尾、具体的には296行目の _add_log("=== バトル開始...") の直前。

### 3. CombatSystem.gd: on_critトリガー発火

変更箇所: _do_attack()内のis_criticalブロック（102行目付近）

クリティカル判定後（effective_atk *= 2 または *= 3 の直後）に追加:
```
# on_crit トリガー発火
if is_critical and not skip_on_hit:
    for skill_oc in attacker.skills:
        if skill_oc.get("trigger", "") == "on_crit":
            var merged_oc: Dictionary = skill_oc.get("params", {}).duplicate()
            if skill_oc.has("target"):
                merged_oc["target"] = skill_oc["target"]
            bm.effect_executor.execute(skill_oc["effect_id"], merged_oc, {
                "trigger": "on_crit", "side": side, "row": row, "col": col,
                "source": attacker, "target": null, "damage": 0,
                "board_manager": bm, "deck_manager": null,
                "enemy_ai": null, "event_queue": bm.event_queue
            })
```

### 4. EventQueue.gd: on_damagedトリガー発火

変更箇所: flush()内の"damage"ケース、take_damage後（62行目付近）

take_damage(dmg_value)の直後に追加:
```
# on_damaged トリガー発火
for skill_od in tgt.skills:
    if skill_od.get("trigger", "") == "on_damaged" and dmg_value > 0:
        var merged_od: Dictionary = skill_od.get("params", {}).duplicate()
        if skill_od.has("target"):
            merged_od["target"] = skill_od["target"]
        var t_side: int = ex.get("enemy_side", 0)
        var t_row: int = ex.get("row", 0)
        var t_col: int = ex.get("col", 0)
        var src_od = event["source"]
        board_manager.effect_executor.execute(skill_od["effect_id"], merged_od, {
            "trigger": "on_damaged", "side": t_side, "row": t_row, "col": t_col,
            "source": src_od, "target": tgt, "damage": dmg_value,
            "board_manager": board_manager, "deck_manager": board_manager.deck_manager_ref,
            "enemy_ai": board_manager.enemy_ai_ref, "event_queue": self
        })
```

### 5. CombatSystem.gd: timerトリガー処理

変更箇所: process_combat()内の _process_support_effects(delta) 呼び出しの直後（79行目付近）

追加呼び出し:
```
_process_timer_skills(delta)
```

追加関数（CombatSystem.gd末尾に追加）:
```
func _process_timer_skills(delta: float) -> void:
    for side in range(2):
        for row in range(3):
            for col in range(3):
                var u = bm.board[side][row][col]
                if u == null or not u.is_alive() or u._is_sealed:
                    continue
                for i in range(u.skills.size()):
                    var skill = u.skills[i]
                    if skill.get("trigger", "") != "timer":
                        continue
                    var interval: float = skill.get("params", {}).get("interval", 3.0)
                    if not u._skill_timers.has(i):
                        u._skill_timers[i] = interval
                    u._skill_timers[i] -= delta
                    if u._skill_timers[i] <= 0.0:
                        u._skill_timers[i] = interval
                        var merged_t: Dictionary = skill.get("params", {}).duplicate()
                        if skill.has("target"):
                            merged_t["target"] = skill["target"]
                        bm.effect_executor.execute(skill["effect_id"], merged_t, {
                            "trigger": "timer", "side": side, "row": row, "col": col,
                            "source": u, "target": null, "damage": 0,
                            "board_manager": bm, "deck_manager": null,
                            "enemy_ai": null, "event_queue": bm.event_queue
                        })
```

注意: _skill_timersのキーは skillインデックス(int)を使用。既存フィールドはDictionary型で互換。

## 除外事項
- on_ally_deathトリガー: EventQueue.gd 240行目に実装済みのため変更不要
- _skill_timersフィールド: UnitData.gd 84行目に定義済みのため変更不要
- UnitData.gdのフィールド追加不要

## 実装後チェック
- bash check_syntax.sh でエラー0件確認
- grep "on_battle_start" scripts/Main.gd で発火コード確認
- grep "on_crit" scripts/CombatSystem.gd で発火コード確認
- grep "on_damaged" scripts/EventQueue.gd で発火コード確認
- grep "_process_timer_skills" scripts/CombatSystem.gd で追加確認
