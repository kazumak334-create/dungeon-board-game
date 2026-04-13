#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
召喚系カードクリーンアップスクリプト
"""
import json
import sys

def main():
    # cards.jsonを読み込み
    with open('cards.json', 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 召喚系呪文を特定
    summon_spells = []
    for spell_name, spell_data in data.get("spells", {}).items():
        is_summon = False
        for skill in spell_data.get("skills", []):
            target = skill.get("target", "")
            effect_id = skill.get("effect_id", "")
            # _deckターゲットまたはsummon/inject/shuffle系effect_id
            if "_deck" in target or "summon" in effect_id or "inject" in effect_id or "shuffle" in effect_id:
                is_summon = True
                break
        if is_summon:
            summon_spells.append(spell_name)

    print(f"Found {len(summon_spells)} summon-based spells:")
    for spell_name in sorted(summon_spells):
        print(f"  - {spell_name}")

    # 召喚系呪文を削除
    for spell_name in summon_spells:
        del data["spells"][spell_name]

    # enemy_deckを削除
    if "enemy_deck" in data:
        print("\nRemoving enemy_deck section")
        del data["enemy_deck"]

    # player_deckを削除
    if "player_deck" in data:
        print("Removing player_deck section")
        del data["player_deck"]

    # 保存
    with open('cards.json', 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent="\t")

    print(f"\nCleanup complete! Removed {len(summon_spells)} spells and deck sections.")

if __name__ == "__main__":
    main()
