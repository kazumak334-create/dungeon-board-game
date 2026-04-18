#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
全カードリスト表示スクリプト（ファイル出力版）
"""
import json
from pathlib import Path

def main():
    cards_path = Path(__file__).parent.parent / 'data' / 'cards.json'
    with open(cards_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    units = data.get('units', {})

    # レアリティマーク
    rarity_marks = {
        'common': 'C',
        'uncommon': 'U',
        'rare': 'R',
        'epic': 'E',
        'legend': 'L',
        'boss': 'B',
        'god': 'G'
    }

    # 種族別・レアリティ順でソート
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

    # 出力用リスト
    lines = []
    lines.append("=" * 80)
    lines.append("全カードリスト (72体)")
    lines.append("=" * 80)

    current_race = None
    no = 1

    for name, unit in sorted_units:
        race = unit.get('race', '')
        rarity = unit.get('rarity', 'common')
        en_name = unit.get('en_name', name)
        hp = int(unit.get('hp', 0))
        atk = int(unit.get('atk', 0))
        spd = float(unit.get('spd', 1.0))
        mana = int(unit.get('mana', 0))

        rarity_mark = rarity_marks.get(rarity, '?')

        # 種族ヘッダー
        if race != current_race:
            if current_race is not None:
                lines.append("")
            lines.append(f"\n【{race}】")
            lines.append("-" * 80)
            current_race = race

        # カード情報
        lines.append(f"No.{no:2d} [{rarity_mark}] {name:12s} ({en_name:15s}) HP:{hp:3d} ATK:{atk:2d} SPD:{spd:.1f} マナ:{mana}")
        no += 1

    lines.append("\n" + "=" * 80)
    lines.append(f"合計: {len(sorted_units)}体")
    lines.append("=" * 80)

    # ファイル出力
    output_path = Path(__file__).parent / 'card_list.txt'
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))

    print(f"カードリストを出力しました: {output_path}")

if __name__ == '__main__':
    main()
