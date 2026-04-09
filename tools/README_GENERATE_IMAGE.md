# Gemini画像生成スクリプト使用方法

## セットアップ

### 1. ライブラリインストール
```bash
pip install google-genai Pillow python-dotenv
```

### 2. APIキー設定
プロジェクトルートに `.env` ファイルを作成し、以下を追加：
```
GEMINI_API_KEY=あなたのAPIキー
```

**APIキー取得方法**：
https://aistudio.google.com/apikey

## 使用方法

### 基本的な使い方
```bash
python tools/generate_image.py --prompt "スライム、深海、粘体" --name "slime_unit"
```

### スタイル指定
```bash
python tools/generate_image.py --prompt "骸骨の兵士、盾持ち" --name "skeleton_unit" --style card_art
```

## 利用可能なスタイル

| スタイル | 説明 |
|---------|------|
| `pixel_art` | ドット絵、16x16ピクセル、ゲームアイコン風（デフォルト） |
| `dark_fantasy` | ダークファンタジー、モノクロ、細密画風 |
| `card_art` | カードゲームイラスト、縦長、ダークファンタジー風 |
| `icon` | シンプルなゲームアイコン、黒背景、発光エフェクト |

## 保存先
生成された画像は `assets/generated/{name}.png` に保存されます。

## トラブルシューティング

### エラー: GEMINI_API_KEY が設定されていません
→ `.env` ファイルをプロジェクトルートに作成し、APIキーを記載してください。

### エラー: google-genai ライブラリがインストールされていません
→ `pip install google-genai Pillow python-dotenv` を実行してください。

### 画像生成に失敗しました
→ プロンプトを変更するか、APIキーが有効か確認してください。
