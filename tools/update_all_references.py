#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
削除されたカードへの全参照を置き換え
"""
import json
from pathlib import Path

# 削除されたカード → 置き換え先カード
REPLACEMENTS = {
    # アンデッド系
    "スケルトン": "カースシード",
    "ゾンビの手": "ヘクススポーン",
    "グール": "グリムハウル",
    "シャドウ": "カーシール",
    "レヴナント": "ワイト",
    "ソウルイーター": "デュラハン",
    "ヴリコラカス": "トレイトベイン",

    # スライム系
    "マッドスライム": "Mudblob",
    "ラージスライム": "Granob",
    "クリスタルスライム": "Crystel",
    "ゼリーフィッシュ": "Glitzel",
    "パラライズスライム": "Sparkblob",
    "ヒートスライム": "Venpool",
    "ファットスライム": "Granob",
    "フロストスライム": "Crystel",
    "ブラッドスライム": "Venpool",
    "ポイズンスライム": "Plagzel",

    # 獣系
    "ゴブリン": "Fangos",
    "ホブゴブリン": "Piercor",
    "コカトリス": "Thornbeast",
    "キリン": "Rageveil",
    "タイガー": "Rageveil",
    "ビャッコ": "Manticore",
    "グリフォン": "Manticore",
    "ストームホーク": "ワイルドホーク",
    "フェンリスウルフ": "ウルフ",
}

def replace_in_dict(d, key_path=[]):
    """辞書内の文字列を再帰的に置き換え"""
    if isinstance(d, dict):
        for key, value in d.items():
            if isinstance(value, str) and value in REPLACEMENTS:
                old_value = value
                d[key] = REPLACEMENTS[value]
                print(f"  置換: {'/'.join(key_path + [key])} = {old_value} → {d[key]}")
            elif isinstance(value, (dict, list)):
                replace_in_dict(value, key_path + [key])
    elif isinstance(d, list):
        for i, item in enumerate(d):
            if isinstance(item, str) and item in REPLACEMENTS:
                old_value = item
                d[i] = REPLACEMENTS[item]
                print(f"  置換: {'/'.join(key_path)}[{i}] = {old_value} → {d[i]}")
            elif isinstance(item, (dict, list)):
                replace_in_dict(item, key_path + [f"[{i}]"])

def main():
    cards_path = Path(__file__).parent.parent / 'data' / 'cards.json'
    with open(cards_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    print("=== 削除カード参照の全置換 ===\n")

    # 全データを再帰的に走査して置換
    print("ボスデータ置換:")
    if 'bosses' in data:
        replace_in_dict(data['bosses'], ['bosses'])

    print("\n合成レシピ置換:")
    if 'synergy' in data:
        replace_in_dict(data['synergy'], ['synergy'])

    print("\nその他のデータ置換:")
    for key in data:
        if key not in ['units', 'spells', 'bosses', 'classes', 'synergy']:
            replace_in_dict(data[key], [key])

    # バックアップ作成
    backup_path = Path(__file__).parent.parent / 'data' / 'cards.json.backup_before_ref_update'
    with open(backup_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')
    print(f"\nバックアップ作成: {backup_path.name}")

    # cards.json更新
    with open(cards_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print("\n全参照の置換完了")

if __name__ == '__main__':
    main()
