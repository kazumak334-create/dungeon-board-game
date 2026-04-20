# 未定義effect_id仕様確認（37個）

## X値システム（毒スタック連動）

### x_stack_add
- **カード例**: Toxblade, Venomstrike
- **trigger**: on_support
- **params**: `{"stacks": 3-4}`
- **推定仕様**: X値をスタック数分加算

### poison_by_x
- **カード例**: Toxblade, Venomstrike, Voidvenom, Toxmark
- **trigger**: on_hit
- **params**: `{"multiplier": 1}`
- **推定仕様**: X値×multiplier分の毒を対象に付与

### damage_by_x
- **カード例**: Toxblade（poison_by_xと併用）
- **trigger**: on_hit
- **params**: `{"divisor": 5}`
- **推定仕様**: X値÷divisor分の追加ダメージ

### poison_total_to_x
- **カード例**: 不明（要確認）
- **推定仕様**: 対象の毒スタック総数をX値に変換？

### poison_if_marked
- **カード例**: Toxmark系（mark_if_poison_gteと併用）
- **trigger**: on_support
- **推定仕様**: マーク持ちに毒付与

### mark_if_poison_gte
- **カード例**: Toxmark, Plaguemark
- **trigger**: on_hit
- **params**: `{"poison_threshold": 10, "mark_stacks": 2}`
- **推定仕様**: 毒が閾値以上ならマーク付与

---

## バフ操作系

### buff_steal
- **カード例**: Souldrain
- **trigger**: on_hit
- **params**: `{"count": 2}`
- **推定仕様**: 敵からランダムなバフを2スタック奪う

### buff_steal_all
- **カード例**: Soulreap（buff_stealの上位版）
- **trigger**: on_support
- **推定仕様**: 敵の全バフを奪う

### buff_to_curse_convert_all
- **カード例**: Voidcurse, Hexvoid
- **trigger**: on_hit / on_support
- **推定仕様**: 敵の全バフを呪いに変換

---

## 呪い操作系

### curse_amplify_all
- **カード例**: Hexshift, Hexbreak, Hexruin
- **trigger**: on_support
- **params**: `{"factor": 1.5-2.5, "min_curse": 5}`
- **推定仕様**: 呪い5以上の敵全体の呪いを×factor倍

### curse_multiply
- **カード例**: Hexblast, Hexlord
- **trigger**: on_hit
- **params**: `{"factor": 2.5-4.0}`
- **推定仕様**: 対象の呪いを×factor倍

### curse_multiply_all_cursed
- **カード例**: Hexlord（curse_multiplyと併用）
- **trigger**: on_hit
- **params**: `{"factor": 1.5-2.0}`
- **推定仕様**: 全呪い持ち敵の呪いを×factor倍

### curse_burst_on_death
- **カード例**: Deathhowl
- **trigger**: on_death
- **params**: `{"threshold": 20}`
- **推定仕様**: 死亡時、threshold以上の呪い持ち敵全体に呪い爆発ダメージ？

---

## 鎧・ダメージ系

### armor_damage
- **カード例**: Shieldblast
- **trigger**: on_front_attack
- **params**: `{}`
- **推定仕様**: 自分の鎧スタック×ダメージ（鎧消費なし）

### armor_damage_consume
- **カード例**: Crystalblast（armor_damageの消費版）
- **trigger**: on_front_attack
- **params**: `{}`
- **推定仕様**: 自分の鎧スタック×ダメージ（鎧を消費）

### sense_consume_damage
- **カード例**: Keenfang
- **trigger**: on_crit
- **推定仕様**: センス消費して追加ダメージ？

### thorn_damage
- **カード例**: Thornrage（on_ally_death_thorn_boostと併用）
- **trigger**: on_front_attack
- **推定仕様**: 棘スタック×ダメージ？

### on_ally_death_thorn_boost
- **カード例**: Thornrage
- **trigger**: on_ally_death
- **推定仕様**: 味方死亡時に棘スタック増加

---

## マナ操作系

### mana_steal
- **カード例**: Manawall, Aegisblob
- **trigger**: on_front_attack
- **params**: `{"amount": 1}`
- **推定仕様**: 敵のマナを1奪って自分のマナに

### mana_generation_boost
- **カード例**: Manasly（always）
- **推定仕様**: マナ生成量を恒久的にブースト

### mana_generation_trigger
- **カード例**: Manasly（on_summon）
- **推定仕様**: 召喚時にマナ生成量を増加

### mana_regen_boost
- **カード例**: 不明
- **推定仕様**: マナ回復速度上昇？

---

## ATK・バフ付与系

### atk_apply
- **カード例**: Deadeye
- **trigger**: on_crit
- **params**: `{"stacks": 1}`
- **推定仕様**: ATKバフ付与（一時的？永続？）

### atk_buff_apply
- **カード例**: アーティファクト（always）
- **params**: `{"stacks": 2-5}`
- **target**: front_ally_all / all_allies
- **推定仕様**: サポート効果としてのATKバフ付与

### summon_speed_buff
- **カード例**: 不明
- **推定仕様**: 召喚時にSPDバフ付与

### crit_mult_boost
- **カード例**: Deadfang
- **trigger**: on_support
- **推定仕様**: クリティカル倍率上昇（×2→×3？）

---

## 状態異常系

### burn_by_status_count
- **カード例**: Blightzel（状態異常カウント参照）
- **trigger**: on_support
- **推定仕様**: 状態異常の数×火傷付与

### freeze_by_status_count
- **カード例**: Frostblob（burn_by_status_countの凍結版）
- **trigger**: on_support
- **推定仕様**: 状態異常の数×凍結付与

---

## 特殊効果

### heal_by_damage_dealt
- **カード例**: Ironpelt
- **trigger**: on_hit
- **params**: `{"factor": 0.05}`
- **推定仕様**: 与ダメージの5%分HP回復

### heal_reduction_cursed
- **カード例**: 不明
- **推定仕様**: 呪い持ちの回復量減少

### position_swap_front_back
- **カード例**: Hexdrift
- **trigger**: on_support
- **推定仕様**: 前列と後列のユニットを入れ替え

### position_swap_random
- **カード例**: 不明
- **推定仕様**: ランダムにユニットを入れ替え

### swap_cursed_enemies
- **カード例**: Hexswap
- **trigger**: on_support
- **推定仕様**: 呪い持ち敵の位置をランダムに入れ替え

### spell_slot_seal
- **カード例**: Spellock系
- **trigger**: on_support
- **推定仕様**: 敵の呪文スロットを封印（Phase 5で実装予定？）

### deck_add_toxswamp
- **カード例**: Voidvenom
- **trigger**: on_support
- **推定仕様**: デッキにToxswamp（毒沼カード？）を追加

### trait_madness
- **カード例**: 不明
- **推定仕様**: 狂乱特性（既存の_has_midnight_frenzy？）

### trait_resilient
- **カード例**: 不明
- **推定仕様**: 復活特性（既存の_support_revive？）

---

## 確認が必要な点

1. **X値システムの実装方針**
   - UnitDataにx_stacksフィールド追加？
   - 毒スタック総数と連動？別管理？

2. **バフ奪取の実装**
   - _stolen_atk等の既存フィールド活用？
   - 新規バフ奪取システム構築？

3. **呪い増幅系の倍率計算**
   - 整数丸め？小数点維持？
   - 上限値は？

4. **マナ操作系の敵マナ管理**
   - 敵AIのマナを奪う仕組みは既存？

5. **位置入れ替え系**
   - アニメーション対応必要？
   - 即座に移動？

6. **trait系effect_id**
   - 既存のフラグ（_has_midnight_frenzy等）との重複？
   - 新規実装が必要？
