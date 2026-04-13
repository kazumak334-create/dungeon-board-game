#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
SPD値を10スケールに変換
旧SPD = 1/interval → 新SPD = 10/interval（整数化）
"""
import json
import sys

def main():
    # cards.jsonを読み込み
    with open('cards.json', 'r', encoding='utf-8') as f:
        data = json.load(f)

    # ユニットのSPD変換
    units = data.get("units", {})
    converted_count = 0

    for unit_name, unit_data in units.items():
        if "spd" in unit_data:
            old_spd = unit_data["spd"]
            new_spd = round(old_spd * 10)  # 10倍して整数化
            unit_data["spd"] = new_spd
            converted_count += 1
            print(f"{unit_name}: SPD {old_spd:.3f} → {new_spd}")

    # boss_exclusive_unitsのSPD変換
    boss_units = data.get("boss_exclusive_units", {})
    for unit_name, unit_data in boss_units.items():
        if "spd" in unit_data:
            old_spd = unit_data["spd"]
            new_spd = round(old_spd * 10)
            unit_data["spd"] = new_spd
            converted_count += 1
            print(f"[BOSS] {unit_name}: SPD {old_spd:.3f} → {new_spd}")

    # 保存
    with open('cards.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent="\t")

    print(f"\n変換完了: {converted_count}体のユニット")

if __name__ == "__main__":
    main()
