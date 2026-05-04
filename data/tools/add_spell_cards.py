#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
呪文カードデータ追加スクリプト
16枚の新規呪文カードを追加
"""
import json
from pathlib import Path

# 新規呪文カードデータ
NEW_SPELLS = {
    # === 毒系 ===
    "ベノムバースト": {
        "anim": "",
        "rarity": "common",
        "mana": 6,
        "effect": "敵単体に毒+5",
        "sfx": "",
        "skills": [
            {
                "effect_id": "poison_apply_single",
                "params": {"stacks": 5},
                "target": "random_enemy",
                "trigger": "on_play"
            }
        ],
        "target": "random_enemy",
        "texture": "",
        "en_name": "Venomburst",
        "description": "敵単体に毒+5"
    },

    "ベノムクラウド": {
        "anim": "",
        "rarity": "uncommon",
        "mana": 8,
        "effect": "敵ランダム3体に毒+3ずつ",
        "sfx": "",
        "skills": [
            {
                "effect_id": "poison_apply_random_multi",
                "params": {"stacks": 3, "count": 3},
                "target": "random_enemies",
                "trigger": "on_play"
            }
        ],
        "target": "random_enemies",
        "texture": "",
        "en_name": "Venomcloud",
        "description": "敵ランダム3体に毒+3ずつ"
    },

    "ベノムショック": {
        "anim": "",
        "rarity": "rare",
        "mana": 10,
        "effect": "敵ユニットの毒スタック数分ダメージ（毒スタック消費なし）",
        "sfx": "",
        "skills": [
            {
                "effect_id": "poison_damage_by_stack",
                "params": {"consume": False},
                "target": "all_enemies",
                "trigger": "on_play"
            }
        ],
        "target": "all_enemies",
        "texture": "",
        "en_name": "Venomshock",
        "description": "敵ユニットの毒スタック数分ダメージ（毒スタック消費なし）"
    },

    # === 呪い系 ===
    "デファイルカース": {
        "anim": "",
        "rarity": "legend",
        "mana": 14,
        "effect": "敵ユニットの全デバフを呪いスタックに変換する",
        "sfx": "",
        "skills": [
            {
                "effect_id": "debuff_to_curse",
                "params": {"factor": 1.0},
                "target": "all_enemies",
                "trigger": "on_play"
            }
        ],
        "target": "all_enemies",
        "texture": "",
        "en_name": "Defilecurse",
        "description": "敵ユニットの全デバフを呪いスタックに変換する"
    },

    "ヘクスアクルー": {
        "anim": "",
        "rarity": "uncommon",
        "mana": 5,
        "effect": "直近5秒間にかけられたデバフ数×1呪いスタックをランダムなユニットに付与",
        "sfx": "",
        "skills": [
            {
                "effect_id": "recent_debuff_to_curse",
                "params": {"window": 5.0, "factor": 1.0},
                "target": "random_enemy",
                "trigger": "on_play"
            }
        ],
        "target": "random_enemy",
        "texture": "",
        "en_name": "Hexaccrue",
        "description": "直近5秒間にかけられたデバフ数×1呪いスタックをランダムなユニットに付与"
    },

    "カースドレイン": {
        "anim": "",
        "rarity": "uncommon",
        "mana": 7,
        "effect": "自分ユニットの呪いスタックが最多のユニットから呪い5解除",
        "sfx": "",
        "skills": [
            {
                "effect_id": "curse_remove",
                "params": {"stacks": 5, "target_type": "highest"},
                "target": "ally_highest_curse",
                "trigger": "on_play"
            }
        ],
        "target": "ally_highest_curse",
        "texture": "",
        "en_name": "Cursedrain",
        "description": "自分ユニットの呪いスタックが最多のユニットから呪い5解除"
    },

    "デスシフト": {
        "anim": "",
        "rarity": "rare",
        "mana": 10,
        "effect": "再生後のユニットに盤面全デバフを移す（対象なしで発動）",
        "sfx": "",
        "skills": [
            {
                "effect_id": "debuff_transfer_revived",
                "params": {"target_type": "revived"},
                "target": "revived_unit",
                "trigger": "on_play"
            }
        ],
        "target": "revived_unit",
        "texture": "",
        "en_name": "Deathshift",
        "description": "再生後のユニットに盤面全デバフを移す（対象なしで発動）"
    },

    # === 異常状態解除系 ===
    "ピュアポイント": {
        "anim": "",
        "rarity": "rare",
        "mana": 10,
        "effect": "味方単体の全異常状態を解除",
        "sfx": "",
        "skills": [
            {
                "effect_id": "cleanse_single",
                "params": {"scope": "single"},
                "target": "random_ally",
                "trigger": "on_play"
            }
        ],
        "target": "random_ally",
        "texture": "",
        "en_name": "Purepoint",
        "description": "味方単体の全異常状態を解除"
    },

    "ピュアライン": {
        "anim": "",
        "rarity": "common",
        "mana": 6,
        "effect": "味方同列の異常状態1種類ランダム解除",
        "sfx": "",
        "skills": [
            {
                "effect_id": "cleanse_column_random",
                "params": {"scope": "column", "count": 1},
                "target": "random_ally_column",
                "trigger": "on_play"
            }
        ],
        "target": "random_ally_column",
        "texture": "",
        "en_name": "Pureline",
        "description": "味方同列の異常状態1種類ランダム解除"
    },

    "ピュアロウ": {
        "anim": "",
        "rarity": "common",
        "mana": 6,
        "effect": "味方同行の異常状態1種類ランダム解除",
        "sfx": "",
        "skills": [
            {
                "effect_id": "cleanse_row_random",
                "params": {"scope": "row", "count": 1},
                "target": "random_ally_row",
                "trigger": "on_play"
            }
        ],
        "target": "random_ally_row",
        "texture": "",
        "en_name": "Purerow",
        "description": "味方同行の異常状態1種類ランダム解除"
    },

    "ピュアウェーブ": {
        "anim": "",
        "rarity": "uncommon",
        "mana": 9,
        "effect": "味方全体の異常状態1種類ランダム解除",
        "sfx": "",
        "skills": [
            {
                "effect_id": "cleanse_all_random",
                "params": {"scope": "all", "count": 1},
                "target": "all_allies",
                "trigger": "on_play"
            }
        ],
        "target": "all_allies",
        "texture": "",
        "en_name": "Purewave",
        "description": "味方全体の異常状態1種類ランダム解除"
    },

    "ヌルフィールド": {
        "anim": "",
        "rarity": "rare",
        "mana": 9,
        "effect": "味方全体に一定時間異常状態無効化バリア付与",
        "sfx": "",
        "skills": [
            {
                "effect_id": "status_immunity_barrier",
                "params": {"duration": 5.0, "barrier_type": "status"},
                "target": "all_allies",
                "trigger": "on_play"
            }
        ],
        "target": "all_allies",
        "texture": "",
        "en_name": "Nullfield",
        "description": "味方全体に一定時間異常状態無効化バリア付与"
    },

    # === 獣強化系 ===
    "ソウルクロウ": {
        "anim": "",
        "rarity": "rare",
        "mana": 6,
        "effect": "撃破された獣ユニットのATK合計を前列ランダム獣1体に付与",
        "sfx": "",
        "skills": [
            {
                "effect_id": "beast_atk_from_dead",
                "params": {"target_type": "front_random_beast"},
                "target": "front_random_beast",
                "trigger": "on_play"
            }
        ],
        "target": "front_random_beast",
        "texture": "",
        "en_name": "Soulclaw",
        "description": "撃破された獣ユニットのATK合計を前列ランダム獣1体に付与"
    },

    "ワイルドシフト": {
        "anim": "",
        "rarity": "uncommon",
        "mana": 5,
        "effect": "前列の獣を後退させて中列と交換・前列ユニットのHP回復",
        "sfx": "",
        "skills": [
            {
                "effect_id": "beast_retreat_heal",
                "params": {"heal_pct": 0.3},
                "target": "front_beasts",
                "trigger": "on_play"
            }
        ],
        "target": "front_beasts",
        "texture": "",
        "en_name": "Wildshift",
        "description": "前列の獣を後退させて中列と交換・前列ユニットのHP回復"
    },

    "パックラッシュ": {
        "anim": "",
        "rarity": "common",
        "mana": 3,
        "effect": "盤面の獣ユニット数×ATK1%を前列獣全体に5秒間付与",
        "sfx": "",
        "skills": [
            {
                "effect_id": "beast_pack_atk_boost",
                "params": {"atk_pct_per_beast": 0.01, "duration": 5.0},
                "target": "front_beasts",
                "trigger": "on_play"
            }
        ],
        "target": "front_beasts",
        "texture": "",
        "en_name": "Packrush",
        "description": "盤面の獣ユニット数×ATK1%を前列獣全体に5秒間付与"
    },

    "プレイマーク": {
        "anim": "",
        "rarity": "uncommon",
        "mana": 7,
        "effect": "中後列のバフを前列獣1体に移す",
        "sfx": "",
        "skills": [
            {
                "effect_id": "buff_transfer_to_front_beast",
                "params": {"count": 99, "target_type": "front_random_beast"},
                "target": "front_random_beast",
                "trigger": "on_play"
            }
        ],
        "target": "front_random_beast",
        "texture": "",
        "en_name": "Preymark",
        "description": "中後列のバフを前列獣1体に移す"
    },
}

def main():
    json_path = Path('cards.json')

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 呪文追加
    print("=== 呪文カード追加 ===\n")
    added_count = 0
    for spell_name, spell_data in NEW_SPELLS.items():
        # 既に存在する場合はスキップ
        if spell_name in data['spells']:
            print(f"Skip {spell_name} - 既に存在")
            continue

        data['spells'][spell_name] = spell_data
        if spell_name not in data['player_spells']:
            data['player_spells'].append(spell_name)

        rarity_str = f"({spell_data['rarity']})" if spell_data.get('rarity') else ""
        print(f"+ {spell_name} ({spell_data['en_name']}) - コスト{spell_data['mana']} {rarity_str}")
        added_count += 1

    # バックアップ作成
    backup_path = Path('cards.json.backup_spells')
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print(f"\nバックアップ作成: {backup_path}")

    # cards.jsonを更新
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print(f"\n=== 完了 ===")
    print(f"新規呪文カード: {added_count}枚")
    print("cards.jsonを更新しました")

if __name__ == '__main__':
    main()
