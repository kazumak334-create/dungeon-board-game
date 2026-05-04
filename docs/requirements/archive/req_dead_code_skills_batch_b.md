STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# 要件定義書 バッチB: effect_id実装（EffectActions.gd + EffectExecutor.gd）

## 概要
EffectDB.gdには既に定義済みのentryが存在する。
バッチBではEffectActions.gdに未実装のtype handler関数を追加し、EffectExecutor.gdにマッピングを追加する。

## 実装対象ファイル
- scripts/EffectActions.gd（handler関数追加）
- scripts/EffectExecutor.gd（typeとhandler関数のマッピング追加）

## EffectDB.gdで定義済みtype一覧（変更不要）

| effect_id | type |
|---|---|
| poison_apply_periodic | debuff_apply_periodic |
| same_row_beast_atk_boost | temp_buff_race |
| front_beast_spd_boost | temp_buff_race |
| grant_pierce_to_same_row | grant_skill_flag |
| atk_by_thorn_stacks | atk_by_buff_stacks |
| curse_apply_random | curse_random |
| curse_apply_front_random | curse_front_random |
| curse_apply_adjacent | curse_adjacent |
| curse_amplify_all | curse_amplify_all |
| rush_attack | rush_damage |
| atk_apply | buff_apply (buff=atk_permanent) |
| on_ally_death_heal_and_buff | on_ally_death_trigger |

## EffectActions.gdに追加するhandler関数

### do_debuff_apply_periodic(merged, ctx)
on_supportトリガーで定期的に呼ばれる前提。通常のdebuff付与と同一処理。
実装: do_debuff_apply(merged, ctx) を呼ぶだけ

### do_temp_buff_race(merged, ctx)
targetフィールドで対象を絞り込み済み。一時ATK/SPDバフ付与。
- targets.resolve(merged, context, true) で対象取得
- buff="atk": t._temp_atk_bonus = max(1, int(t.attack * pct)), t._temp_atk_timer = duration
- buff="spd": t._temp_spd_bonus = t.get_attack_interval() * pct, t._temp_spd_timer = duration

### do_grant_skill_flag(merged, ctx)
対象ユニット全員にflagsのプロパティを設定。
- targets.resolve(merged, context, true) で対象取得
- flags.keys()を反復してt.set(flag_key, flags[flag_key])

### do_atk_by_buff_stacks(merged, ctx)
指定buffのスタック数 x factor でATKボーナス加算（always/passiveトリガーで毎フレーム再計算）。
- source == null なら return
- buff="thorn": stacks = source.thorn_stacks
- buff="armor": stacks = int(source._damage_reduction)
- buff="regen": stacks = source.regen_stacks
- source._atk_bonus += int(stacks * factor)

### do_curse_random(merged, ctx)
敵全体からランダムmax_targets体に呪い付与。
- enemy_side全9マスを候補に
- shuffle()後 min(max_targets, size())体に status_apply イベント push
- status="呪い", skill_name="curse_apply_random"

### do_curse_front_random(merged, ctx)
前列敵からランダムcount体に呪い付与。
- enemy_sideの前列のみ候補
- shuffle()後 min(count, size())体に status_apply イベント push
- status="呪い", skill_name="curse_apply_front_random"

### do_curse_adjacent(merged, ctx)
source位置の隣接マス（上下左右4方向）の敵に呪い付与。
- [[-1,0],[1,0],[0,-1],[0,1]]を反復
- 範囲外チェック(r2,c2 in [0,2])
- enemy_side[r2][c2]が生存なら status_apply push

### do_curse_amplify_all(merged, ctx)
呪いスタックがmin_curse以上の敵全員のcurse_stacksをfactor倍（int切り捨て）。
- enemy_side全9マスを確認
- curse_stacks >= min_curse なら curse_stacks = int(cs * factor)

### do_rush_damage(merged, ctx)
source.attack x damage_mult のダメージを対象に与える。
- targets.resolve(merged, context, false)で対象取得
- dmg = max(1, int((source.attack + source._atk_bonus) * damage_mult))
- eq.push(1, source, t, "damage", dmg, {enemy_side, row, col})

### do_buff_apply内のatk_permanent分岐追加
既存do_buff_apply関数のmatch buff分岐に追加:
- "atk_permanent": for t in tgt: t.attack += stacks

### do_on_ally_death_trigger(merged, ctx)
味方死亡時にsourceに回復とATK/SPDバフを付与（on_ally_deathトリガー用）。
- source == null なら return
- source.current_hp = min(max_hp, hp + max(1, int(max_hp * heal_pct)))
- source._atk_bonus += max(1, int(attack * atk_pct))
- source._interval_bonus += get_attack_interval() * spd_pct

## EffectExecutor.gdへの追加
match effect_typeブロックに以下を追加:
- "debuff_apply_periodic": actions.do_debuff_apply_periodic(merged, ctx)
- "temp_buff_race":        actions.do_temp_buff_race(merged, ctx)
- "grant_skill_flag":      actions.do_grant_skill_flag(merged, ctx)
- "atk_by_buff_stacks":    actions.do_atk_by_buff_stacks(merged, ctx)
- "curse_random":          actions.do_curse_random(merged, ctx)
- "curse_front_random":    actions.do_curse_front_random(merged, ctx)
- "curse_adjacent":        actions.do_curse_adjacent(merged, ctx)
- "curse_amplify_all":     actions.do_curse_amplify_all(merged, ctx)
- "rush_damage":           actions.do_rush_damage(merged, ctx)
- "on_ally_death_trigger": actions.do_on_ally_death_trigger(merged, ctx)

## 除外事項
- EffectDB.gdの変更なし（全type定義済み）
- UnitData.gdのフィールド追加なし

## 実装後チェック
- bash check_syntax.sh でエラー0件確認
