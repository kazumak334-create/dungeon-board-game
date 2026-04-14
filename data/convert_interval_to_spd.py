#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
interval → SPD変換スクリプト
SPD = 1.0 / interval
"""
import json
import sys

def main():
    # cards.jsonを読み込み
    with open('cards.json', 'r', encoding='utf-8') as f:
        data = json.load(f)

    # ユニットのinterval → SPD変換
    units = data.get("units", {})
    converted_count = 0

    for unit_name, unit_data in units.items():
        if "interval" in unit_data:
            interval = unit_data["interval"]
            if interval > 0:
                spd = 1.0 / interval
                unit_data["spd"] = round(spd, 5)  # 小数点5桁で丸める
                del unit_data["interval"]
                converted_count += 1
                print(f"{unit_name}: interval={interval:.2f} → SPD={spd:.3f}")

    # boss_exclusive_unitsのinterval → SPD変換
    boss_units = data.get("boss_exclusive_units", {})
    for unit_name, unit_data in boss_units.items():
        if "interval" in unit_data:
            interval = unit_data["interval"]
            if interval > 0:
                spd = 1.0 / interval
                unit_data["spd"] = round(spd, 3)
                del unit_data["interval"]
                converted_count += 1
                print(f"[BOSS] {unit_name}: interval={interval:.2f} → SPD={spd:.3f}")

    # 保存
    with open('cards.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent="\t")

    print(f"\n変換完了: {converted_count}体のユニット")

if __name__ == "__main__":
    main()
