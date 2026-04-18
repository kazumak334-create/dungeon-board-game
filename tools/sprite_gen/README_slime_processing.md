# Slime Sprite Processing

## 手順

### 1. Geminiで生成
`slime_prompts.txt`の各プロンプトをGeminiに投げて14体生成

### 2. グリッド画像を配置
生成されたグリッド画像を以下に配置:
```
assets/sprites/units/raw/slime_sheet.png
```

### 3. スクリプト実行
```bash
python tools/sprite_gen/process_slime_sheet.py
```

### 4. 出力確認
```
assets/sprites/units/
  slime.png
  amoeba.png
  jelfix.png
  barbzel.png
  mudblob.png
  plagzel.png
  sparkblob.png
  crystel.png
  glitzel.png
  granob.png
  venpool.png
  silenzel.png
  voidblob.png
  kinglob.png
```

## 処理内容
- 7×2グリッド自動検出（ラベル行除外）
- 背景透過化（#0a1628 ±30）
- 48×48リサイズ（Nearest Neighbor）
- PNG出力（透過あり）

## 必要なライブラリ
```bash
pip install pillow numpy
```
