# Act1 ボスシステム完成 要件定義書

## 1. 概要

企画意図: Act1ボス3体の専用デッキ3段階（通常/強化/激昂）と専用ユニット5体を実装し、警戒レベルに応じた難易度調整を完成させる。「盤面を設計して、介入を仕込んで、答え合わせを観戦する」体験の最高到達点として、ボスごとに異なる対策を要求する。

## 2. 実装対象

### 2.1 データファイル
- **ファイル**: `C:\Users\kazum\dungeon-board-game\data\cards.json`
- **変更箇所**: 以下のセクションを追加・修正

### 2.2 スクリプトファイル
- **ファイル1**: `C:\Users\kazum\dungeon-board-game\scripts\CardDB.gd`
  - 変更箇所: `_ready()` 関数（新規セクション読み込み追加）
  
- **ファイル2**: `C:\Users\kazum\dungeon-board-game\scripts\EnemyAI.gd`
  - 変更箇所: `_build_boss_deck()` 関数（109-136行目のTODO解消）

## 3. データ構造定義（cards.json）

### 3.1 boss_decks セクション（新規追加）

enemy_poolsセクションの直後（現在の"bosses"セクションの前）に追加:

```json
"boss_decks": {
  "boss_act1_beast": [
    {"name": "ウルフ", "col": 0},
    {"name": "ゴブリン", "col": 0},
    {"name": "ウルフ", "col": 1},
    {"name": "ケットシー", "col": 1},
    {"name": "ゴブリン", "col": 2},
    {"name": "ワイルドホーク", "col": 2},
    {"name": "コカトリス", "col": 1}
  ],
  "boss_act1_beast_strong": [
    {"name": "タイガー", "col": 0},
    {"name": "ウルフ", "col": 0},
    {"name": "マンティコア", "col": 1},
    {"name": "コカトリス", "col": 1},
    {"name": "ワイルドホーク", "col": 2},
    {"name": "ウルフ", "col": 2},
    {"name": "猛獣使い", "col": 2}
  ],
  "boss_act1_beast_enraged": [
    {"name": "タイガー", "col": 0},
    {"name": "マンティコア", "col": 0},
    {"name": "グリフォン", "col": 1},
    {"name": "コカトリス", "col": 1},
    {"name": "猛獣使い", "col": 2},
    {"name": "ビャッコ", "col": 2},
    {"name": "タイガー", "col": 1}
  ],
  "boss_act1_slime": [
    {"name": "スライム", "col": 0},
    {"name": "マッドスライム", "col": 0},
    {"name": "スライム", "col": 1},
    {"name": "ラージスライム", "col": 1},
    {"name": "マッドスライム", "col": 2},
    {"name": "スライム", "col": 2},
    {"name": "ファットスライム", "col": 1}
  ],
  "boss_act1_slime_strong": [
    {"name": "マッドスライム", "col": 0},
    {"name": "ファットスライム", "col": 0},
    {"name": "ラージスライム", "col": 1},
    {"name": "ヒートスライム", "col": 1},
    {"name": "マッドスライム", "col": 2},
    {"name": "ブラッドスライム", "col": 2},
    {"name": "母スライム核", "col": 1}
  ],
  "boss_act1_slime_enraged": [
    {"name": "ファットスライム", "col": 0},
    {"name": "パラライズスライム", "col": 0},
    {"name": "ブラッドスライム", "col": 1},
    {"name": "母スライム核", "col": 1},
    {"name": "ヒートスライム", "col": 2},
    {"name": "フロストスライム", "col": 2},
    {"name": "融合スライム", "col": 0}
  ],
  "boss_act1_undead": [
    {"name": "スケルトン", "col": 0},
    {"name": "グール", "col": 0},
    {"name": "スケルトン", "col": 1},
    {"name": "バンシー", "col": 1},
    {"name": "グール", "col": 2},
    {"name": "リッチ", "col": 2},
    {"name": "シャドウ", "col": 1}
  ],
  "boss_act1_undead_strong": [
    {"name": "グール", "col": 0},
    {"name": "レヴナント", "col": 0},
    {"name": "バンシー", "col": 1},
    {"name": "ワイト", "col": 1},
    {"name": "リッチ", "col": 2},
    {"name": "シャドウ", "col": 2},
    {"name": "屍術師", "col": 2}
  ],
  "boss_act1_undead_enraged": [
    {"name": "ヴリコラカス", "col": 0},
    {"name": "レヴナント", "col": 0},
    {"name": "ワイト", "col": 1},
    {"name": "屍術師", "col": 1},
    {"name": "リッチ", "col": 2},
    {"name": "バンシー", "col": 2},
    {"name": "死骸の王座", "col": 1}
  ]
}
```

### 3.2 boss_exclusive_units セクション（新規追加）

boss_decksセクションの直後に追加:

```json
"boss_exclusive_units": {
  "猛獣使い": {
    "hp": 25,
    "atk": 6,
    "interval": 1.5,
    "mana": 3,
    "race": "獣",
    "range": "1行",
    "skills": [
      {
        "trigger": "on_hit",
        "target": "hit_target",
        "effect_id": "burn_apply",
        "params": {"stacks": 2}
      }
    ],
    "boss_exclusive": true
  },
  "母スライム核": {
    "hp": 60,
    "atk": 1,
    "interval": 5,
    "mana": 4,
    "race": "スライム",
    "range": "1行",
    "skills": [
      {
        "trigger": "on_death",
        "target": "self",
        "effect_id": "self_revive",
        "params": {"hp": 20, "delay": 5.0}
      }
    ],
    "boss_exclusive": true
  },
  "融合スライム": {
    "hp": 45,
    "atk": 4,
    "interval": 3,
    "mana": 4,
    "race": "スライム",
    "range": "1行",
    "skills": [
      {
        "trigger": "on_hit",
        "target": "hit_target",
        "effect_id": "freeze_apply",
        "params": {"stacks": 2}
      }
    ],
    "boss_exclusive": true
  },
  "屍術師": {
    "hp": 20,
    "atk": 3,
    "interval": 3,
    "mana": 3,
    "race": "アンデッド",
    "range": "上下含む3行",
    "skills": [
      {
        "trigger": "on_hit",
        "target": "hit_target",
        "effect_id": "poison_apply",
        "params": {"stacks": 2}
      }
    ],
    "boss_exclusive": true
  },
  "死骸の王座": {
    "hp": 50,
    "atk": 5,
    "interval": 3,
    "mana": 4,
    "race": "アンデッド",
    "range": "上下含む3行",
    "skills": [
      {
        "trigger": "on_hit",
        "target": "hit_target",
        "effect_id": "freeze_apply",
        "params": {"stacks": 3}
      }
    ],
    "boss_exclusive": true
  }
}
```

### 3.3 bosses セクション修正

既存の3ボスのalert_level_buffsを以下に差し替え:

**boss_beast_king**（2174-2175行目を修正）:
```json
"alert_level_buffs": {
  "4": {"hp_bonus": 5, "atk_bonus": 1},
  "5": {"hp_bonus": 10, "atk_bonus": 2}
}
```

**boss_slime_mother**（該当箇所を修正）:
```json
"alert_level_buffs": {
  "4": {"hp_bonus": 5, "atk_bonus": 1},
  "5": {"hp_bonus": 10, "atk_bonus": 2}
}
```

**boss_death_lord**（2211-2214行目を修正）:
```json
"alert_level_buffs": {
  "4": {"hp_bonus": 5, "atk_bonus": 1},
  "5": {"hp_bonus": 10, "atk_bonus": 2}
}
```

## 4. 実装詳細

### 4.1 CardDB.gd 修正仕様

**ファイル**: `C:\Users\kazum\dungeon-board-game\scripts\CardDB.gd`

**変更箇所**: `_ready()` 関数（23-50行目）

**追加内容**:

```gdscript
var BOSS_DECKS: Dictionary = {}
var BOSS_EXCLUSIVE_UNITS: Dictionary = {}

func _ready() -> void:
    var file = FileAccess.open("res://data/cards.json", FileAccess.READ)
    if file == null:
        print("[CardDB] ERROR: data/cards.json not found")
        return
    var json_text = file.get_as_text()
    file.close()
    var data = JSON.parse_string(json_text)
    if data == null:
        print("[CardDB] ERROR: JSON parse failed")
        return
    UNITS = data.get("units", {})
    SPELLS = data.get("spells", {})
    STATUS_SPELLS = data.get("status_spells", {})
    SYSTEM_SPELLS = data.get("system_spells", {})
    ARTIFACTS = data.get("artifacts", {})
    CLASSES = data.get("classes", {})
    SYNTHESIS = data.get("synthesis", [])
    PLAYER_DECK = data.get("player_deck", [])
    PLAYER_SPELLS = data.get("player_spells", [])
    ENEMY_DECK = data.get("enemy_deck", [])
    ENEMY_POOLS = data.get("enemy_pools", {})
    ELITE_POOLS = data.get("elite_pools", {})
    BASE_DECK = data.get("base_deck", [])
    RELICS = data.get("relics", {})
    ENVIRONMENTS = data.get("environments", {})
    BOSSES = data.get("bosses", {})
    EVENTS = data.get("events", {})
    BOSS_DECKS = data.get("boss_decks", {})  # 追加
    BOSS_EXCLUSIVE_UNITS = data.get("boss_exclusive_units", {})  # 追加
    
    # ボス専用ユニットをUNITSにマージ（プレイヤー入手不可フラグ付き）
    for unit_name in BOSS_EXCLUSIVE_UNITS:
        UNITS[unit_name] = BOSS_EXCLUSIVE_UNITS[unit_name]
```

**処理フロー**:
1. JSON読み込み（既存処理）
2. boss_decks / boss_exclusive_units セクションを読み込み
3. BOSS_EXCLUSIVE_UNITS を UNITS にマージ（boss_exclusive: trueフラグはそのまま保持）

### 4.2 EnemyAI.gd 修正仕様

**ファイル**: `C:\Users\kazum\dungeon-board-game\scripts\EnemyAI.gd`

**変更箇所**: `_build_boss_deck()` 関数（85-136行目）

**修正内容**: 109-116行目のTODO部分を以下に置き換え

```gdscript
# deck_idから実際のデッキ構成を取得
var pool: Array = CardDB.BOSS_DECKS.get(deck_id, [])
if pool.is_empty():
    print("[EnemyAI] ERROR: デッキID '%s' が未定義、フォールバック" % deck_id)
    pool = CardDB.ENEMY_POOLS.get(str(GameSession.current_act), CardDB.ENEMY_DECK)

print("[EnemyAI] ボスデッキ構築: %s (deck_id=%s, phase=%d, alert=%d)" % [boss.get("display", ""), deck_id, GameSession.boss_phase, GameSession.alert_level])
```

**修正後の全体フロー**:
1. boss_idからボス情報取得（既存）
2. フェーズと警戒レベルに応じたdeck_id決定（既存）
3. **deck_idからBOSS_DECKSを参照してデッキ構成取得（修正）**
4. 警戒レベル別バフ取得（既存）
5. デッキカード生成・バフ適用（既存）

**111-116行目削除**: TODO警告と暫定pool_key取得処理を削除

## 5. 制約・注意事項

### 5.1 既存コードとの整合性
- enemy_poolsと同じ構造（`{"name": string, "col": int}`配列）を使用
- CardDB.UNITS参照時、通常ユニットとボス専用ユニットを区別しない（boss_exclusiveフラグで判別）
- hp_bonus/atk_bonusは既存の実装（126-133行目）で全ユニットに一律加算される

### 5.2 GAME_DESIGN.mdとの整合性
- 3秒ルール遵守: ボス専用ユニットは既存スキルの組み合わせのみ
- 新effect_id追加なし（burn_apply, freeze_apply, poison_apply, self_reviveは既存）
- ユニット配置は列の役割定義に従う（前列Tank・中列サポート・後列遠距離）

### 5.3 データ整合性チェックポイント
- boss_decksで参照されるユニット名は全てUNITSまたはBOSS_EXCLUSIVE_UNITSに存在すること
- ボス専用ユニットのrangeは既存の値（"1行", "上下含む3行"）のみ
- skillsのeffect_idは全てEffectDB.gdに存在すること

## 6. Sprint分割

### Sprint 1: データ定義（工数: 小）
1. cards.jsonにboss_decksセクション追加（9デッキ）
2. cards.jsonにboss_exclusive_unitsセクション追加（5体）
3. cards.jsonのbosses修正（alert_level_buffs更新）

**完了条件**: JSON構文エラーなし・Godotエディタで読み込み成功

### Sprint 2: CardDB読み込み実装（工数: 小）
1. CardDB.gdに変数追加（BOSS_DECKS, BOSS_EXCLUSIVE_UNITS）
2. _ready()に読み込み処理追加
3. マージ処理実装

**完了条件**: CardDB.BOSS_DECKS / CardDB.BOSS_EXCLUSIVE_UNITS にデータが格納されていることを確認

### Sprint 3: EnemyAI実装（工数: 中）
1. _build_boss_deck()のTODO部分修正
2. デッキ読み込みロジック実装

**完了条件**: ボス戦開始時にログ出力「ボスデッキ構築完了: 7枚 (HP+X, ATK+Y)」確認

## 7. テストポイント

### 7.1 データ整合性テスト
```bash
# JSON構文チェック（Godotエディタで実行）
- cards.jsonを開く
- エラーメッセージがないことを確認
```

### 7.2 CardDB読み込みテスト
```gdscript
# _ready()完了後にprint確認
print(CardDB.BOSS_DECKS.keys())  # ["boss_act1_beast", "boss_act1_beast_strong", ...]
print(CardDB.BOSS_EXCLUSIVE_UNITS.keys())  # ["猛獣使い", "母スライム核", ...]
print(CardDB.UNITS.has("猛獣使い"))  # true
print(CardDB.UNITS["猛獣使い"]["boss_exclusive"])  # true
```

### 7.3 ボス戦デッキ構築テスト
```gdscript
# GameSession設定
GameSession.battle_type = "boss"
GameSession.boss_id = "boss_beast_king"
GameSession.boss_phase = 1
GameSession.alert_level = 3

# EnemyAI._build_boss_deck() 実行
# 期待されるログ:
# [EnemyAI] ボスデッキ構築: 獣王 (deck_id=boss_act1_beast, phase=1, alert=3)
# [EnemyAI] ボスデッキ構築完了: 7枚 (HP+0, ATK+0)
```

### 7.4 警戒レベル別バフテスト
```gdscript
# 警戒Lv4テスト
GameSession.boss_phase = 2
GameSession.alert_level = 4
# 期待: deck_id=boss_act1_beast_strong, HP+5, ATK+1

# 警戒Lv5テスト
GameSession.alert_level = 5
# 期待: deck_id=boss_act1_beast_enraged, HP+10, ATK+2
```

### 7.5 ボス専用ユニット配置テスト
```gdscript
# boss_act1_beast_strongデッキで「猛獣使い」が配置されることを確認
# enemy_deck[6].unit_name == "猛獣使い"
# enemy_deck[6].skills[0]["effect_id"] == "burn_apply"
```

## 8. 未決定事項（実装時に判断）

| 項目 | 選択肢 | 判断タイミング | 推奨 |
|------|--------|---------------|------|
| hp_multiplier/atk_multiplierの扱い | A: 廃止（デッキ構成で表現） / B: ボス専用ユニットのみ適用 | Sprint 3実装時 | A（企画書ではalert_level_buffsで十分） |
| boss_exclusiveユニットの入手可否チェック | A: CardDB参照時にフィルタ / B: ドロップテーブル側で除外 | Phase 4 報酬実装時 | B（データ構造を分離） |

## 9. ファイルサイズチェック

### 9.1 現在行数
- `cards.json`: 2200行超（boss_decks追加で約120行、boss_exclusive_units追加で約80行増加予定 → 約2400行）
- `CardDB.gd`: 51行（+4行 → 55行）
- `EnemyAI.gd`: 277行（+4行、-6行 → 275行）

### 9.2 判定
- cards.json: 肥大化傾向だがデータファイルのため分割不要（Act2/Act3追加でさらに増加するがPhase 4で対応）
- CardDB.gd: 55行 → 分割不要
- EnemyAI.gd: 275行 → 分割不要

## 10. 完了報告フォーマット

```
# Act1 ボスシステム完成 実装完了報告

## 実装内容
- cards.json: boss_decks 9デッキ追加
- cards.json: boss_exclusive_units 5体追加
- cards.json: bosses alert_level_buffs修正
- CardDB.gd: BOSS_DECKS/BOSS_EXCLUSIVE_UNITS読み込み実装
- EnemyAI.gd: _build_boss_deck() TODO解消

## テスト結果
- [ ] JSON構文チェック: OK
- [ ] CardDB読み込みテスト: OK（ログ出力確認）
- [ ] ボス戦デッキ構築テスト: OK（3ボス × 3段階確認）
- [ ] 警戒レベル別バフテスト: OK（Lv4/Lv5確認）
- [ ] ボス専用ユニット配置テスト: OK（5体確認）

## 修正ファイル
- C:\Users\kazum\dungeon-board-game\data\cards.json
- C:\Users\kazum\dungeon-board-game\scripts\CardDB.gd
- C:\Users\kazum\dungeon-board-game\scripts\EnemyAI.gd
```
