#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
スライムスプライト生成テスト
既存のカードイラストから48×48スプライトを生成
"""
import os
import base64
import json
import requests
from pathlib import Path

# APIキーを環境変数から取得
API_KEY = os.environ.get("GEMINI_API_KEY")
if not API_KEY:
    print("エラー: GEMINI_API_KEY環境変数が設定されていません")
    print("設定方法: export GEMINI_API_KEY='your-api-key'")
    exit(1)

# パス設定
PROJECT_ROOT = Path(__file__).parent.parent.parent
REFERENCE_IMAGE = PROJECT_ROOT / "assets/cards/units/slime_art.png"
OUTPUT_DIR = PROJECT_ROOT / "tools/sprite_gen/data/output"

# プロンプト設定
GLOBAL_STYLE = """
STYLE: pixel art, 16-bit JRPG style, clean outline, centered composition,
flat solid background (#1a1a2e dark navy), no text, no UI, no shadow on ground,
SETTING: bio-digital laboratory experiment, synthetic lifeform, data-ghost,
glitch particles, faint cyan circuit lines, SF horror aesthetic
"""

SLIME_STYLE = """
SUBJECT: gelatinous, translucent, liquid core, floating data fragments,
cyan/violet palette, simple gel blob form, faintly glowing core
"""

SPRITE_SPEC = """
FORMAT: full body, 3/4 top-down view (diagonal overhead perspective), 48x48 pixel sprite, chunky pixels, minimal detail
EXTRACT: Focus ONLY on the large main slime from the reference image.
Ignore small slimes, magic circles, stone tablets, and background elements.
VIEW: Isometric-like angle for tactical board game placement
"""

PROMPT = f"{GLOBAL_STYLE}\n{SLIME_STYLE}\n{SPRITE_SPEC}"

def generate_sprite():
    """スプライトを生成"""

    # reference imageを読み込み
    if not REFERENCE_IMAGE.exists():
        print(f"エラー: {REFERENCE_IMAGE} が見つかりません")
        exit(1)

    with open(REFERENCE_IMAGE, "rb") as f:
        image_data = base64.b64encode(f.read()).decode("utf-8")

    # Gemini API エンドポイント
    # 注: 実際のエンドポイントはGemini APIのバージョンによって異なる可能性があります
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key={API_KEY}"

    # リクエストボディ
    payload = {
        "contents": [{
            "parts": [
                {
                    "text": f"Generate a pixel art sprite based on this reference image and prompt:\n\n{PROMPT}"
                },
                {
                    "inline_data": {
                        "mime_type": "image/png",
                        "data": image_data
                    }
                }
            ]
        }],
        "generationConfig": {
            "temperature": 0.4,
            "topK": 32,
            "topP": 1,
            "maxOutputTokens": 4096,
        }
    }

    print("スプライト生成中...")
    print(f"Reference: {REFERENCE_IMAGE.name}")
    print(f"Prompt: {PROMPT[:100]}...")

    # API呼び出し
    response = requests.post(url, json=payload, headers={"Content-Type": "application/json"})

    if response.status_code != 200:
        print(f"エラー: API呼び出し失敗 (status: {response.status_code})")
        print(f"Response: {response.text}")
        exit(1)

    result = response.json()

    # レスポンス確認
    print(f"API Response: {json.dumps(result, indent=2)[:500]}...")

    # 結果を保存（実際の画像データの抽出方法はAPIレスポンス形式に依存）
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output_path = OUTPUT_DIR / "slime_sprite_test.json"

    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    print(f"結果を保存: {output_path}")
    print("\n注意: Gemini 2.0 Flashはテキスト生成モデルです。")
    print("画像生成にはImagen 3などの専用モデルが必要な可能性があります。")

if __name__ == "__main__":
    generate_sprite()
