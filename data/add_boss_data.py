#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ボスデータ追加スクリプト
- 既存のボス3体にen_nameを追加
- Act1の残り2体を追加
- Act2/Act3の各5体を追加
"""
import json
from pathlib import Path

# 既存ボスのen_name
EXISTING_BOSS_EN_NAMES = {
    'boss_beast_king': 'BEASTKING',       # 獣王 (9文字)
    'boss_slime_mother': 'OVERFLOW',      # 母なるスライム = Buffer Overflow (8文字)
    'boss_death_lord': 'LEAK LICH',       # 死神の主 = Memory Leak × Lich (9文字)
}

# 新規ボスデータ（Act1残り2体 + Act2/Act3各5体 = 12体）
NEW_BOSSES = {
    # Act1 残り2体
    'boss_firewall': {
        'display': 'ファイア・ゲート',
        'en_name': 'FIREWALL',
        'act': 1,
        'race_theme': 'mixed',
        'description': 'ネットワークを守る炎の障壁',
        'difficulty': 3,
        'enemy_deck_id': 'boss_act1_firewall',
        'enemy_deck_id_phase2_lv4': 'boss_act1_firewall_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act1_firewall_enraged',
        'hp_multiplier': 1.5,
        'atk_multiplier': 1.3,
        'reward_gold': 200,
        'reward_sp': 2,
        'alert_level_buffs': {
            '4': {'hp_bonus': 5, 'atk_bonus': 1},
            '5': {'hp_bonus': 10, 'atk_bonus': 2}
        },
        'texture': ''
    },
    'boss_kepalos': {
        'display': 'ケパロス',
        'en_name': 'KEPALOS',
        'act': 1,
        'race_theme': 'beast',
        'description': 'パケットを監視する三つ首の番犬',
        'difficulty': 2,
        'enemy_deck_id': 'boss_act1_kepalos',
        'enemy_deck_id_phase2_lv4': 'boss_act1_kepalos_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act1_kepalos_enraged',
        'hp_multiplier': 1.3,
        'atk_multiplier': 1.5,
        'reward_gold': 200,
        'reward_sp': 2,
        'alert_level_buffs': {
            '4': {'hp_bonus': 5, 'atk_bonus': 1},
            '5': {'hp_bonus': 10, 'atk_bonus': 2}
        },
        'texture': ''
    },

    # Act2 5体
    'boss_deadlock': {
        'display': 'デッド・ロック',
        'en_name': 'DEADLOCK',
        'act': 2,
        'race_theme': 'undead',
        'description': '互いに動けなくなる死の錠前',
        'difficulty': 4,
        'enemy_deck_id': 'boss_act2_deadlock',
        'enemy_deck_id_phase2_lv4': 'boss_act2_deadlock_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act2_deadlock_enraged',
        'hp_multiplier': 1.8,
        'atk_multiplier': 1.2,
        'reward_gold': 300,
        'reward_sp': 3,
        'alert_level_buffs': {
            '4': {'hp_bonus': 8, 'atk_bonus': 2},
            '5': {'hp_bonus': 15, 'atk_bonus': 3}
        },
        'texture': ''
    },
    'boss_sandgolem': {
        'display': 'サンド・ゴーレム',
        'en_name': 'SANDGOLEM',
        'act': 2,
        'race_theme': 'mixed',
        'description': '隔離領域を守る人工生命',
        'difficulty': 3,
        'enemy_deck_id': 'boss_act2_sandgolem',
        'enemy_deck_id_phase2_lv4': 'boss_act2_sandgolem_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act2_sandgolem_enraged',
        'hp_multiplier': 2.0,
        'atk_multiplier': 1.0,
        'reward_gold': 300,
        'reward_sp': 3,
        'alert_level_buffs': {
            '4': {'hp_bonus': 10, 'atk_bonus': 1},
            '5': {'hp_bonus': 20, 'atk_bonus': 2}
        },
        'texture': ''
    },
    'boss_cryptor': {
        'display': 'クリプター',
        'en_name': 'CRYPTOR',
        'act': 2,
        'race_theme': 'undead',
        'description': '暗号化された地下墓所の番人',
        'difficulty': 4,
        'enemy_deck_id': 'boss_act2_cryptor',
        'enemy_deck_id_phase2_lv4': 'boss_act2_cryptor_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act2_cryptor_enraged',
        'hp_multiplier': 1.6,
        'atk_multiplier': 1.4,
        'reward_gold': 300,
        'reward_sp': 3,
        'alert_level_buffs': {
            '4': {'hp_bonus': 8, 'atk_bonus': 2},
            '5': {'hp_bonus': 15, 'atk_bonus': 3}
        },
        'texture': ''
    },
    'boss_manoras': {
        'display': 'マノラス',
        'en_name': 'MANORAS',
        'act': 2,
        'race_theme': 'slime',
        'description': 'リソースを人質に取る領主',
        'difficulty': 3,
        'enemy_deck_id': 'boss_act2_manoras',
        'enemy_deck_id_phase2_lv4': 'boss_act2_manoras_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act2_manoras_enraged',
        'hp_multiplier': 1.7,
        'atk_multiplier': 1.3,
        'reward_gold': 300,
        'reward_sp': 3,
        'alert_level_buffs': {
            '4': {'hp_bonus': 8, 'atk_bonus': 2},
            '5': {'hp_bonus': 15, 'atk_bonus': 3}
        },
        'texture': ''
    },
    'boss_null': {
        'display': 'NULL',
        'en_name': 'NULL',
        'act': 2,
        'race_theme': 'mixed',
        'description': '存在しない虚無の存在',
        'difficulty': 5,
        'enemy_deck_id': 'boss_act2_null',
        'enemy_deck_id_phase2_lv4': 'boss_act2_null_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act2_null_enraged',
        'hp_multiplier': 1.5,
        'atk_multiplier': 1.5,
        'reward_gold': 300,
        'reward_sp': 3,
        'alert_level_buffs': {
            '4': {'hp_bonus': 8, 'atk_bonus': 2},
            '5': {'hp_bonus': 15, 'atk_bonus': 3}
        },
        'texture': ''
    },

    # Act3 5体
    'boss_overfit': {
        'display': 'オーバーフィット',
        'en_name': 'OVERFIT',
        'act': 3,
        'race_theme': 'mixed',
        'description': '学習しすぎて狂ったAI',
        'difficulty': 5,
        'enemy_deck_id': 'boss_act3_overfit',
        'enemy_deck_id_phase2_lv4': 'boss_act3_overfit_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act3_overfit_enraged',
        'hp_multiplier': 2.0,
        'atk_multiplier': 1.5,
        'reward_gold': 400,
        'reward_sp': 4,
        'alert_level_buffs': {
            '4': {'hp_bonus': 10, 'atk_bonus': 3},
            '5': {'hp_bonus': 20, 'atk_bonus': 5}
        },
        'texture': ''
    },
    'boss_rootshade': {
        'display': 'ルートキット・シャドウ',
        'en_name': 'ROOTSHADE',
        'act': 3,
        'race_theme': 'undead',
        'description': '見えない脅威',
        'difficulty': 6,
        'enemy_deck_id': 'boss_act3_rootshade',
        'enemy_deck_id_phase2_lv4': 'boss_act3_rootshade_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act3_rootshade_enraged',
        'hp_multiplier': 1.8,
        'atk_multiplier': 1.7,
        'reward_gold': 400,
        'reward_sp': 4,
        'alert_level_buffs': {
            '4': {'hp_bonus': 10, 'atk_bonus': 3},
            '5': {'hp_bonus': 20, 'atk_bonus': 5}
        },
        'texture': ''
    },
    'boss_adversary': {
        'display': 'アドバーサリ',
        'en_name': 'ADVERSARY',
        'act': 3,
        'race_theme': 'mixed',
        'description': '学習して対抗する悪魔',
        'difficulty': 5,
        'enemy_deck_id': 'boss_act3_adversary',
        'enemy_deck_id_phase2_lv4': 'boss_act3_adversary_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act3_adversary_enraged',
        'hp_multiplier': 1.9,
        'atk_multiplier': 1.6,
        'reward_gold': 400,
        'reward_sp': 4,
        'alert_level_buffs': {
            '4': {'hp_bonus': 10, 'atk_bonus': 3},
            '5': {'hp_bonus': 20, 'atk_bonus': 5}
        },
        'texture': ''
    },
    'boss_drifter': {
        'display': 'ドリフター',
        'en_name': 'DRIFTER',
        'act': 3,
        'race_theme': 'slime',
        'description': '漂うデータの幻影',
        'difficulty': 4,
        'enemy_deck_id': 'boss_act3_drifter',
        'enemy_deck_id_phase2_lv4': 'boss_act3_drifter_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act3_drifter_enraged',
        'hp_multiplier': 1.7,
        'atk_multiplier': 1.5,
        'reward_gold': 400,
        'reward_sp': 4,
        'alert_level_buffs': {
            '4': {'hp_bonus': 10, 'atk_bonus': 3},
            '5': {'hp_bonus': 20, 'atk_bonus': 5}
        },
        'texture': ''
    },
    'boss_guardian': {
        'display': 'ガーディアン',
        'en_name': 'GUARDIAN',
        'act': 3,
        'race_theme': 'beast',
        'description': '最後の守護者',
        'difficulty': 6,
        'enemy_deck_id': 'boss_act3_guardian',
        'enemy_deck_id_phase2_lv4': 'boss_act3_guardian_strong',
        'enemy_deck_id_phase2_lv5': 'boss_act3_guardian_enraged',
        'hp_multiplier': 2.2,
        'atk_multiplier': 1.4,
        'reward_gold': 400,
        'reward_sp': 4,
        'alert_level_buffs': {
            '4': {'hp_bonus': 12, 'atk_bonus': 3},
            '5': {'hp_bonus': 25, 'atk_bonus': 5}
        },
        'texture': ''
    },
}

def main():
    json_path = Path('cards.json')

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    bosses = data.get('bosses', {})

    # 既存ボスにen_nameを追加
    print("=== 既存ボスにen_name追加 ===\n")
    for boss_id, en_name in EXISTING_BOSS_EN_NAMES.items():
        if boss_id in bosses:
            bosses[boss_id]['en_name'] = en_name
            display = bosses[boss_id].get('display', boss_id)
            print(f"{boss_id}: {display} → {en_name}")

    # 新規ボスを追加
    print("\n=== 新規ボス追加 ===\n")
    for boss_id, boss_data in NEW_BOSSES.items():
        bosses[boss_id] = boss_data
        print(f"{boss_id}: {boss_data['display']} ({boss_data['en_name']}) - Act{boss_data['act']}")

    # バックアップ作成
    backup_path = Path('cards.json.backup_bosses')
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print(f"\nバックアップ作成: {backup_path}")

    # cards.jsonを更新
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print(f"\n=== 完了 ===")
    print(f"既存ボスen_name追加: {len(EXISTING_BOSS_EN_NAMES)}体")
    print(f"新規ボス追加: {len(NEW_BOSSES)}体")
    print(f"合計ボス数: {len(bosses)}体")
    print("cards.jsonを更新しました")

if __name__ == '__main__':
    main()
