#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
全ユニットにen_nameを追加するスクリプト
"""
import json
import re
from pathlib import Path

# 翻訳辞書（日本語 → 英語）
TRANSLATIONS = {
    # 基本種族
    'スライム': 'Slime',
    'ウルフ': 'Wolf',
    'タイガー': 'Tiger',
    'スケルトン': 'Skeleton',
    'グール': 'Ghoul',
    'バンシー': 'Banshee',
    'リッチ': 'Lich',
    'ゴブリン': 'Goblin',
    'ホーク': 'Hawk',

    # 修飾語
    'キング': 'King',
    'クリスタル': 'Crystal',
    'パラライズ': 'Para',
    'ヒート': 'Heat',
    'ファット': 'Fat',
    'フロスト': 'Frost',
    'ブラッド': 'Blood',
    'ポイズン': 'Poison',
    'マッド': 'Mad',
    'ラージ': 'Large',
    'ワイルド': 'Wild',
    'ストーカー': 'Stalker',
    'ケットシー': 'CaitSith',
    'マンティコア': 'Manticore',
    'コカトリス': 'Cocatrice',
    'フェンリル': 'Fenrir',
    'ゼロフィッシュ': 'Zerofish',
    'ボーンナイト': 'BoneKnight',
    'ワイト': 'Wight',
    'レイス': 'Wraith',
    'デュラハン': 'Dullahan',
    'ボーンドラゴン': 'BoneDragon',
}

# 短縮形ルール（10文字を超える場合）
SHORTHAND = {
    'Slime': 'lob',  # Sparkblob, Voidblobと統一
    'Skeleton': 'Bone',
}

def translate_unit_name(jp_name: str) -> str:
    """日本語のユニット名を英語に翻訳（10文字以内）"""

    # 既に英語の場合はそのまま
    if not re.search(r'[ぁ-んァ-ヶー一-龯]', jp_name):
        return jp_name[:10]  # 念のため10文字制限

    # 翻訳を試みる
    en_name = jp_name

    # 複合語の翻訳（例：クリスタルスライム → Crystal + Slime）
    for jp, en in TRANSLATIONS.items():
        en_name = en_name.replace(jp, en)

    # スライム系は "lob" に短縮
    if 'Slime' in en_name and en_name != 'Slime':
        en_name = en_name.replace('Slime', 'lob')

    # Skeleton系は "Bone" に短縮（必要に応じて）
    if 'Skeleton' in en_name and len(en_name) > 10:
        en_name = en_name.replace('Skeleton', 'Bone')

    # 10文字を超える場合は短縮
    if len(en_name) > 10:
        # スペースを削除
        en_name = en_name.replace(' ', '')

    # それでも超える場合は切り詰め
    if len(en_name) > 10:
        en_name = en_name[:10]

    return en_name

def main():
    # cards.jsonを読み込み
    json_path = Path('cards.json')

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    units = data.get('units', {})
    updated_count = 0

    print("=== en_name自動生成 ===\n")

    for unit_id, unit_data in units.items():
        unit_name = unit_data.get('unit_name', unit_id)
        current_en = unit_data.get('en_name', '')

        # en_nameが未設定の場合のみ追加
        if not current_en:
            new_en_name = translate_unit_name(unit_name)
            unit_data['en_name'] = new_en_name
            updated_count += 1
            print(f"{unit_name} → {new_en_name} ({len(new_en_name)}文字)")

    # バックアップを作成
    backup_path = Path('cards.json.backup_en_names')
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print(f"\nバックアップ作成: {backup_path}")

    # cards.jsonを更新
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print(f"\n=== 完了 ===")
    print(f"更新したユニット数: {updated_count}体")
    print(f"cards.jsonを更新しました")

if __name__ == '__main__':
    main()
