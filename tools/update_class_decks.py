#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
削除されたカードをクラス初期デッキから置き換え
"""
import json
from pathlib import Path

# 削除されたカード → 置き換え先カード
REPLACEMENTS = {
    # Alchemist (スライム系)
    "マッドスライム": "Mudblob",
    "ブラッドスライム": "Venpool",

    # Berserker (獣系)
    "ゴブリン": "Fangos",
    "タイガー": "Rageveil",

    # Necromancer (アンデッド系)
    "スケルトン": "カースシード",
    "グール": "グリムハウル",
}

def main():
    cards_path = Path(__file__).parent.parent / 'data' / 'cards.json'
    with open(cards_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    classes = data.get('classes', {})

    print("=== クラス初期デッキ更新 ===\n")

    for class_name, class_data in classes.items():
        initial_deck = class_data.get('initial_deck', [])
        updated = False

        new_deck = []
        for card_name in initial_deck:
            if card_name in REPLACEMENTS:
                replacement = REPLACEMENTS[card_name]
                new_deck.append(replacement)
                print(f"{class_data['display']}: {card_name} → {replacement}")
                updated = True
            else:
                new_deck.append(card_name)

        if updated:
            class_data['initial_deck'] = new_deck

    # バックアップ作成
    backup_path = Path(__file__).parent.parent / 'data' / 'cards.json.backup_before_class_update'
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')
    print(f"\nバックアップ作成: {backup_path.name}")

    # cards.json更新
    with open(cards_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print("\n=== 更新後の初期デッキ ===\n")
    for class_name, class_data in classes.items():
        print(f"{class_data['display']}:")
        for card in class_data['initial_deck']:
            print(f"  - {card}")
        print()

    print("クラス初期デッキ更新完了")

if __name__ == '__main__':
    main()
