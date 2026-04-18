#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
interval キー参照を spd に一括修正
"""
import re
from pathlib import Path

# 修正対象ファイルと修正パターン
FIXES = [
    # DevUI.gd
    {
        "file": "scripts/DevUI.gd",
        "replacements": [
            (r'obj\.attack_interval = d\["interval"\]', 'obj.spd = d["spd"]'),
            (r'd\["interval"\](?=\s*\])', '10.0 / d["spd"]'),  # 配列内の参照
        ]
    },
    # EffectActions.gd
    {
        "file": "scripts/EffectActions.gd",
        "replacements": [
            (r'new_unit\.attack_interval = ud\["interval"\]', 'new_unit.spd = ud["spd"]'),
        ]
    },
    # EnemyPlacementHelper.gd
    {
        "file": "scripts/EnemyPlacementHelper.gd",
        "replacements": [
            (r'u\.attack_interval = d\["interval"\]', 'u.spd = d["spd"]'),
        ]
    },
    # InitialCardPick.gd
    {
        "file": "scripts/InitialCardPick.gd",
        "replacements": [
            (r'view\.spd = int\(data\.get\("interval", 1\.0\)\)', 'view.spd = int(10.0 / data.get("spd", 1.0))'),
        ]
    },
    # Main.gd
    {
        "file": "scripts/Main.gd",
        "replacements": [
            (r'u\.attack_interval = r\["interval"\]', 'u.spd = r["spd"]'),
            (r'unit\.attack_interval = unit_data\["interval"\]', 'unit.spd = unit_data["spd"]'),
        ]
    },
    # Result.gd
    {
        "file": "scripts/Result.gd",
        "replacements": [
            (r'data\.get\("interval", 0\)', '10.0 / data.get("spd", 1.0)'),
        ]
    },
]

def main():
    base_path = Path(__file__).parent.parent

    print("=== interval キー参照修正 ===\n")

    total_changes = 0

    for fix in FIXES:
        file_path = base_path / fix["file"]

        if not file_path.exists():
            print(f"SKIP: {fix['file']} (ファイルなし)")
            continue

        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content
        changes = 0

        for pattern, replacement in fix["replacements"]:
            new_content = re.sub(pattern, replacement, content)
            if new_content != content:
                changes += content.count(re.search(pattern, content).group(0)) if re.search(pattern, content) else 0
                content = new_content

        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"OK: {fix['file']} ({changes}箇所)")
            total_changes += changes
        else:
            print(f"SKIP: {fix['file']} (変更なし)")

    print(f"\n合計: {total_changes}箇所修正")

if __name__ == '__main__':
    main()
