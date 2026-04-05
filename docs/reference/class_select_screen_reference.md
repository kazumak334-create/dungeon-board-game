# クラス選択画面リファレンス（STS参考）

## MVP最小構成
1. 3つのクラスカードを横並び表示
2. クリックで選択（枠色変更）
3. 選択中クラスの詳細パネル（名前・説明・初期デッキ）
4. 「ゲーム開始」→ GameSession.class_id設定 → バトルへ

## 必要なCardDB.CLASSESフィールド
- display, description, initial_mana, mana_max, initial_deck, skills
