#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
batch_generate.py
Phase 2最優先グラフィックを一括生成する
"""

import os
import sys
import json
import time
from pathlib import Path
from generate_image import generate_image

# プロジェクトルート
project_root = Path(__file__).resolve().parent.parent

# ========== 生成対象定義 ==========

# 1. クラス選択イラスト（260×160px）
CLASS_ILLUSTRATIONS = [
    {
        "name": "class_alchemist",
        "prompt": "スライム錬金術師、緑のローブを着た中世の錬金術師、周囲に緑色のスライム生物が浮遊、ダークファンタジー、縦長イラスト",
        "style": "card_art"
    },
    {
        "name": "class_berserker",
        "prompt": "バーサーカー戦士、獣の毛皮を着た筋肉質の戦士、背後に狼と虎のシルエット、ダークファンタジー、縦長イラスト",
        "style": "card_art"
    },
    {
        "name": "class_necromancer",
        "prompt": "死霊術師、黒いフードを被った術師、周囲に骸骨と幽霊が浮遊、ダークファンタジー、縦長イラスト",
        "style": "card_art"
    }
]

# 2. バフ/デバフアイコン（16×16px）
BUFF_DEBUFF_ICONS = [
    # バフ系
    {"name": "icon_atk_buff", "prompt": "剣が赤く光るアイコン、シンプル", "style": "icon"},
    {"name": "icon_spd_buff", "prompt": "稲妻のアイコン、黄色、シンプル", "style": "icon"},
    {"name": "icon_vampire", "prompt": "血のしずくアイコン、赤、シンプル", "style": "icon"},
    {"name": "icon_pierce", "prompt": "貫通する矢印アイコン、白、シンプル", "style": "icon"},
    {"name": "icon_armor", "prompt": "盾のアイコン、銀色、シンプル", "style": "icon"},
    {"name": "icon_regen", "prompt": "緑の葉とハートのアイコン、シンプル", "style": "icon"},

    # デバフ系
    {"name": "icon_burn", "prompt": "炎のアイコン、オレンジ、シンプル", "style": "icon"},
    {"name": "icon_freeze", "prompt": "氷の結晶アイコン、青、シンプル", "style": "icon"},
    {"name": "icon_paralyze", "prompt": "稲妻に打たれた人型アイコン、紫、シンプル", "style": "icon"},
    {"name": "icon_poison", "prompt": "毒のしずくアイコン、緑、シンプル", "style": "icon"},

    # スキル系
    {"name": "icon_fly", "prompt": "羽根アイコン、白、シンプル", "style": "icon"},
    {"name": "icon_revive", "prompt": "復活の光アイコン、金色、シンプル", "style": "icon"},
    {"name": "icon_sniper", "prompt": "照準アイコン、赤、シンプル", "style": "icon"},
    {"name": "icon_support", "prompt": "剣を交差したアイコン、シンプル", "style": "icon"},
    {"name": "icon_self_revive", "prompt": "不死鳥の羽根アイコン、金色、シンプル", "style": "icon"},
]

# 3. 盤面効果アイコン
FIELD_EFFECT_ICONS = [
    {"name": "icon_thorn", "prompt": "棘の床アイコン、茶色、シンプル", "style": "icon"},
    {"name": "icon_curse", "prompt": "呪いの紫の霧アイコン、シンプル", "style": "icon"},
    {"name": "icon_crack", "prompt": "ヒビ割れアイコン、グレー、シンプル", "style": "icon"},
    {"name": "icon_poison_swamp", "prompt": "毒沼アイコン、緑の泡、シンプル", "style": "icon"},
    {"name": "icon_fortress", "prompt": "砦の壁アイコン、石、シンプル", "style": "icon"},
    {"name": "icon_beast_forest", "prompt": "獣の森アイコン、緑の木、シンプル", "style": "icon"},
]

def generate_batch(target_list: list, category_name: str):
    """カテゴリごとに一括生成"""
    print(f"\n{'='*60}")
    print(f"カテゴリ: {category_name}")
    print(f"対象数: {len(target_list)}")
    print(f"{'='*60}\n")

    success_count = 0
    failed = []

    for i, item in enumerate(target_list, 1):
        print(f"\n[{i}/{len(target_list)}] {item['name']}")
        try:
            result_path = generate_image(
                prompt=item['prompt'],
                name=item['name'],
                style=item.get('style', 'pixel_art')
            )
            success_count += 1
            print(f"✅ 成功: {result_path}")

            # API制限回避のため少し待機
            if i < len(target_list):
                print("⏳ 3秒待機...")
                time.sleep(3)

        except Exception as e:
            print(f"❌ 失敗: {e}")
            failed.append(item['name'])

    print(f"\n{'='*60}")
    print(f"{category_name} 完了: {success_count}/{len(target_list)} 成功")
    if failed:
        print(f"失敗: {', '.join(failed)}")
    print(f"{'='*60}\n")

def main():
    """メイン実行"""
    print("="*60)
    print("Phase 2 最優先グラフィック一括生成")
    print("="*60)

    # 生成前確認
    print("\n生成対象:")
    print(f"1. クラス選択イラスト: {len(CLASS_ILLUSTRATIONS)}種")
    print(f"2. バフ/デバフアイコン: {len(BUFF_DEBUFF_ICONS)}種")
    print(f"3. 盤面効果アイコン: {len(FIELD_EFFECT_ICONS)}種")
    print(f"\n合計: {len(CLASS_ILLUSTRATIONS) + len(BUFF_DEBUFF_ICONS) + len(FIELD_EFFECT_ICONS)}枚")

    response = input("\n生成を開始しますか？ (y/N): ")
    if response.lower() != 'y':
        print("キャンセルしました")
        sys.exit(0)

    # 1. クラス選択イラスト
    generate_batch(CLASS_ILLUSTRATIONS, "クラス選択イラスト")

    # 2. バフ/デバフアイコン
    generate_batch(BUFF_DEBUFF_ICONS, "バフ/デバフアイコン")

    # 3. 盤面効果アイコン
    generate_batch(FIELD_EFFECT_ICONS, "盤面効果アイコン")

    print("\n" + "="*60)
    print("全生成完了！")
    print("="*60)

if __name__ == "__main__":
    main()
