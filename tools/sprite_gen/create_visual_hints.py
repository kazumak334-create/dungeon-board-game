#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
visual_hints.json生成スクリプト
cards.jsonから全ユニットを読み込み、en_nameベースでvisual hintsのテンプレートを作成
"""
import json
from pathlib import Path

def main():
    # cards.jsonからユニットデータ読み込み
    cards_path = Path(__file__).parent.parent.parent / 'data' / 'cards.json'
    with open(cards_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    units = data.get('units', {})

    # en_nameでソート
    sorted_units = sorted(
        [(name, unit) for name, unit in units.items()],
        key=lambda x: x[1].get('en_name', x[0])
    )

    # visual_hints生成
    visual_hints = {}

    for unit_name, unit_data in sorted_units:
        en_name = unit_data.get('en_name', unit_name)
        race = unit_data.get('race', '')

        # プレースホルダー（後で手動で埋める）
        hint = f"[TODO: {en_name}の詳細な外見記述（20-30単語）]"

        # 種族に応じた基本的なヒントを追加
        if race == 'スライム':
            hint = f"{en_name.lower()} slime variant, gelatinous form, [TODO: 色・特徴を追加]"
        elif race == '獣':
            hint = f"{en_name.lower()} beast, quadruped or aggressive form, [TODO: 色・特徴を追加]"
        elif race == 'アンデッド':
            hint = f"{en_name.lower()} undead, skeletal or spectral, [TODO: 色・特徴を追加]"

        visual_hints[en_name.lower()] = hint

    # 出力
    output_path = Path('data/visual_hints.json')
    output_path.parent.mkdir(exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(visual_hints, f, indent=2, ensure_ascii=False)

    print(f"visual_hints.jsonを生成しました: {output_path}")
    print(f"ユニット数: {len(visual_hints)}")
    print("\n最初の5件:")
    for i, (key, value) in enumerate(list(visual_hints.items())[:5]):
        print(f"  {key}: {value}")

    print("\n次のステップ:")
    print("1. visual_hints.jsonを開く")
    print("2. 各ユニットの[TODO]部分を詳細な外見記述（20-30単語）で埋める")
    print("3. 完成したらGoogle Driveにアップロード")

if __name__ == '__main__':
    main()
