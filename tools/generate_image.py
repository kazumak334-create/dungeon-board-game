#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generate_image.py
Gemini APIを使用してゲームアセット画像を生成する
"""

import os
import sys
import argparse
from pathlib import Path
from dotenv import load_dotenv

# プロジェクトルートから.envを読み込む
project_root = Path(__file__).resolve().parent.parent
load_dotenv(project_root / ".env")

# Gemini SDK
try:
    from google import genai
    from google.genai.types import GenerateImageConfig
except ImportError:
    print("エラー: google-genai ライブラリがインストールされていません")
    print("以下のコマンドでインストールしてください：")
    print("pip install google-genai Pillow python-dotenv")
    sys.exit(1)

# スタイルプリセット
STYLE_PRESETS = {
    "pixel_art": "ドット絵、16x16ピクセル、ゲームアイコン風",
    "dark_fantasy": "ダークファンタジー、モノクロ、細密画風",
    "card_art": "カードゲームイラスト、縦長、ダークファンタジー風",
    "icon": "シンプルなゲームアイコン、黒背景、発光エフェクト",
}

def generate_image(prompt: str, name: str, style: str = "pixel_art"):
    """Gemini APIで画像を生成する"""

    # APIキー確認
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("エラー: GEMINI_API_KEY が設定されていません")
        print("プロジェクトルートに .env ファイルを作成し、以下を追加してください：")
        print("GEMINI_API_KEY=あなたのAPIキー")
        sys.exit(1)

    # クライアント初期化
    client = genai.Client(api_key=api_key)

    # スタイルプリセット適用
    style_suffix = STYLE_PRESETS.get(style, "")
    if style_suffix:
        full_prompt = f"{prompt}。{style_suffix}"
    else:
        full_prompt = prompt

    print(f"画像生成中...")
    print(f"プロンプト: {full_prompt}")
    print(f"スタイル: {style}")

    # 画像生成
    try:
        response = client.models.generate_image(
            model="gemini-2.5-flash-image",
            prompt=full_prompt,
            config=GenerateImageConfig(
                number_of_images=1,
            )
        )

        # 保存先ディレクトリ確認・作成
        output_dir = project_root / "assets" / "generated"
        output_dir.mkdir(parents=True, exist_ok=True)

        # ファイル保存
        output_path = output_dir / f"{name}.png"

        # 画像データを取得して保存
        if response.generated_images:
            image = response.generated_images[0]

            # PILを使って保存
            from PIL import Image
            import io

            # 画像データをPIL Imageに変換
            pil_image = image._pil_image
            pil_image.save(output_path, "PNG")

            print(f"✅ 生成完了: {output_path}")
            return str(output_path)
        else:
            print("エラー: 画像が生成されませんでした")
            sys.exit(1)

    except Exception as e:
        print(f"エラー: 画像生成に失敗しました")
        print(f"詳細: {e}")
        sys.exit(1)

def main():
    parser = argparse.ArgumentParser(
        description="Gemini APIでゲームアセット画像を生成する"
    )
    parser.add_argument(
        "--prompt",
        required=True,
        help="生成プロンプト（必須）"
    )
    parser.add_argument(
        "--name",
        required=True,
        help="保存ファイル名（必須・拡張子なし）"
    )
    parser.add_argument(
        "--style",
        default="pixel_art",
        choices=list(STYLE_PRESETS.keys()),
        help=f"スタイル指定（デフォルト: pixel_art）。選択肢: {', '.join(STYLE_PRESETS.keys())}"
    )

    args = parser.parse_args()

    generate_image(args.prompt, args.name, args.style)

if __name__ == "__main__":
    main()
