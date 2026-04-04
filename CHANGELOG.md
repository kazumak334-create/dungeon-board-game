# CHANGELOG

## [Unreleased]

### Added
- **常時発動サポート効果を実装** (`BoardManager.gd`, `UnitData.gd`)
  - `UnitData` にランタイムボーナスフィールドを追加: `_atk_bonus`, `_interval_bonus`, `_regen`, `_can_attack_from_back`, `_back_atk_factor`（`clone()` には引き継がない）
  - `BoardManager._apply_support_effects()`: 毎フレーム全ユニットのボーナスをリセット→再計算
  - `BoardManager._process_unit_support()`: 各ユニットの `support_effect` 文字列を " / " で分割し 常時発動 エントリを処理
  - `BoardManager._get_support_targets()`: ターゲット記述（隣接/同行/同列/前列/全体）と種族フィルタを解析
  - `BoardManager._apply_regen()`: 1秒ごとに `_regen > 0` のユニットのHPを回復
  - 実装済み効果: **ATKバフ**（隣接/同行獣に+2 ATK）/ **SPDバフ**（同行/同列味方の攻撃間隔-0.3s）/ **HPバフ**（1 HP/秒回復）/ **後列攻撃**（後列ユニットが攻撃タイマーをティック・極低ATKは×0.3）
  - 未実装（今後）: 障壁付与・吸血付与・再起付与・デバフ波及・シナジー増幅
  - `_do_attack` に `atk_override: int = -1` パラメータを追加（後列攻撃の減衰ATK対応）

### Changed
- **敵デッキをプレイヤーと同一構成に変更** (`EnemyAI.gd`)
  - 旧構成：ゼリーフィッシュ・ミミック・アビスゼリー・シャドウ・ヴリコラカス・ワイト・コカトリス・ケットシー・マンティコア（高HPで重すぎ）
  - 新構成：アメーバ・マッドスライム・ブラッドスライム・スケルトン・グール・バンシー・ゴブリン・ウルフ・タイガー（プレイヤーと同じ）

### Changed
- **効果構造を2層化** (`UnitData.gd`, `DeckManager.gd`, `EnemyAI.gd`, `docs/card_database.md`)
  - 旧構造：サポート効果・攻撃時効果・固有スキルの3層
  - 新構造：サポート効果（常時発動/召喚時/条件達成時）＋アクティブスキル（命中時/撃破時/HP閾値時/時間経過/召喚時/その他）の2層
  - 攻撃時効果 → アクティブスキル（命中時）に統合
  - 固有スキル → アクティブスキルに【固有】プレフィックス付きで統合
  - `UnitData` フィールド: `attack_effect` を廃止し `active_skill` に一本化（`support_effect` は据え置き）

- **card_database.md を2層効果構造で全面書き直し**（`docs/card_database.md`）
  - 全28ユニット（プレイヤー14枚・敵14枚）のサポート効果／アクティブスキルを〈発動タイプ・対象・詳細〉形式に統一
  - 攻撃時効果欄を削除し、命中時発動としてアクティブスキル欄に移行
  - 固有スキルをアクティブスキル内【固有】エントリとして統合

- **プレイヤーデッキをcard_database.md準拠9枚構成に再構築** (`DeckManager.gd`)
  - 旧構成：アメーバ/マッドスライム/ゼリーフィッシュ（スライム）・スケルトン/グール/バンシー（アンデッド）・ゴブリン/ウルフ/コカトリス（獣）
  - 新構成：アメーバ・マッドスライム・ブラッドスライム（スライム）／スケルトン・グール・バンシー（アンデッド）／ゴブリン・ウルフ・タイガー（獣）
  - 全カードに card_database.md 準拠の `support_effect` / `active_skill` データを追加

- **敵デッキをcard_database.md準拠9枚構成に再構築** (`EnemyAI.gd`)
  - 新構成：ゼリーフィッシュ・ミミック・アビスゼリー（スライム）／シャドウ・ヴリコラカス・ワイト（アンデッド）／コカトリス・ケットシー・マンティコア（獣）
  - 全カードに card_database.md 準拠の `support_effect` / `active_skill` データを追加
  - プレイヤーと異なるカードセットで差別化

- **CLAUDE.md にユニット効果構造表を追加**（`CLAUDE.md`）
  - 2層効果（support_effect / active_skill）の発動タイプ一覧と説明を追記

### Changed
- **攻撃対象を「前列優先・貫通なし（案A）」に変更** (`BoardManager.gd`)
  - `_do_attack`: 固定 `enemy_front_col` を廃止し `_get_frontmost_col()` で前列→中列→後列の順に最初のユニットを攻撃
  - `_get_frontmost_col(side, row)` を追加（-1=行にユニットなし）
  - `_try_promote`: 前列が既に埋まっている場合は何もしないガードを追加
  - `process_combat`: 毎フレームの先頭で全行の繰り上がりチェックを実行（中列→前列の自動昇格により中列ユニットも攻撃に参加）

### Fixed
- **本体ダメージ判定を全列チェックに修正** (`BoardManager.gd`)
  - 変更前：前列が空なら同行の中列・後列にユニットがいても本体ダメージが入っていた
  - 変更後：対象行の全3列（前・中・後）にユニットが1体もいない場合のみ本体ダメージ

### Added
- **中列繰り上がりロジックを実装** (`BoardManager.gd`)
  - `_try_promote(side, row, col)` を追加。`remove_unit` の末尾から呼び出される
  - 前列（自陣=col2、敵陣=col0）が空になった際、同行の中列（col=1）ユニットを前列に移動
  - 後列（col=0/2）は移動しない（固定）
  - 移動はHPをそのまま引き継ぎ、攻撃タイマーは1インターバル分リセット

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
