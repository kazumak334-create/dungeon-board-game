# 新呪文システム（StS方式）全面再設計 要件定義書

作成日: 2026-04-26
設計確定: 2026-04-27
最終更新: 2026-04-27（コスト・効果・対象選択操作を確定）

---

## 1. 概要

呪文システムをSlay the Spire方式（山札/手札/捨て札サイクル）に再設計する。
バトル開始時に初期デッキ11枚がセットされ、プレイヤーが対象選択UIを介して手動発動する。

### 確定仕様サマリー

| 項目 | 確定内容 |
|-----|---------|
| 発動方式 | 手動発動（対象選択あり：WASDキーまたはマウスD&D） |
| デッキサイクル | 山札 / 手札 / 捨て札（StS方式） |
| 初期デッキ | 固定11枚（マナ結晶×5 / 火球×3 / ガード×3） |
| マナ結晶コスト | 0（効果: マナ+1、対象選択なし・即時発動） |
| 火球コスト | 5（効果: 敵単体攻撃、対象選択あり） |
| ガードコスト | 4（効果: 自ユニット1体に鎧1付与、対象選択あり） |

---

## REQ-A: cards.json への初期デッキカード追加

### 2. 実装対象

- ファイル: `data/cards.json`
- 変更箇所: `"spells"` セクション（L557付近）に3種追加

### 3. データ構造

追加する3種のカード定義（`spells` セクションに追加）：

```json
"マナ結晶": {
    "anim": "",
    "rarity": "common",
    "mana": 0,
    "effect": "マナ+1",
    "sfx": "",
    "is_consumable": true,
    "skills": [
        {
            "effect_id": "mana_gain",
            "params": {},
            "target": "self",
            "trigger": "on_play"
        }
    ],
    "target": "self",
    "texture": ""
},
"火球Ⅰ": {
    "anim": "",
    "rarity": "common",
    "mana": 5,
    "effect": "敵単体を攻撃",
    "sfx": "",
    "is_consumable": true,
    "requires_target": true,
    "skills": [
        {
            "effect_id": "single_enemy_damage",
            "params": {},
            "target": "enemy_single",
            "trigger": "on_play"
        }
    ],
    "target": "enemy_single",
    "texture": ""
},
"ガード": {
    "anim": "",
    "rarity": "common",
    "mana": 4,
    "effect": "自ユニット1体に鎧1付与",
    "sfx": "",
    "is_consumable": true,
    "requires_target": true,
    "skills": [
        {
            "effect_id": "armor_apply",
            "params": {
                "amount": 1
            },
            "target": "ally_single",
            "trigger": "on_play"
        }
    ],
    "target": "ally_single",
    "texture": ""
}
```

**追加場所**: `"spells": {` の先頭エントリの直前（L557の `{` の次行）

### 4. 実装詳細

**手順:**
1. `data/cards.json` の `"spells":` セクション冒頭（L557〜L559付近）に上記3エントリを追加
2. JSON構文エラーに注意（追加後の末尾カンマの有無を確認）

**注意:** `spells` セクションに追加する理由は、`DeckManager.get_spell_card_by_name()` が `CardDB.SPELLS` のみ参照するため。`system_spells` に追加すると別途修正が必要になる。

### 5. 受け入れ基準

- [ ] `CardDB.SPELLS.has("マナ結晶")` が true
- [ ] `CardDB.SPELLS.has("火球Ⅰ")` が true
- [ ] `CardDB.SPELLS.has("ガード")` が true
- [ ] JSONパースエラーが発生しない
- [ ] 各カードの `mana` フィールドが正しい（0 / 5 / 4）
- [ ] 火球Ⅰ・ガードの `requires_target: true` が設定されている
- [ ] マナ結晶の `target: "self"` が設定されている（対象選択なし）

### 6. 依存関係

- 前提タスク: なし（最初に実施）
- 後続タスク: REQ-B（Main._start_battle()でこれらのカード名を参照）

### 7. 制約・注意事項

- 既存の「火球」（L868: コスト5・15ダメ）は変更しない。別エントリ「火球Ⅰ」として追加
- `is_consumable: true` を必ず設定（捨て札サイクルに乗せるため）
- `requires_target: true` を火球Ⅰ・ガードに設定（対象選択UIを起動するフラグ）
- `mana_gain` エフェクトID: EffectDB.gd L71 で定義済み（amount=1 が既定値）
- `single_enemy_damage` エフェクトID: cards.json L876で使用例あり（ダメージ量はパラメータではなくカードatk等から計算する場合は params: {} でよい）
- `armor_apply` エフェクトID: 鎧付与エフェクト。amount=1（鎧1段階）
- `ally_single` ターゲット: cards.json L1051で使用例あり

---

## REQ-B: Main._start_battle() への初期デッキ初期化追加

### 2. 実装対象

- ファイル: `scripts/Main.gd`
- 変更箇所: `_start_battle()` L267 内

### 3. データ構造

変更なし。既存の `GameSession.spell_deck`（Array・L47）を利用。

### 4. 実装詳細

**追加処理の挿入箇所:** `_start_battle()` の `deck_manager.ensure_shuffle_card()` （L278）の直前

**擬似コード:**

```gdscript
# 初期デッキが空の場合、デフォルト11枚をセット
if GameSession.spell_deck.is_empty():
    var starter: Array = []
    for i in range(5):
        starter.append("マナ結晶")
    for i in range(3):
        starter.append("火球Ⅰ")
    for i in range(3):
        starter.append("ガード")
    starter.shuffle()
    GameSession.spell_deck = starter
    print("[Main] 初期スペルデッキ設定: %d枚" % GameSession.spell_deck.size())

# 手札補充（バトル開始時3枚ドロー）
if spell_slot_system != null:
    spell_slot_system.draw_to_fill_slots()
```

**挿入後のコードフロー（L278付近）:**
```
L278: deck_manager.ensure_shuffle_card()
      ↓ [新規追加: 初期デッキセット + ドロー]
L279: enemy_ai.ensure_shuffle_card()
```

### 5. 受け入れ基準

- [ ] バトル開始時に `GameSession.spell_deck` が空の場合、マナ結晶5枚・火球Ⅰ3枚・ガード3枚（計11枚）がセットされる
- [ ] `GameSession.spell_deck` が空でない場合（既にデッキ設定済み）は上書きしない
- [ ] バトル開始時にスロット3枠が補充される
- [ ] ログに `[Main] 初期スペルデッキ設定: 11枚` が出力される（初期化時のみ）

### 6. 依存関係

- 前提タスク: REQ-A（cards.jsonにカード定義が存在すること）
- `spell_slot_system.draw_to_fill_slots()`: SpellSlotSystem.gd L510 で実装済み

### 7. 制約・注意事項

- `GameSession.spell_deck.is_empty()` でガード（既存デッキ選択時は上書きしない）
- ローグライク途中のバトル再開時も `spell_deck` が空でなければ既存デッキを維持
- `spell_slot_system` が null の場合は `draw_to_fill_slots()` を呼ばない（null チェック必須）
- シャッフル（`starter.shuffle()`）は `GameSession.spell_deck` に代入する前に実施

---

## REQ-C: SpellSlotSystem 確認（変更不要）

### 2. 実装対象

- ファイル: `scripts/SpellSlotSystem.gd`

### 3. 確認結果

**変更不要。** 以下の調査結果に基づく：

- `process_slots(delta)` L147: キャストタイマー更新のみ（自動発動ループなし）
- `_check_condition()` L152: `cast_spell()` / `can_cast()` から呼ばれるが、手動クリック起点なので問題なし
- 左クリック発動: `GameUIQueue._on_spell_slot_input()` L344 → `cast_spell()` L327 実装済み
- 右クリック捨て: `GameUIQueue._on_spell_slot_input()` L381 → `discard_slot()` L498 実装済み
- `draw_to_fill_slots()` L510: 捨て札シャッフル→山札に戻す処理含む実装済み

**条件チェック（_check_condition）について:**
`can_cast()` L295 内で `_check_condition()` を呼んでいるが、初期デッキカードは全て `"always"` 条件で `set_slot()` されるため常にtrueになる。変更不要。

### 4. 受け入れ基準

- [ ] 変更なし（確認のみ）
- [ ] SpellSlotSystem.gd のファイルが変更されていない

---

## REQ-D: DeckManager.get_spell_card_by_name() の SYSTEM_SPELLS 対応（オプション）

### 2. 実装対象

- ファイル: `scripts/DeckManager.gd`
- 変更箇所: `get_spell_card_by_name()` L219

### 3. 確認

**今回は不要。** REQ-A で初期デッキカードを `spells` セクションに追加するため、`get_spell_card_by_name()` の既存実装（`CardDB.SPELLS` 参照）で動作する。

将来 `system_spells` に呪文カードを追加したい場合は、`get_spell_card_by_name()` に以下を追加すること：

```gdscript
elif CardDB.SYSTEM_SPELLS.has(spell_name):
    var d: Dictionary = CardDB.SYSTEM_SPELLS[spell_name]
    var u = _UnitDataScript.new()
    u.unit_name = spell_name
    u.card_type = "spell"
    u.spell_id = spell_name
    u.mana = d.get("mana", 0)
    u.is_consumable = d.get("is_consumable", true)
    u.spell_target = d.get("target", "")
    u.spell_effect = d.get("effect", "")
    u.skills = d.get("skills", []).duplicate(true)
    return u
```

### 4. 受け入れ基準

- [ ] 今回は変更なし（将来用メモとして記録）

---

---

## REQ-E: 対象選択UI（WASDキー＋マウスD&D）

### 2. 概要

`requires_target: true` の呪文を発動しようとした際に対象選択モードに入る。
操作方法はWASDキーとマウスD&Dの2系統を両方サポートする。

### 3. 対象選択モードの状態遷移

```
通常状態
  ↓ 手札の呪文カードをクリック（requires_target=true）
対象選択モード（カーソル表示 / D&D待機）
  ↓ 有効なマスを選択・確定
呪文発動 → 捨て札へ
  ↓ ESCキーまたは右クリック
キャンセル → 通常状態に戻る
```

### 4. 操作方式A：WASDキー

| 操作 | 挙動 |
|-----|------|
| 対象選択モード突入時 | 盤面にカーソルを表示（初期位置：有効な最初のマス） |
| W / A / S / D | カーソルを上 / 左 / 下 / 右に1マス移動 |
| Enter または スペース | 現在カーソル位置で確定（有効マスのみ） |
| ESC | キャンセル・通常状態に戻る |

- カーソルは盤面グリッドに沿って移動（9マスの範囲内）
- 有効マス：火球＝敵ユニットが存在するマス、ガード＝自ユニットが存在するマス
- 無効マス（空マス・対象外）ではEnterを押しても確定しない

### 5. 操作方式B：マウスD&D

| 操作 | 挙動 |
|-----|------|
| 手札の呪文カードをドラッグ開始 | 対象選択モードに入る（ドラッグ中）|
| 有効なユニットマスにドロップ | 呪文発動・確定 |
| 無効なマス・盤面外にドロップ | キャンセル・通常状態に戻る |

- ドラッグ中は対象候補マスをハイライト表示
- ドロップ先が無効なマスの場合、カードは手札に戻る

### 6. 対象制限

| 呪文 | 有効な対象 | 無効な対象 |
|-----|----------|----------|
| 火球 | 敵ユニットが存在するマス | 空マス・自ユニットマス |
| ガード | 自ユニットが存在するマス | 空マス・敵ユニットマス |
| マナ結晶 | 対象選択なし（即時発動） | - |

### 7. 実装対象

- 対象選択モード管理: SpellSlotSystem.gd または GameUI.gd（既存の入力処理に統合）
- WASDカーソル表示: GameUIOverlay.gd（既存のオーバーレイ層に追加）
- D&Dイベント: GameUIQueue.gd（既存の `_on_spell_slot_input()` を拡張）

### 8. 受け入れ基準

- [ ] requires_target=true の呪文をクリックすると対象選択モードに入る
- [ ] WASDキーでカーソルが移動する
- [ ] Enter/スペースで有効マスを確定できる
- [ ] 無効マスでEnterを押しても何も起きない
- [ ] 手札カードのD&Dで有効ユニットマスにドロップすると発動する
- [ ] 無効マス・盤面外ドロップでキャンセル・カードが手札に戻る
- [ ] ESCキーでキャンセルできる
- [ ] requires_target=false（マナ結晶）は従来通りクリックで即時発動

### 9. 制約・注意事項

- 対象選択モード中はほかのUI操作（別の呪文クリック等）を無効化する
- D&DはSpellSlotSystemの既存D&D基盤（GameUIQueue）を流用する
- WASDカーソルはバトル中のみ表示（他画面では非表示）
- カーソルのビジュアルは既存のUIFactory/GameUIOverlayの枠組みに合わせる

---

## 実装順序

1. REQ-A: cards.json に3カード追加（コスト・requires_target更新済み定義）
2. REQ-B: Main._start_battle() に初期デッキ初期化追加
3. REQ-E: 対象選択UI実装（WASDカーソル + D&D）
4. REQ-C / REQ-D: 変更不要（確認のみ）

---

## 実装可能性チェックリスト

- [x] effect_id が EffectDB.gd で定義済みか — mana_gain(L71), single_enemy_damage(使用例あり), armor_apply(要確認)
- [x] ターゲット名が既存コードで使用済みか — enemy_single(L880), ally_single(L1051), self(使用例あり)
- [x] 初期デッキ上書き防止ガードが明記されているか — `is_empty()` チェック
- [x] null チェックが明記されているか — `spell_slot_system != null`
- [x] JSON構文エラー対策が明記されているか — 末尾カンマの確認
- [x] is_consumable フィールドが設定されているか — 全3カードに true を設定
- [x] requires_target フィールドが設定されているか — 火球Ⅰ・ガードに true、マナ結晶は設定なし（false扱い）
- [x] 既存コードとの連携箇所が明記されているか — draw_to_fill_slots(), get_spell_card_by_name()
- [ ] armor_apply エフェクトID の実装状況確認（EffectDB.gd で未定義の場合は追加が必要）

---

## 廃止対象（今回のスコープ外）

以下は将来タスクとして残す：
- SpellSlotSystem の条件設定UI廃止（現状は PHASE_ACTION モードでのみ使用）

---

## 確定仕様（2026-04-27 追記）

### REST画面 呪文タブ

- Rest画面の呪文タブは `GameSession.spell_deck` の内容を**閲覧専用**で表示する
- 抜き差し・編集は不可
- `spell_available`（入手済み呪文プール）の概念は廃止。Rest画面には表示しない

### MANA_MAX 廃止

- 呪文マナの上限 `MANA_MAX` 定数を廃止する
- マナは上限なしで蓄積できる
- 廃止理由：上限があると入手した呪文がデッキに反映されないバグが生じる
- 影響ファイル：`scripts/DeckManager.gd`（MANA_MAX 定数・参照箇所を削除）

### ショップ デッキ削減商品

- ショップの商品ラインナップにランダムで「呪文デッキから1枚削除」商品が出現する
- 毎回必ず出るわけではない（確率出現）
- 購入すると `GameSession.spell_deck` から1枚選んで削除できるUIを起動する
- 詳細仕様：`docs/design/rest_screen_shop_requirements.md` §8-EX 参照
