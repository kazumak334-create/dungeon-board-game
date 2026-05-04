STATUS: 廃止（→ docs/GAME_DESIGN_V0_2_MVP.md）
最終更新: 2026-05-04

# Act2/Act3ボスデッキ構成企画書

作成日: 2026-04-20
種別: デッキ構成企画

---

## 企画意図

Act2/Act3の初期MVPボス戦デッキ構成を定義する。
各Actのテーマ（アンデッド/獣）に沿った7体編成を提供し、通常戦enhanced1/enhanced2レベルの難易度バランスを実現する。

---

## Act2: boss_deadlock（アンデッド）

### テーマ
- アンデッド中心
- デバフ・状態異常による戦線崩し
- 後列からの遠距離攻撃

### ベースデッキ（boss_act2_deadlock）

**難易度**：通常戦enhanced1レベル

**構成**：7体

```json
"boss_act2_deadlock": [
    {"name": "グリムハウル", "col": 0},
    {"name": "ワイト", "col": 0},
    {"name": "グリムハウル", "col": 1},
    {"name": "カーシール", "col": 1},
    {"name": "バンシー", "col": 2},
    {"name": "バンシー", "col": 2},
    {"name": "カーシール", "col": 1}
]
```

**配置バランス**：
- 前列（col:0）：2体（グリムハウル×1、ワイト×1）
- 中列（col:1）：3体（グリムハウル×1、カーシール×2）
- 後列（col:2）：2体（バンシー×2）

**戦術的特徴**：
- 前列：ワイトのタンク + グリムハウルの状態異常
- 中列：カーシールの呪い付与による支援
- 後列：バンシーの広範囲燃焼攻撃

### 強化デッキ（boss_act2_deadlock_strong）

**難易度**：通常戦enhanced2レベル

**構成**：7体

```json
"boss_act2_deadlock_strong": [
    {"name": "トレイトベイン", "col": 0},
    {"name": "ワイト", "col": 0},
    {"name": "カーシール", "col": 1},
    {"name": "ワイト", "col": 1},
    {"name": "リッチ", "col": 2},
    {"name": "バンシー", "col": 2},
    {"name": "屍術師", "col": 2}
]
```

**配置バランス**：
- 前列（col:0）：2体（トレイトベイン×1、ワイト×1）
- 中列（col:1）：2体（カーシール×1、ワイト×1）
- 後列（col:2）：3体（リッチ×1、バンシー×1、屍術師×1）

**戦術的特徴**：
- 前列：トレイトベイン（特性封印）+ ワイトの高耐久
- 中列：ワイト追加でタンク層強化
- 後列：リッチ（凍結）+ バンシー（燃焼）+ 屍術師（毒）の多様なデバフ

---

## Act3: boss_guardian（獣）

### テーマ
- 獣中心
- 高ATK/SPDによる速攻
- 味方死亡時バフ（Rageveil）による持久戦

### ベースデッキ（boss_act3_guardian）

**難易度**：通常戦enhanced1レベル

**構成**：7体

```json
"boss_act3_guardian": [
    {"name": "ウルフ", "col": 0},
    {"name": "Rageveil", "col": 0},
    {"name": "ウルフ", "col": 1},
    {"name": "ケットシー", "col": 1},
    {"name": "ワイルドホーク", "col": 2},
    {"name": "ケットシー", "col": 2},
    {"name": "Thornbeast", "col": 1}
]
```

**配置バランス**：
- 前列（col:0）：2体（ウルフ×1、Rageveil×1）
- 中列（col:1）：3体（ウルフ×1、ケットシー×1、Thornbeast×1）
- 後列（col:2）：2体（ワイルドホーク×1、ケットシー×1）

**戦術的特徴**：
- 前列：ウルフ（高ATK/SPD）+ Rageveil（味方死亡時回復バフ）
- 中列：ケットシー（高速）+ Thornbeast（反撃）
- 後列：ケットシー・ワイルドホークの高速攻撃

### 強化デッキ（boss_act3_guardian_strong）

**難易度**：通常戦enhanced2レベル

**構成**：7体

```json
"boss_act3_guardian_strong": [
    {"name": "Rageveil", "col": 0},
    {"name": "マンティコア", "col": 0},
    {"name": "Thornbeast", "col": 1},
    {"name": "マンティコア", "col": 1},
    {"name": "ワイルドホーク", "col": 2},
    {"name": "猛獣使い", "col": 2},
    {"name": "Rageveil", "col": 1}
]
```

**配置バランス**：
- 前列（col:0）：2体（Rageveil×1、マンティコア×1）
- 中列（col:1）：3体（Thornbeast×1、マンティコア×1、Rageveil×1）
- 後列（col:2）：2体（ワイルドホーク×1、猛獣使い×1）

**戦術的特徴**：
- 前列：Rageveil（持久戦）+ マンティコア（毒付与）
- 中列：マンティコア追加 + Thornbeast（反撃）+ Rageveil（回復バフ）
- 後列：猛獣使い（燃焼付与）+ ワイルドホーク（高速攻撃）

---

## 設計意図の確認

### Act1との比較

**Act1_beast（参考）**：
- ウルフ、Fangos、ケットシー、ワイルドホーク、Thornbeast（7体）
- 獣テーマ・バランス型構成

**Act2_deadlock（アンデッド）**：
- グリムハウル、ワイト、カーシール、バンシー
- デバフ特化・遠距離攻撃重視

**Act3_guardian（獣）**：
- ウルフ、Rageveil、ケットシー、Thornbeast、ワイルドホーク、マンティコア
- Act1_beastより強力なユニット（Rageveil・マンティコア追加）

### 難易度バランス確認

- ベースデッキ：act2/act3_enhanced1相当
- 強化デッキ：act2/act3_enhanced2相当
- 既存enemy_poolsと同等の難易度

---

## データ構造

cards.json `boss_decks` セクションに追加：

```json
"boss_decks": {
    "boss_act2_deadlock": [...],
    "boss_act2_deadlock_strong": [...],
    "boss_act3_guardian": [...],
    "boss_act3_guardian_strong": [...]
}
```

---

## 参照

- data/cards.json `enemy_pools` セクション
- data/cards.json `units` セクション
- data/cards.json `boss_decks` セクション（既存Act1ボス構成）
- docs/GAME_DESIGN.md
