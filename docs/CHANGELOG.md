# CHANGELOG

## 2026-04-10

### Phase 3 マップ画面UI v2

**StS風横方向分岐ツリー実装**
- MapSelect.gd: 縦リストから横ツリー表示に全面改修
- MapGenerator連携: シード再現性・ race_theme対応
- ノード配置: depth×lane座標計算・中央配置アルゴリズム
- 接続線描画: Line2Dで前ノード→現ノード接続
- 状態管理: 現在地（青グロー）・訪問済み（灰）・到達可能（種別色）・未到達（暗灰）
- クリック処理: 到達可能ノードのみボタン化
- テスト: test_map_generator.gd追加
- コミット: 2fc9871

---

## 2026-04-10（続き）

### Phase 2完了

**スキルツリー実装**
- 6階層ランダム生成（T1-T6）、70+ダミースキル
- T4/T6階層でクラス固有カード報酬
- 横ツリーUI・前提スキルシステム
- ファイル：`scripts/SkillTree.gd`, `scripts/SkillTreeGenerator.gd`

**敵スケーリングシステム**
- Act別敵プール実装（5ランク：弱→中間→中→中間→強）
- `data/cards.json` enemy_pools、`GameSession.current_act` でプール選択
- ファイル：`scripts/EnemyAI.gd`, `scripts/CardDB.gd`

**警戒レベルシステム設計**
- 戦闘マス+1、レスト-2、Lv3+でデッキランク上昇、Lv5+でエリート確定
- `GameSession.alert_level` 追加、実装はPhase 3
- 設計：`docs/GAME_DESIGN.md`

**UI/UX改善**
- DeckPrep.gd: タブバー復活（配置・持ち物）
- GameUI.gd: セル内情報密度削減、バフ/デバフアイコン化

**ツール作成**
- `tools/session_check.py`: セッション開始時チェック
- `tools/generate_image.py`: Gemini画像生成スクリプト

**設計文書**
- `docs/GAME_DESIGN.md`: Single Source of Truth確立

---

## 2026-04-06

### ドキュメント
- スキル分類の用語を統一：「アクティブスキル」→「パッシブスキル」（CLAUDE.md / docs/game_spec.md / docs/card_database.md）
- 3レイヤー定義を「攻撃/サポート効果/パッシブスキル」に更新
- checker設計整合性チェック文言を「攻撃/サポート/パッシブスキル」に更新

## 2026-04-05

### 新システム
- 効果テーブルシステム導入（EffectDB.gd + EffectExecutor.gd）
- CardDB.gd による全カードデータ一元管理
- ユニット効果の3レイヤー構造定義（攻撃/サポート効果/アクティブスキル）
- skills配列構造標準化（trigger/target/effect_id/params）

### 新ユニット
- リッチ（狙撃+再起付与+魂の器）
- ヴリコラカス（バフ奪取+デバフ波及）

### バランス変更
- スケルトン：ATK4→2, SPD2→3s, サポート効果を再起付与→敵マナ妨害に変更, 自己再起を3秒遅延復活に
- ゴブリン：サポート効果を「隣接の獣ATKバフ」→「前のユニット1体ATKバフ」に変更
- バフスタック化：吸血(3%/スタック), 貫通(5%/スタック, 10で2マス波及), 鎧(被弾で-1), リジェネ(2秒ごと-1)
- 血の契約：HP30%代償（HP1未満にならない）+ 吸血10スタック付与
- サポート効果：前列では発動しない（中列・後列のみ）
- 狙撃/支援攻撃のスキル名称変更

### 開発者モード
- 左側デッキエディタ（ドラッグ追加/右クリック削除/シャッフル/全削除）
- カードホバー詳細パネル
- 本体HP回復ボタン3種
- ゲームオーバー無効化
- 一時停止でデッキ/マナ/時間経過スキルが停止

### バグ修正
- EnemyAIにdeckエイリアス追加（環境呪文フリーズ修正）
- 召喚時効果がドラッグ配置で未発動→修正
- 呪文ドラッグ時のside逆転防止
- _apply_regen_buffのnullアクセス修正
- preload→load変更（起動フリーズ修正）

### アーキテクチャ
- Agent体制更新（architect/data-sync新設）
- 盤面座標・対象範囲のMECE定義
- 召喚と復活の定義明確化
- _skill_timersにsupport_Nプレフィックスで定期サポート統合

---

## 2026-04-05（後半）

### アーキテクチャ（続き）
- BoardManager分割完了（CombatSystem.gd / SupportSystem.gd / TileSystem.gd / TickSystem.gd）
- 旧方式文字列パース（match文によるeffect_id文字列分岐）完全削除
- CardDBデータをJSON外出し（data/cards.json）
- load()キャッシュ化（同一リソースの重複ロード排除）
- GameUI.gd分離（Main.gdからUI構築ロジックを独立）

### 新システム
- アーティファクトシステム実装（永久スロット3 + 盤面スロット4）
- プレイヤークラス3種実装（召喚士 / 戦術家 / 錬金術師）
- 装備3種実装（武器 / 防具 / アクセサリ）
- ゲームスピード変更機能実装（0.5x / 1x / 2x）

### テスト
- TestRunner.gd によるテスト自動化基盤実装

### ユニット調整
- キングスライム：auto_promote対応（前列空きで自動昇格）
