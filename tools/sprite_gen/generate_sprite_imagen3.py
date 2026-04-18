#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
スライムスプライト生成 - Imagen 3
既存のカードイラストから48×48スプライトを生成
"""
import os
from pathlib import Path
from google import genai
from google.genai import types
from PIL import Image
from io import BytesIO
from dotenv import load_dotenv

# .envファイルから環境変数を読み込み
project_root = Path(__file__).parent.parent.parent
load_dotenv(project_root / ".env")

# APIキーを取得
API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY:
    env_file = project_root / ".env"
    if env_file.exists():
        API_KEY = env_file.read_text(encoding='utf-8').strip().split('\n')[0].strip()

if not API_KEY:
    print("=" * 60)
    print("エラー: GEMINI_API_KEY環境変数が設定されていません")
    print("=" * 60)
    exit(1)

# パス設定
REFERENCE_IMAGE = project_root / "assets/cards/units/slime_art.png"
OUTPUT_DIR = project_root / "tools/sprite_gen/data/output"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# プロンプト設定
PROMPT = """
Generate a 48x48 pixel art sprite of a slime creature.

REFERENCE: Based on the large main slime visible in reference materials
- Extract ONLY the large main slime
- Ignore small slimes, magic circles, stone tablets, background elements

STYLE:
- Pixel art, 16-bit JRPG style
- Clean outline, chunky pixels, minimal detail
- 3/4 top-down view (diagonal overhead perspective)
- Isometric-like angle for tactical board game placement

APPEARANCE:
- Translucent cyan/green gelatinous form
- Glowing core (faint cyan light)
- Bio-digital laboratory experiment aesthetic
- Synthetic lifeform, data-ghost
- Glitch particles, faint cyan circuit lines
- SF horror aesthetic

BACKGROUND:
- Flat solid dark navy blue (#1a1a2e)
- No text, no UI elements, no ground shadow

OUTPUT: 48x48 pixel sprite suitable for game board placement
"""

def generate_sprite():
    """Imagen 3でスプライトを生成"""

    print("=" * 60)
    print("スライムスプライト生成開始 (Imagen 3)")
    print("=" * 60)
    print(f"Model: imagen-3.0-generate-002")
    print(f"Output: {OUTPUT_DIR}")
    print(f"料金: $0.03/枚")
    print()

    # Gemini クライアント初期化
    client = genai.Client(api_key=API_KEY)

    # 画像生成リクエスト
    print("生成中...")
    try:
        response = client.models.generate_images(
            model='imagen-3.0-generate-002',
            prompt=PROMPT,
            config=types.GenerateImagesConfig(
                number_of_images=3,  # 3パターン生成
                aspect_ratio='1:1',  # 正方形
                safety_filter_level='BLOCK_ONLY_HIGH',
            )
        )

        # 結果を保存
        saved_count = 0
        for idx, generated_image in enumerate(response.generated_images):
            # 画像を読み込み
            image = Image.open(BytesIO(generated_image.image.image_bytes))

            # 48x48にリサイズ（Nearest Neighbor = ピクセルアートに最適）
            resized = image.resize((48, 48), Image.Resampling.NEAREST)

            # 保存
            output_path = OUTPUT_DIR / f"slime_sprite_imagen3_v{idx+1}.png"
            resized.save(output_path)

            print(f"✓ 保存: {output_path.name} (元サイズ: {image.size})")
            saved_count += 1

        print()
        print("=" * 60)
        print(f"✓ 完了: {saved_count}枚のスプライトを生成しました")
        print(f"合計料金: ${saved_count * 0.03:.2f}")
        print("=" * 60)

    except Exception as e:
        print(f"エラー: {e}")
        print("\n確認事項:")
        print("1. Google Cloud Consoleで課金が有効になっているか")
        print("2. Vertex AI APIが有効になっているか")
        print("3. APIキーに適切な権限があるか")
        exit(1)

if __name__ == "__main__":
    generate_sprite()
