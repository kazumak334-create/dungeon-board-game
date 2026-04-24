# 敵デッキシステム要件定義書

## 1. 概要

Phase 4 #6「敵デッキパターン（8種以上）」の要件定義書。
通しプレイ可能な敵デッキを整備し、バランス調整の前提条件を満たす。

## 2. 背景・前提条件

### 警戒度システム確定（Phase 4 #0）
- 警戒度MAX=3に変更済み（旧5から変更）
- 通常戦：警戒度0-2（weak/enhanced1/enhanced2）
- ボス戦：警戒度1-3（基本/strong/enraged）
- エリートノード廃止

### 現状の実装状態

**enemy_pools（通常戦用）:**
- Act1: weak/enhanced1/enhanced2/enhanced3の4段階
- Act2: weak/enhanced1/enhanced2/enhanced3の4段階
- Act3: weak/enhanced1/enhanced2/enhanced3の4段階

**boss_decks（ボス戦用）:**
- Act1: 種族別3種 × 3段階（基本/strong/enraged）＝9デッキ実装済み
- Act2: 5ボス × 3段階の参照ID定義済み（データ未実装）
- Act3: 5ボス × 3段階の参照ID定義済み（データ未実装）

**elite_pools:**
- Act1/2/3のエリートプール定義あり（エリートノード廃止により不要）

## 3. 要件定義

### 3-1. 通常戦デッキ整備

#### Act1（変更不要）
- 現状：weak/enhanced1/enhanced2/enhanced3の4段階
- 判定：動作確認済みのため変更不要

#### Act2/Act3
- 現状：weak/enhanced1/enhanced2/enhanced3の4段階
- 判定：通常戦で使用するのはweak/enhanced1/enhanced2の3段階のみ
- **enhanced3の扱い:** 削除不要（将来の拡張可能性を考慮）、現時点で参照されない

### 3-2. ボス戦デッキ整備（新方針）

#### 基本構成
**ボスデッキ構成:**
- **ベースデッキ**（alert 1-2用）: 初期3、ローンチ9
- **強化デッキ**（alert 3用）: 初期3、ローンチ9
- **合計**: 初期6デッキ、ローンチ18デッキ

#### alert 1-2の差分表現
- 同じベースデッキを使用
- alert値に応じてATK/HPバフを適用（実装簡単、後で調整可能）
- alert 1: バフなし（1.0倍）
- alert 2: 小バフ（1.2倍など、要調整）
- alert 3: 強化デッキに切替

#### 初期MVP実装（Phase 4）
- Act1のみ: 1ボス × 2段階 = 2デッキ
- 既存のboss_act1_beast（ベース）+ boss_act1_beast_strong（強化）を使用
- Act2/3は後回し

#### ローンチ実装
- Act1/2/3それぞれ3ボス × 2段階 = 18デッキ

### 3-3. elite_pools削除（完了済み）

エリートノード廃止により不要。cards.jsonから以下を削除：
- elite_pools.act1
- elite_pools.act2
- elite_pools.act3

**ステータス:** 完了済み

## 4. データ構造定義

### enemy_pools構造（変更不要）
```json
"enemy_pools": {
  "act1_weak": [ { "name": "カード名", "col": 0-2 }, ... ],
  "act1_enhanced1": [ ... ],
  "act1_enhanced2": [ ... ],
  "act1_enhanced3": [ ... ],
  "act2_weak": [ ... ],
  ...
}
```

### boss_decks構造（新方針：2段階構成）
```json
"boss_decks": {
  "boss_act1_beast": [ { "name": "カード名", "col": 0-2 }, ... ],
  "boss_act1_beast_strong": [ ... ],
  "boss_act2_deadlock": [ ... ],
  "boss_act2_deadlock_strong": [ ... ],
  "boss_act3_overfit": [ ... ],
  "boss_act3_overfit_strong": [ ... ],
  ...
}
```

**命名規則:**
- ベースデッキ: `boss_act[N]_[name]`
- 強化デッキ: `boss_act[N]_[name]_strong`

### デッキ構成ガイドライン

#### カード数
- 通常デッキ：7枚
- ボスデッキ：7枚

#### 配置バランス
- 前列（col=0）：2-3枚
- 中列（col=1）：2-3枚
- 後列（col=2）：1-2枚

#### 強度段階
- ベースデッキ：Act標準レベルのカード（weak〜enhanced1相当）
- 強化デッキ：Act上位レベル（enhanced1〜enhanced2相当）

### alert 1-2バフ倍率定義（実装時に調整）

#### 推奨定数定義
```gdscript
const ALERT_LEVEL_BUFFS = {
    1: 1.0,   # バフなし
    2: 1.2,   # 小バフ（調整必要）
    3: 1.0    # 強化デッキ使用（バフなし）
}
```

#### 適用対象
- ATK（攻撃力）
- HP（体力）

#### 適用タイミング
- 敵ユニット生成時（Main.gd または BossManager）

## 5. 実装ファイル・変更箇所

### 5-1. data/cards.json
**変更箇所:**
- boss_decks セクション（6000行前後〜）
  - **Phase 4 初期（MVP）:** Act1の2デッキ（boss_act1_beast、boss_act1_beast_strong）は既存利用
  - **Phase 4 後期:** Act2/3各2デッキ追加（合計6デッキ）
  - **ローンチ前:** バリエーション追加（各Act 3ボス × 2段階 = 18デッキ）
- elite_pools セクション
  - **完了済み:** act1/act2/act3のelite_pools定義削除完了

**作業量見積もり:**
- Phase 4 初期: 変更なし（既存2デッキ使用）
- Phase 4 後期: Act2/3各2ボス追加 約100行
- ローンチ前: 残りボス追加 約200行

### 5-2. scripts/Main.gd または scripts/BossManager.gd
**新規追加箇所:**
- alert 1-2バフ適用ロジック（+50行程度）
- 関数例: `apply_alert_buff(unit_data: Dictionary, alert_level: int) -> Dictionary`

**処理フロー:**
1. ボスデッキからユニットデータ取得
2. alert_levelに応じてATK/HPバフ適用
3. alert 3の場合は_strongデッキに切替

**変更箇所:**
- 敵ユニット生成処理（_spawn_enemy_unit等）

### 5-3. scripts/WaveManager.gd
**確認必要箇所:**
- enemy_poolsのロード処理（変更不要）
- boss_decksのロード処理（変更不要）
- elite_pools参照箇所（削除漏れチェック）

### 5-4. scripts/WaveConfig.gd
**確認必要箇所:**
- プール名の定数定義（変更不要）
- elite関連の定数（削除必要か確認）

## 6. テスト観点

### 6-1. データ整合性
- [ ] cards.jsonが構文エラーなくロード可能
- [ ] 全ボスデッキIDが参照可能
- [ ] elite_pools削除後も既存機能が動作

### 6-2. ゲームプレイ動作
- [ ] Act1通常戦でweak/enhanced1/enhanced2が選出される
- [ ] Act1ボス戦で基本/strong/enragedが警戒度に応じて選出される
- [ ] Act2通常戦でデッキが正常に選出される
- [ ] Act2ボス戦で各ボスのデッキが警戒度に応じて選出される
- [ ] Act3通常戦でデッキが正常に選出される
- [ ] Act3ボス戦で各ボスのデッキが警戒度に応じて選出される

### 6-3. エリートノード廃止確認
- [ ] エリートノードへの遷移が発生しない
- [ ] elite_pools参照によるエラーが発生しない

## 7. 制約・注意事項

### 7-1. 既存プール保持
- Act1のenemy_pools/boss_decksは動作確認済みのため変更不要
- 既存デッキ構成を参考にAct2/3を作成する

### 7-2. カードプール活用
- cards.jsonには199枚のユニットカードが定義済み
- Act1=序盤（slime/beast/undead基本〜中級）
- Act2=中盤（各種族中級〜上級混合）
- Act3=終盤（全種族上級〜最上級混合）

### 7-3. バランス調整は後回し
- Phase 4 #6の目的は「通しプレイ可能な敵デッキ整備」
- 詳細なバランス調整はPhase 4 #11で実施
- alert 1-2バフ倍率は仮値（1.2倍など）で実装し、後で調整

### 7-4. enhanced3の位置づけ
- 通常戦では使用しない（警戒度0-2の範囲外）
- 削除不要（将来の拡張可能性を考慮）

### 7-5. 実装フェーズ
- **Phase 4 初期（MVP）:** Act1の2デッキで動作確認
- **Phase 4 後期:** Act2/3各2デッキ追加（合計6デッキ）
- **ローンチ前:** バリエーション追加（合計18デッキ）

## 8. 完了定義

### Phase 4 初期（MVP）
- [ ] elite_poolsがcards.jsonから削除されている（完了済み）
- [ ] Act1の2デッキ（boss_act1_beast、boss_act1_beast_strong）を使用してボス戦が動作
- [ ] alert 1-2バフ適用ロジックが実装されている
- [ ] alert 1: バフなし、alert 2: 1.2倍バフ、alert 3: _strongデッキ使用
- [ ] tools/ci/check_syntax.shでエラーなし
- [ ] WaveManager/WaveConfigでelite関連参照が残っていない

### Phase 4 後期
- [ ] Act2の2ボス × 2段階（4デッキ）が実装されている
- [ ] Act3の2ボス × 2段階（4デッキ）が実装されている
- [ ] 合計6デッキで通しプレイ可能

### ローンチ前
- [ ] Act1/2/3それぞれ3ボス × 2段階（18デッキ）が実装されている
- [ ] 全ボスデッキIDが参照可能
- [ ] バランス調整完了（Phase 4 #11）

## 9. 参照ドキュメント

- docs/design/alert_level_requirements.md（警戒度システム仕様）
- docs/design/alert_level_combat_impact.md（警戒度の戦闘影響）
- docs/GAME_DESIGN.md（ゲーム全体設計）
- data/cards.json（カードデータベース）
