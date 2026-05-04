STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# 要件定義書 バッチA: ターゲット追加（EffectTargets.gd）

## 実装対象ファイル
- `C:\Users\kazum\dungeon-board-game\scripts\EffectTargets.gd`

## 変更方針
`resolve()` 関数の `match tgt_str:` ブロックに以下のターゲットケースを追加する。
既存ケースは一切変更しない。`return []` の直前に追加する。

## 追加ターゲット一覧

### 1. `random_enemy`
- 敵全体（全9マス）からランダム1体
- `all_enemies` の亜種（単一返却）
```gdscript
"random_enemy":
    var cands_re: Array = []
    for r2 in range(3):
        for c2 in range(3):
            var u = bm.board[enemy_side][r2][c2]
            if u != null and u.is_alive():
                cands_re.append(u)
    if cands_re.is_empty():
        return []
    return [cands_re[randi() % cands_re.size()]]
```

### 2. `enemy_front_lowest_hp`
- 前列の最低HP敵1体（同HP時はランダム）
```gdscript
"enemy_front_lowest_hp":
    var front_eflo: int = 0 if enemy_side == 1 else 2
    var best_eflo: Object = null
    var best_hp_eflo: int = 999999
    for r2 in range(3):
        var u = bm.board[enemy_side][r2][front_eflo]
        if u != null and u.is_alive():
            if u.current_hp < best_hp_eflo:
                best_hp_eflo = u.current_hp
                best_eflo = u
    return [best_eflo] if best_eflo != null else []
```

### 3. `same_row_allies`
- source と同じ行の味方全員（source自身を除く）
- contextの`row`を使用
```gdscript
"same_row_allies":
    var result_sra: Array = []
    for c2 in range(3):
        var u = bm.board[side][row][c2]
        if u != null and u.is_alive() and u != source:
            result_sra.append(u)
    return result_sra
```

### 4. `enemies_with_curse` / `cursed_enemies`
- curse_stacks > 0 の敵全員（2つは同一ロジック、別名）
```gdscript
"enemies_with_curse", "cursed_enemies":
    var result_ewc: Array = []
    for r2 in range(3):
        for c2 in range(3):
            var u = bm.board[enemy_side][r2][c2]
            if u != null and u.is_alive():
                var cs: int = u.curse_stacks if "curse_stacks" in u else 0
                if cs > 0:
                    result_ewc.append(u)
    return result_ewc
```

### 5. `enemy_highest_curse`
- curse_stacks最大の敵1体
```gdscript
"enemy_highest_curse":
    var best_ehc: Object = null
    var best_curse_ehc: int = 0
    for r2 in range(3):
        for c2 in range(3):
            var u = bm.board[enemy_side][r2][c2]
            if u != null and u.is_alive():
                var cs: int = u.curse_stacks if "curse_stacks" in u else 0
                if cs > best_curse_ehc:
                    best_curse_ehc = cs
                    best_ehc = u
    return [best_ehc] if best_ehc != null else []
```

### 6. `adjacent_enemies`
- source位置（row, col）に隣接する敵マス（上下左右4方向）
- 盤面は enemy_side を使用
```gdscript
"adjacent_enemies":
    var result_aen: Array = []
    for d in [[-1, 0], [1, 0], [0, -1], [0, 1]]:
        var r2: int = row + d[0]
        var c2: int = col + d[1]
        if r2 >= 0 and r2 < 3 and c2 >= 0 and c2 < 3:
            var u = bm.board[enemy_side][r2][c2]
            if u != null and u.is_alive():
                result_aen.append(u)
    return result_aen
```

### 7. `attacker`
- コンテキストの `source` を返す（被ダメージ時の攻撃者がsourceとして渡される）
```gdscript
"attacker":
    return [source] if source != null else []
```

### 8. `enemy_back`
- 後列の敵全員（side=0なら enemy_side=1 の col=2、side=1なら col=0）
```gdscript
"enemy_back":
    var back_col_eb: int = 2 if enemy_side == 1 else 0
    var result_eb: Array = []
    for r2 in range(3):
        var u = bm.board[enemy_side][r2][back_col_eb]
        if u != null and u.is_alive():
            result_eb.append(u)
    return result_eb
```

### 9. `all_units_random`
- 全ユニット（味方+敵）からランダムN体（N=max_targets、デフォルト5）
- mergedにmax_targetsが含まれる前提
```gdscript
"all_units_random":
    var cands_aur: Array = []
    for s2 in range(2):
        for r2 in range(3):
            for c2 in range(3):
                var u = bm.board[s2][r2][c2]
                if u != null and u.is_alive():
                    cands_aur.append(u)
    cands_aur.shuffle()
    var max_n: int = merged.get("max_targets", 5)
    return cands_aur.slice(0, min(max_n, cands_aur.size()))
```

## 除外事項
- `all_enemies`：既に実装済み（確認済み）
- `front_ally`：既存の`random_front_ally`で代替可能なため追加しない
- EffectDB.gdの変更は行わない

## 実装後チェック
- `bash check_syntax.sh` を実行してエラー0件を確認
- `grep "random_enemy\|enemy_front_lowest_hp\|same_row_allies\|enemies_with_curse\|enemy_highest_curse\|adjacent_enemies\|attacker\|enemy_back\|all_units_random" scripts/EffectTargets.gd` で全ケースが追加されていることを確認
