#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
アンデッドカードデータ追加スクリプト
12体の新規アンデッドユニットと3枚の呪文カードを追加
"""
import json
from pathlib import Path

# 新規アンデッドユニットデータ
NEW_UNDEAD_UNITS = {
    # 1. Gravshift（墓場シフト）- Rare
    "グレイヴシフト": {
        "anim": "",
        "rarity": "rare",
        "atk": 2,
        "col": 0,
        "mana": 2,
        "hp": 30,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "swap_enemy_positions",
                "params": {"count": 2, "target": "enemy_back"},
                "target": "enemy_back",
                "trigger": "timer",
                "interval": 5.0
            },
            {
                "effect_id": "revive_on_death",
                "params": {"hp_pct": 0.1, "delay": 5.0},
                "target": "self",
                "trigger": "on_death"
            }
        ],
        "texture": "",
        "spd": 2.0,
        "en_name": "Gravshift"
    },

    # 2. Soulsteal（魂奪取）- Rare
    "ソウルスティール": {
        "anim": "",
        "rarity": "rare",
        "atk": 2,
        "col": 1,
        "mana": 2,
        "hp": 25,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "buff_steal_transfer",
                "params": {"count": 2},
                "target": "hit_target",
                "trigger": "on_hit"
            },
            {
                "effect_id": "buff_transfer",
                "params": {"count": 2},
                "target": "random_enemy",
                "trigger": "timer",
                "interval": 5.0
            },
            {
                "effect_id": "revive_on_death",
                "params": {"hp_pct": 0.1, "delay": 5.0},
                "target": "self",
                "trigger": "on_death"
            }
        ],
        "texture": "",
        "spd": 2.0,
        "en_name": "Soulsteal"
    },

    # 3. Hexvert（呪い反転）- Uncommon
    "ヘクスヴァート": {
        "anim": "",
        "rarity": "uncommon",
        "atk": 1,
        "col": 0,
        "mana": 1,
        "hp": 10,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "synergy_invert",
                "params": {"duration": 5.0},
                "target": "hit_target",
                "trigger": "on_hit"
            }
        ],
        "texture": "",
        "spd": 3.0,
        "en_name": "Hexvert"
    },

    # 4. Curseed（呪いの種）- Common
    "カースシード": {
        "anim": "",
        "rarity": "common",
        "atk": 1,
        "col": 0,
        "mana": 1,
        "hp": 25,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "curse_additional_damage",
                "params": {"factor": 1.0},
                "target": "hit_target",
                "trigger": "on_hit"
            },
            {
                "effect_id": "curse_apply_highest",
                "params": {"stacks": 1},
                "target": "enemy_highest_curse",
                "trigger": "timer",
                "interval": 3.0
            }
        ],
        "texture": "",
        "spd": 1.0,
        "en_name": "Curseed"
    },

    # 5. Maleamp（呪詛増幅）- Uncommon
    "マレアンプ": {
        "anim": "",
        "rarity": "uncommon",
        "atk": 1,
        "col": 0,
        "mana": 2,
        "hp": 20,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "curse_amplify",
                "params": {"factor": 2.0},
                "target": "hit_target",
                "trigger": "on_hit"
            }
        ],
        "texture": "",
        "spd": 2.0,
        "en_name": "Maleamp"
    },

    # 6. Wraithdance（死霊の舞）- Rare
    "レイスダンス": {
        "anim": "",
        "rarity": "rare",
        "atk": 1,
        "col": 1,
        "mana": 2,
        "hp": 20,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "curse_spread_trigger",
                "params": {"threshold": 10},
                "target": "all_enemies",
                "trigger": "timer",
                "interval": 3.0
            },
            {
                "effect_id": "curse_total_spd_boost",
                "params": {"pct": 0.001},
                "target": "self",
                "trigger": "always"
            }
        ],
        "texture": "",
        "spd": 3.0,
        "en_name": "Wraithdance"
    },

    # 7. Grimhowl（死の遠吠え）- Uncommon
    "グリムハウル": {
        "anim": "",
        "rarity": "uncommon",
        "atk": 1,
        "col": 1,
        "mana": 2,
        "hp": 20,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "random_status_apply",
                "params": {"count": 1},
                "target": "random_enemy",
                "trigger": "timer",
                "interval": 5.0
            },
            {
                "effect_id": "skill_seal_on_ally_death",
                "params": {"duration": 5.0},
                "target": "random_enemy",
                "trigger": "on_ally_death"
            }
        ],
        "texture": "",
        "spd": 2.0,
        "en_name": "Grimhowl"
    },

    # 8. Curseal（呪封じ）- Uncommon
    "カーシール": {
        "anim": "",
        "rarity": "uncommon",
        "atk": 1,
        "col": 1,
        "mana": 3,
        "hp": 30,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "curse_apply",
                "params": {"stacks": 1},
                "target": "hit_target",
                "trigger": "on_hit"
            },
            {
                "effect_id": "disable_attack_effects",
                "params": {"effect_type": "on_hit", "duration": 1.0},
                "target": "cursed_enemies",
                "trigger": "timer",
                "interval": 2.0
            }
        ],
        "texture": "",
        "spd": 3.0,
        "en_name": "Curseal"
    },

    # 9. Traitbane（特性滅）- Epic
    "トレイトベイン": {
        "anim": "",
        "rarity": "epic",
        "atk": 5,
        "col": 0,
        "mana": 2,
        "hp": 50,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "trait_seal",
                "params": {"duration": 999.0},
                "target": "hit_target",
                "trigger": "on_hit"
            },
            {
                "effect_id": "trait_seal_all_same",
                "params": {"duration": 999.0},
                "target": "all_enemies",
                "trigger": "on_hit"
            }
        ],
        "texture": "",
        "spd": 2.0,
        "en_name": "Traitbane"
    },

    # 10. Hexspawn（呪産）- Common
    "ヘクススポーン": {
        "anim": "",
        "rarity": "common",
        "atk": 1,
        "col": 0,
        "mana": 2,
        "hp": 50,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "curse_apply",
                "params": {"stacks": 1},
                "target": "hit_target",
                "trigger": "on_hit"
            },
            {
                "effect_id": "revive_on_death",
                "params": {"hp_pct": 0.1, "delay": 5.0},
                "target": "self",
                "trigger": "on_death"
            },
            {
                "effect_id": "curse_apply_battle_start",
                "params": {"stacks": 1, "max_count": 5},
                "target": "all_units",
                "trigger": "battle_start"
            }
        ],
        "texture": "",
        "spd": 2.0,
        "en_name": "Hexspawn"
    },

    # 11. Doomcurse（破滅の呪い）- Legend
    "ドゥームカース": {
        "anim": "",
        "rarity": "legend",
        "atk": 8,
        "col": 0,
        "mana": 2,
        "hp": 60,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "total_curse_damage",
                "params": {"factor": 1.0},
                "target": "hit_target",
                "trigger": "on_hit"
            },
            {
                "effect_id": "curse_apply_front_random",
                "params": {"stacks": 1, "count": 1},
                "target": "front_enemy",
                "trigger": "timer",
                "interval": 3.0
            }
        ],
        "texture": "",
        "spd": 3.0,
        "en_name": "Doomcurse"
    },

    # 12. Banewall（呪いの壁）- Rare
    "ベインウォール": {
        "anim": "",
        "rarity": "rare",
        "atk": 2,
        "col": 0,
        "mana": 3,
        "hp": 60,
        "race": "アンデッド",
        "range": "1行",
        "sfx": "",
        "skills": [
            {
                "effect_id": "curse_by_damage_taken",
                "params": {"factor": 0.1},
                "target": "hit_target",
                "trigger": "on_hit"
            },
            {
                "effect_id": "curse_apply_adjacent",
                "params": {"stacks": 1},
                "target": "adjacent_enemies",
                "trigger": "on_damaged"
            },
            {
                "effect_id": "curse_reflect",
                "params": {"stacks": 1},
                "target": "attacker",
                "trigger": "on_damaged"
            }
        ],
        "texture": "",
        "spd": 5.0,
        "en_name": "Banewall"
    },
}

# 新規呪文カードデータ
NEW_SPELLS = {
    "前中列入替": {
        "cost": 5,
        "display": "前中列入替",
        "en_name": "Linewarp",
        "description": "自分の前列と中列のユニットを全て入れ替える",
        "effects": [
            {
                "effect_id": "swap_ally_rows",
                "params": {"row1": "front", "row2": "mid"},
                "target": "ally_board"
            }
        ],
        "rarity": "common",
        "texture": "",
        "anim": "",
        "sfx": ""
    },
    "前列行混乱": {
        "cost": 5,
        "display": "前列行混乱",
        "en_name": "Rowblend",
        "description": "自分の前列からランダム2体の行を入れ替える",
        "effects": [
            {
                "effect_id": "swap_ally_random_rows",
                "params": {"count": 2},
                "target": "front_ally"
            }
        ],
        "rarity": "common",
        "texture": "",
        "anim": "",
        "sfx": ""
    },
    "前列崩し": {
        "cost": 5,
        "display": "前列崩し",
        "en_name": "Frontcrash",
        "description": "敵の前列からランダム2体の行を入れ替える",
        "effects": [
            {
                "effect_id": "swap_enemy_random_rows",
                "params": {"count": 2},
                "target": "front_enemy"
            }
        ],
        "rarity": "common",
        "texture": "",
        "anim": "",
        "sfx": ""
    },
}

def main():
    json_path = Path('cards.json')

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # ユニット追加
    print("=== アンデッドユニット追加 ===\n")
    for unit_name, unit_data in NEW_UNDEAD_UNITS.items():
        data['units'][unit_name] = unit_data
        print(f"+ {unit_name} ({unit_data['en_name']}) - {unit_data['rarity']}")

    # 呪文追加
    print("\n=== 呪文カード追加 ===\n")
    for spell_name, spell_data in NEW_SPELLS.items():
        data['spells'][spell_name] = spell_data
        if spell_name not in data['player_spells']:
            data['player_spells'].append(spell_name)
        print(f"+ {spell_name} ({spell_data['en_name']}) - コスト{spell_data['cost']}")

    # バックアップ作成
    backup_path = Path('cards.json.backup_undead')
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print(f"\nバックアップ作成: {backup_path}")

    # cards.jsonを更新
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print(f"\n=== 完了 ===")
    print(f"新規アンデッドユニット: {len(NEW_UNDEAD_UNITS)}体")
    print(f"新規呪文カード: {len(NEW_SPELLS)}枚")
    print("cards.jsonを更新しました")

if __name__ == '__main__':
    main()
