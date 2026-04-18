#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
指定番号のカードを削除するスクリプト
"""
import json
from pathlib import Path

# 削除対象の番号
REMOVE_NUMBERS = [2,3,7,8,16,18,21,33,34,39,40,41,42,43,44,45,46,54,55,62,65,66,67,69,70,71]

def main():
    cards_path = Path(__file__).parent.parent / 'data' / 'cards.json'
    with open(cards_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    units = data.get('units', {})

    # レアリティ順でソート（番号を再現）
    race_order = {'アンデッド': 0, 'スライム': 1, '獣': 2}
    rarity_order = {'common': 0, 'uncommon': 1, 'rare': 2, 'epic': 3, 'legend': 4, 'boss': 5, 'god': 6}

    sorted_units = sorted(
        units.items(),
        key=lambda x: (
            race_order.get(x[1].get('race', ''), 99),
            rarity_order.get(x[1].get('rarity', 'common'), 0),
            x[0]
        )
    )

    # 削除対象を特定
    units_to_remove = []
    for i, (name, unit) in enumerate(sorted_units, 1):
        if i in REMOVE_NUMBERS:
            en_name = unit.get('en_name', name)
            units_to_remove.append((name, en_name))
            print(f"削除: No.{i:2d} {name} ({en_name})")

    print(f"\n削除対象: {len(units_to_remove)}体")
    print(f"残存: {len(units) - len(units_to_remove)}体")

    # cards.jsonから削除
    for name, en_name in units_to_remove:
        if name in data['units']:
            del data['units'][name]

    # バックアップ作成
    backup_path = Path(__file__).parent.parent / 'data' / 'cards.json.backup_before_remove'
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')
    print(f"\nバックアップ作成: {backup_path.name}")

    # cards.json更新
    with open(cards_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')
    print(f"cards.json更新完了: {len(data['units'])}体")

    # visual_hints.json更新
    visual_hints_path = Path(__file__).parent / 'sprite_gen' / 'data' / 'visual_hints.json'
    if visual_hints_path.exists():
        with open(visual_hints_path, 'r', encoding='utf-8') as f:
            visual_hints = json.load(f)

        # 削除対象のen_nameを小文字化してキーを探す
        removed_count = 0
        for name, en_name in units_to_remove:
            key = en_name.lower()
            if key in visual_hints:
                del visual_hints[key]
                removed_count += 1

        # visual_hints.json更新
        with open(visual_hints_path, 'w', encoding='utf-8') as f:
            json.dump(visual_hints, f, ensure_ascii=False, indent=2)
        print(f"visual_hints.json更新完了: {len(visual_hints)}体（{removed_count}体削除）")
    else:
        print("visual_hints.jsonが見つかりません")

    print("\n削除完了！")
    print(f"最終カード数: {len(data['units'])}体")

if __name__ == '__main__':
    main()
