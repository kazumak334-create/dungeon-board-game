# CHANGELOG

## [Unreleased]

### Changed
- **敵デッキをcard_database.md準拠の9枚構成に刷新** (`EnemyAI.gd`)
  - 旧構成：ゴブリン/オーク/スケルトン/ウルフ/シャーマン（5枚・独自ステータス・前列集中）
  - 新構成：スライム3枚・アンデッド3枚・獣3枚（9枚・card_database.md準拠ステータス）
  - 列分散：前列3（ゼリーフィッシュ・シャドウ・ゴブリン）/ 中列3（クリスタルスライム・グール・コカトリス）/ 後列3（ブラッドスライム・ワイト・タイガー）
  - DeckManagerと同形式の `{name, col}` 辞書ベースに構造統一

### Added
- **山札切れ時の捨て札リシャッフル処理を実装** (`DeckManager.gd`, `EnemyAI.gd`)
  - DeckManager: `discard` 配列を追加。カード発動後は `deck` 末尾でなく `discard` へ移動。`deck` 空時に `discard` をシャッフルして `deck` に戻す
  - EnemyAI: `enemy_discard` 配列を追加。スポーン時に `enemy_deck[0]` を消費して `enemy_discard` へ移動。`enemy_deck` 空時に `enemy_discard` をシャッフルして `enemy_deck` に戻す
  - EnemyAI: カード選択を「ランダム参照（消費なし）」から「山札先頭を順番に消費」に変更し、正しい無限巡回を実現

### Changed
- **マナ不足時のカード挙動をスタック待機に変更** (`DeckManager.gd`)
  - 変更前：マナ不足→マナ消費なしで捨て札（デッキ末尾）へ送る
  - 変更後：マナが足りるまで先頭のカードで待機し、足りたら即発動

### Added
- **敵の次召喚カードをUI上に表示** (`EnemyAI.gd`, `Main.gd`)
  - EnemyAI にスポーン時点で次のカードを事前決定する `_pick_next_card()` と `get_next_card()` を追加
  - 次の敵カード名とスポーンまでの残り時間を「次の敵：〇〇 (X.Xs後)」形式で次カードパネル右横に表示

### Added
- **UnitData に `race` / `attack_range` フィールドを追加** (`UnitData.gd`)
  - `race: String`（"スライム" / "アンデッド" / "獣"）
  - `attack_range: String`（"1行" / "上含む2行" / "下含む2行" / "上下含む3行"）デフォルト "1行"
  - `clone()` で両フィールドをコピーするよう対応

- **card_database.md 準拠のカードデータ実装** (`DeckManager.gd`)
  - スライム系 3 種: アメーバ・マッドスライム・ゼリーフィッシュ
  - アンデッド系 3 種: スケルトン・グール・バンシー
  - 獣系 3 種: ゴブリン・ウルフ・コカトリス
  - 初期デッキ 9 枚構成（cost 1-2 中心、重複あり）

- **攻撃範囲の多行対応** (`BoardManager.gd`)
  - `_get_target_rows(row, attack_range)` を追加
  - `_do_attack` が attack_range に応じて複数行を攻撃するよう変更
    - "1行": 同行のみ（従来どおり）
    - "上含む2行": 自行＋上行
    - "下含む2行": 自行＋下行
    - "上下含む3行": 全行（バンシー・プラズマスライム等）

- **EnemyAI のユニット定義に race / attack_range を追加** (`EnemyAI.gd`)

### Fixed
- **多行攻撃時の本体ダメージ倍増を修正** (`BoardManager.gd`)
  - 変更前：複数行攻撃で全行が空きの場合、行数分だけ本体ダメージが発生していた
  - 変更後：いずれかの行にユニットがいれば本体ダメージなし、全行空きでも本体ダメージは ATK×1 回のみ

### Changed
- **未使用カード定義にコメントを追加** (`DeckManager.gd`)
  - ゼリーフィッシュ・コカトリスに「将来のデッキ構築機能用予備カード」コメントを付与

### Fixed
- **全カードが前列に集中して配置失敗が連発する問題を修正** (`DeckManager.gd`)
  - 原因: card_pool の全カードが `"col": 0` → `place_unit` で `2 - 0 = 2` に変換され全て前列(col2)へ集中
  - 修正: `deck_list` を `{name, col}` 辞書形式に変更し、配置列をデッキエントリごとに指定できる設計に変更
  - 前列3枚（アメーバ・ゴブリン・グール）/ 中列3枚（マッドスライム・ウルフ・バンシー）/ 後列3枚（スケルトン・アメーバ・ゴブリン）の均等分散
  - card_pool から `"col"` キーを削除（配置列の責務を deck_list 側に移行）

### Fixed
- **自陣の列インデックス逆転を修正** (`BoardManager.gd`)
  - `place_unit` で自陣（side 0）の `assigned_col` を `2 - col` に変換し、前列ユニットが視覚的な前列（col 2）に配置されるよう修正
  - `process_combat` / `_do_attack` で自陣の前列を col 2、敵陣の前列を col 0 として戦闘処理するよう修正
  - `_on_unit_died` のログ表示で物理 col を表示 col に変換し、ログが正しい列名を示すよう修正

- **マナ不足時のカード処理を修正** (`DeckManager.gd`)
  - 変更前：コスト不足でも `place_unit` を試みてマナを消費していた
  - 変更後：`mana < cost` の場合はマナを消費せずカードを捨て札（デッキ末尾）へ送る

### Changed
- **energy → mana に統一** (`DeckManager.gd`, `Main.gd`)
  - 変数名：`energy` → `mana`、`ENERGY_MAX` → `MANA_MAX`、`ENERGY_REGEN` → `MANA_REGEN`
  - シグナル名：`energy_changed` → `mana_changed`
  - UI表示：「Energy」→「Mana」
  - 内部変数：`energy_bar_cells` → `mana_bar_cells`、`energy_value_label` → `mana_value_label`
  - 関数名：`_build_energy_bar` → `_build_mana_bar`、`_update_energy` → `_update_mana`

---

## [0.1.0] - 2026-04-03

### Added
- Phase 1 プロトタイプ初期実装
  - 自陣 3×3 / 敵陣 3×3 の対面盤面
  - 左右対称レイアウト、中央ラインで自陣・敵陣を分割
  - 自動巡回デッキ + マナシステム（1.0/s 回復、最大10）
  - 前列のみ攻撃する戦闘システム
  - シンプルな敵AI（3.5秒間隔でランダム召喚）
  - 次カードパネル（カード名・コスト・詳細・発動チェックタイマー表示）
  - デバッグUI（HP・マナ・ログ表示）
  - ゲームオーバー / YOU WIN 判定
