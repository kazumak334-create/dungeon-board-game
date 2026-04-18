#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
詳細なvisual_hints.json生成スクリプト
各ユニットの特徴（スキル、レアリティ、種族）を反映した20-30単語の記述を生成
"""
import json
from pathlib import Path

# 種族別の基本スタイル
RACE_BASE_STYLES = {
    'スライム': 'gelatinous slime, translucent body, liquid core, floating data fragments',
    '獣': 'bio-mechanical beast, synthetic fur, exposed circuit joints, quadruped form',
    'アンデッド': 'undead entity, skeletal or spectral, tattered cloth, glitching silhouette, corrupted wisps'
}

# レアリティ別の強調要素
RARITY_EMPHASIS = {
    'common': 'simple design, basic form, minimal details',
    'uncommon': 'moderate complexity, distinct features',
    'rare': 'detailed appearance, unique characteristics, striking visual',
    'epic': 'elaborate design, powerful aura, commanding presence',
    'legend': 'legendary appearance, overwhelming presence, intricate details, mythical aura'
}

# 色パレット（スキル/名前から推測）
COLOR_HINTS = {
    # スライム系
    'slime': 'cyan/turquoise',
    'crystal': 'transparent crystal, prismatic',
    'blood': 'deep crimson',
    'mad': 'sickly green',
    'heat': 'orange-red, molten',
    'freeze': 'ice blue, frosty',
    'poison': 'toxic purple-green',
    'electric': 'yellow, crackling',
    'amoeba': 'pale cyan, shapeless',

    # 獣系
    'wolf': 'grey-silver, predatory',
    'tiger': 'orange-black stripes',
    'bear': 'brown, massive',
    'hawk': 'brown-white, aerial',
    'boar': 'dark brown, tusked',
    'fox': 'orange-red, cunning',

    # アンデッド系
    'skeleton': 'bone white, hollow',
    'ghost': 'pale ethereal',
    'zombie': 'rotting grey-green',
    'wraith': 'dark shadow',
    'lich': 'purple-black, arcane',
    'banshee': 'pale blue, wailing'
}

def get_color_from_name(en_name):
    """名前から色のヒントを取得"""
    name_lower = en_name.lower()
    for key, color in COLOR_HINTS.items():
        if key in name_lower:
            return color
    return None

def generate_hint(unit_name, unit_data):
    """ユニットデータから詳細なvisual hintを生成"""
    en_name = unit_data.get('en_name', unit_name)
    race = unit_data.get('race', '')
    rarity = unit_data.get('rarity', 'common')
    skills = unit_data.get('skills', [])

    # 基本スタイル
    base = RACE_BASE_STYLES.get(race, 'mysterious creature')

    # レアリティ要素
    emphasis = RARITY_EMPHASIS.get(rarity, '')

    # 色のヒント
    color = get_color_from_name(en_name)
    color_desc = f"{color} palette" if color else ""

    # スキルから特徴を推測
    skill_hints = []
    for skill in skills[:2]:  # 最大2つのスキル
        effect_id = skill.get('effect_id', '')
        if 'poison' in effect_id:
            skill_hints.append('toxic aura')
        elif 'burn' in effect_id or 'fire' in effect_id:
            skill_hints.append('flaming')
        elif 'freeze' in effect_id or 'ice' in effect_id:
            skill_hints.append('icy')
        elif 'electric' in effect_id or 'paralysis' in effect_id:
            skill_hints.append('electric charged')
        elif 'heal' in effect_id or 'regen' in effect_id:
            skill_hints.append('healing glow')
        elif 'armor' in effect_id or 'shield' in effect_id:
            skill_hints.append('armored')
        elif 'curse' in effect_id:
            skill_hints.append('cursed appearance')

    # 名前から特徴を推測
    name_lower = en_name.lower()
    name_hints = []

    if 'king' in name_lower or 'lord' in name_lower:
        name_hints.append('regal, crowned')
    if 'giant' in name_lower or 'mega' in name_lower:
        name_hints.append('oversized, massive')
    if 'mini' in name_lower or 'small' in name_lower:
        name_hints.append('tiny, compact')
    if 'crystal' in name_lower:
        name_hints.append('crystalline structure')
    if 'shadow' in name_lower or 'dark' in name_lower:
        name_hints.append('shadowy, dark')
    if 'death' in name_lower or 'doom' in name_lower:
        name_hints.append('ominous, death-like')

    # 全要素を組み合わせ
    parts = [base]
    if color_desc:
        parts.append(color_desc)
    if skill_hints:
        parts.extend(skill_hints[:2])
    if name_hints:
        parts.extend(name_hints[:1])
    parts.append(emphasis)

    # 20-30単語に調整
    hint = ', '.join([p for p in parts if p])

    # SF horror aesthetic要素を追加
    hint += ', glitch particles, faint circuit lines, data-ghost appearance'

    return hint

def main():
    # cards.jsonからユニットデータ読み込み
    cards_path = Path(__file__).parent.parent.parent / 'data' / 'cards.json'
    with open(cards_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    units = data.get('units', {})

    # visual_hints生成
    visual_hints = {}

    for unit_name, unit_data in sorted(units.items()):
        en_name = unit_data.get('en_name', unit_name).lower()
        hint = generate_hint(unit_name, unit_data)
        visual_hints[en_name] = hint

    # 出力
    output_path = Path(__file__).parent / 'data' / 'visual_hints.json'
    output_path.parent.mkdir(exist_ok=True)

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(visual_hints, f, indent=2, ensure_ascii=False)

    print(f"visual_hints.jsonを生成しました: {output_path}")
    print(f"ユニット数: {len(visual_hints)}")
    print("\nサンプル（最初の10件）:")
    for i, (key, value) in enumerate(list(visual_hints.items())[:10]):
        word_count = len(value.split())
        print(f"  {key} ({word_count}語): {value[:80]}...")

if __name__ == '__main__':
    main()
