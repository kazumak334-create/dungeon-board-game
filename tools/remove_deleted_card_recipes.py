#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
削除されたカードを含む合成レシピを削除
"""
import json
from pathlib import Path

# 削除されたカード
DELETED_CARDS = {
    "スケルトン", "ゾンビの手", "グール", "シャドウ", "レヴナント", "ソウルイーター", "ヴリコラカス",
    "マッドスライム", "ラージスライム", "クリスタルスライム", "ゼリーフィッシュ",
    "パラライズスライム", "ヒートスライム", "ファットスライム", "フロストスライム",
    "ブラッドスライム", "ポイズンスライム",
    "ゴブリン", "ホブゴブリン", "コカトリス", "キリン", "タイガー", "ビャッコ",
    "グリフォン", "ストームホーク", "フェンリスウルフ"
}

def main():
    cards_path = Path(__file__).parent.parent / 'data' / 'cards.json'

    # バックアップから復元
    backup_path = Path(__file__).parent.parent / 'data' / 'cards.json.backup_before_ref_update'
    with open(backup_path, 'r', encoding='utf-8') as f:
        original_data = json.load(f)

    # 現在のデータを読み込み
    with open(cards_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    print("=== 削除カードを含むレシピを削除 ===\n")

    # 合成レシピから削除カードを含むものを削除
    if 'synthesis' in original_data:
        original_synthesis = original_data['synthesis']
        new_synthesis = []

        for recipe in original_synthesis:
            base = recipe.get('base', '')
            card = recipe.get('card', '')
            result = recipe.get('result', '')

            # 削除カードを含むかチェック
            if base in DELETED_CARDS or card in DELETED_CARDS or result in DELETED_CARDS:
                print(f"削除: {base} + {card} → {result}")
            else:
                new_synthesis.append(recipe)

        data['synthesis'] = new_synthesis
        print(f"\n合成レシピ: {len(original_synthesis)}件 → {len(new_synthesis)}件")

    # バックアップ作成
    backup_new = Path(__file__).parent.parent / 'data' / 'cards.json.backup_before_recipe_delete'
    with open(backup_new, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')
    print(f"バックアップ作成: {backup_new.name}")

    # cards.json更新
    with open(cards_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent='\t')

    print("\n削除完了")

if __name__ == '__main__':
    main()
