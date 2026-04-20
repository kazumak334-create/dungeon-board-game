# 残り30個の未定義effect_id

## 実装済み（11個）
- armor_damage, armor_damage_consume
- buff_steal, buff_to_curse_amplify
- curse_amplify_all
- mana_steal, mana_steal_shield
- poison_by_x, x_stack_add, x_stack_add_from_field

## 未実装リスト（30個）

1. atk_apply
2. atk_buff_apply
3. buff_steal_all
4. buff_to_curse_convert_all
5. burn_by_status_count
6. crit_mult_boost
7. curse_burst_on_death
8. curse_multiply
9. curse_multiply_all_cursed
10. damage_by_x
11. deck_add_toxswamp
12. freeze_by_status_count
13. heal_by_damage_dealt
14. heal_reduction_cursed
15. mana_generation_boost
16. mana_generation_trigger
17. mana_regen_boost
18. mark_if_poison_gte
19. on_ally_death_thorn_boost
20. poison_if_marked
21. poison_total_to_x
22. position_swap_front_back
23. position_swap_random
24. sense_consume_damage
25. spell_slot_seal
26. summon_speed_buff
27. swap_cursed_enemies
28. thorn_damage
29. trait_madness
30. trait_resilient

## カテゴリ別分類

### ATK・バフ系（3個）
- **atk_apply**: ATKバフ付与（Deadeye - on_crit）
- **atk_buff_apply**: サポート効果ATKバフ（アーティファクト - always）
- **summon_speed_buff**: 召喚時SPDバフ

### 状態異常系（4個）
- **burn_by_status_count**: 状態異常数×火傷付与（Blightzel - on_support）
- **freeze_by_status_count**: 状態異常数×凍結付与（Frostblob - on_support）
- **mark_if_poison_gte**: 毒閾値でマーク付与（Toxmark - on_hit, poison_threshold=10, mark_stacks=2）
- **poison_if_marked**: マーク持ちに毒付与（Toxmark系 - on_support）

### 呪い系（3個）
- **curse_burst_on_death**: 死亡時呪い爆発（Deathhowl - on_death, threshold=20）
- **curse_multiply**: 対象の呪いを倍率増幅（Hexblast - on_hit, factor=2.5-4.0）
- **curse_multiply_all_cursed**: 全呪い持ち敵の呪い倍率増幅（Hexlord - on_hit, factor=1.5-2.0）

### バフ操作系（1個）
- **buff_steal_all**: 全バフ奪取（Soulreap - on_support）

### X値・毒システム（3個）
- **damage_by_x**: X値÷divisor分の追加ダメージ（Toxblade - on_hit, divisor=5）
- **poison_total_to_x**: 対象の毒スタック総数をX値に変換
- **deck_add_toxswamp**: デッキにToxswampカード追加（Voidvenom - on_support）

### ダメージ・回復系（3個）
- **sense_consume_damage**: センス消費追加ダメージ（Keenfang - on_crit）
- **thorn_damage**: 棘スタック×ダメージ（Thornrage - on_front_attack）
- **heal_by_damage_dealt**: 与ダメージ×factor分HP回復（Ironpelt - on_hit, factor=0.05）

### マナ系（3個）
- **mana_generation_boost**: マナ生成量恒久ブースト（Manasly - always）
- **mana_generation_trigger**: 召喚時マナ生成量増加（Manasly - on_summon）
- **mana_regen_boost**: マナ回復速度上昇

### 位置操作系（3個）
- **position_swap_front_back**: 前列↔後列入れ替え（Hexdrift - on_support）
- **position_swap_random**: ランダム位置入れ替え
- **swap_cursed_enemies**: 呪い持ち敵の位置をランダム入れ替え（Hexswap - on_support）

### 特殊系（5個）
- **spell_slot_seal**: 呪文スロット封印（Spellock系 - on_support）
- **trait_madness**: 狂乱特性（既存の_has_midnight_frenzy?）
- **trait_resilient**: 復活特性（既存の_support_revive?）
- **on_ally_death_thorn_boost**: 味方死亡時に棘スタック増加（Thornrage）
- **heal_reduction_cursed**: 呪い持ちの回復量減少
- **crit_mult_boost**: クリティカル倍率上昇（Deadfang - on_support）

## 実装優先度の提案

### 高優先度（使用頻度高・システム影響大）
1. **damage_by_x** - X値システムの主要効果
2. **curse_multiply** - 呪いシステムの主要効果
3. **atk_apply** - 基本バフ効果
4. **buff_steal_all** - バフ奪取の完全版

### 中優先度（特定カードで必須）
5. **mark_if_poison_gte**, **poison_if_marked** - マークシステム一式
6. **thorn_damage**, **on_ally_death_thorn_boost** - 棘システム一式
7. **burn_by_status_count**, **freeze_by_status_count** - 状態異常カウント系

### 低優先度（派生効果・レア効果）
8. **position_swap_***, **swap_cursed_enemies** - 位置入れ替え系
9. **spell_slot_seal** - Phase 5実装予定機能
10. **trait_madness**, **trait_resilient** - 既存フラグとの統合確認必要
11. **mana_generation_***, **mana_regen_boost** - マナシステム拡張
12. **deck_add_toxswamp** - 特定カード専用

## 次のステップ

高優先度4個→中優先度7個→低優先度12個の順で実装を推奨。
各effect_idの詳細仕様が必要な場合は個別に確認してください。
