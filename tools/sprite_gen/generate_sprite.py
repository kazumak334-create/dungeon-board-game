#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
スライムスプライト生成テスト - Gemini Image Generation
既存のカードイラストから48×48スプライトを生成
"""
import os
from pathlib import Path
from google import genai
from google.genai import types
from PIL import Image
from dotenv import load_dotenv

# .envファイルから環境変数を読み込み（プロジェクトルートを優先）
project_root = Path(__file__).parent.parent.parent
load_dotenv(project_root / ".env")  # プロジェクトルートの.env
load_dotenv(Path(__file__).parent / ".env")  # tools/sprite_gen/.env（上書き）

# APIキーを取得（環境変数 or .envファイルの1行目）
API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY:
    # .envファイルの1行目をAPIキーとして読み込み
    env_file = project_root / ".env"
    if env_file.exists():
        API_KEY = env_file.read_text(encoding='utf-8').strip().split('\n')[0].strip()

if not API_KEY:
    print("=" * 60)
    print("エラー: GEMINI_API_KEY環境変数が設定されていません")
    print("=" * 60)
    print("\n設定方法:")
    print("  Windows (PowerShell):")
    print("    $env:GEMINI_API_KEY='your-api-key-here'")
    print("\n  Linux/Mac:")
    print("    export GEMINI_API_KEY='your-api-key-here'")
    print("\nAPIキー取得方法:")
    print("  https://aistudio.google.com/app/apikey")
    print("=" * 60)
    exit(1)

# パス設定
PROJECT_ROOT = Path(__file__).parent.parent.parent
REFERENCE_IMAGE = PROJECT_ROOT / "assets/cards/units/slime_art.png"
OUTPUT_DIR = PROJECT_ROOT / "tools/sprite_gen/data/output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# プロンプト設定
PROMPT = """
Generate a 48x48 pixel art sprite based on the reference image.

EXTRACT INSTRUCTIONS:
- Extract ONLY the large main slime from the reference image
- Ignore small slimes, magic circles, stone tablets, and background elements
- Focus on the translucent cyan/green gelatinous form with glowing core

STYLE REQUIREMENTS:
- Pixel art, 16-bit JRPG style
- Clean outline, chunky pixels, minimal detail
- 3/4 top-down view (diagonal overhead perspective for tactical board game)
- Isometric-like angle suitable for board placement
- Flat solid background (#1a1a2e dark navy blue)
- No text, no UI elements, no ground shadow

AESTHETIC:
- Bio-digital laboratory experiment
- Synthetic lifeform, data-ghost
- Glitch particles, faint cyan circuit lines
- SF horror aesthetic
- Gelatinous, translucent, liquid core
- Floating data fragments
- Cyan/violet palette, faintly glowing core

OUTPUT: 48x48 pixel sprite, suitable for game board placement
"""

def generate_sprite():
    """スプライトを生成"""

    # reference imageの確認
    if not REFERENCE_IMAGE.exists():
        print(f"エラー: {REFERENCE_IMAGE} が見つかりません")
        exit(1)

    print("=" * 60)
    print("スライムスプライト生成開始")
    print("=" * 60)
    print(f"Reference: {REFERENCE_IMAGE}")
    print(f"Model: gemini-2.5-flash-image (image generation)")
    print(f"Output: {OUTPUT_DIR}")
    print()

    # Gemini クライアント初期化
    client = genai.Client(api_key=API_KEY)

    # 画像生成リクエスト
    print("生成中...")
    try:
        response = client.models.generate_content(
            model="models/gemini-2.5-flash-image",  # Gemini 2.5 Flash Image
            contents=[
                PROMPT,
                Image.open(REFERENCE_IMAGE),
            ],
            config=types.GenerateContentConfig(
                response_modalities=['IMAGE'],  # 画像のみ出力
                image_config=types.ImageConfig(
                    aspect_ratio="1:1",  # 正方形
                    image_size="256"     # 256x256で生成後、リサイズ
                ),
            )
        )

        # 結果を保存
        saved_count = 0
        for idx, part in enumerate(response.parts):
            if image := part.as_image():
                output_path = OUTPUT_DIR / f"slime_sprite_v{idx+1}.png"

                # 48x48にリサイズ（Nearest Neighbor = ピクセルアートに最適）
                resized = image.resize((48, 48), Image.Resampling.NEAREST)
                resized.save(output_path)

                print(f"✓ 保存: {output_path}")
                saved_count += 1

        if saved_count == 0:
            print("⚠ 警告: 画像が生成されませんでした")
            print("レスポンス:")
            for part in response.parts:
                if part.text:
                    print(part.text)
        else:
            print()
            print("=" * 60)
            print(f"✓ 完了: {saved_count}枚のスプライトを生成しました")
            print("=" * 60)

    except Exception as e:
        print(f"エラー: {e}")
        print("\n注意:")
        print("- gemini-2.0-flash-exp は実験版です")
        print("- モデル名を gemini-3.1-flash-image-preview に変更してみてください")
        exit(1)

if __name__ == "__main__":
    generate_sprite()
