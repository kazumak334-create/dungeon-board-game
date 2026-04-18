# 用語統一状況と今後の対応

## 統一完了項目

### ✅ 盤面構造
- 列：前列・中列・後列（統一済み）
- 行：上行・中行・下行（統一済み）
- 対象指定：自/敵の枕詞使用（統一済み）

### ✅ トリガー定義
- glossary.mdに完全版を追加（2026-04-17）
- 実装名（英語）と日本語名の対応表を整備

---

## 統一推奨項目（破壊的変更のため慎重に）

### 🟡 同義語トリガーの統一

**優先度：中**

| 現状の同義語 | 推奨形式 | 使用箇所 | 影響範囲 |
|---|---|---|---|
| `on_summon` / `on_unit_placed` | `on_summon` | cards.json各1回 | 小 |
| `on_ally_death` / `on_unit_died_ally` | `on_ally_death` | cards.json計3回 | 小 |
| `always` / `passive` | `always` | cards.json計24回 | 中 |

**対応方針：**
- Phase 6以降で段階的に統一
- EffectExecutor.gdで同義語を内部的に変換
- cards.jsonは順次修正

**実装例：**
```gdscript
# EffectExecutor.gd
func _normalize_trigger(trigger: String) -> String:
    match trigger:
        "on_unit_placed": return "on_summon"
        "on_unit_died_ally": return "on_ally_death"
        "passive": return "always"
        _: return trigger
```

---

## 未定義・不明確項目

### 🔴 トリガーの詳細仕様

**on_hit vs on_front_attack の使い分け**
- `on_hit`（42回）：攻撃命中時？前列・中列・後列すべて？
- `on_front_attack`（15回）：前列攻撃時のみ？

**推奨：**
- on_front_attack = 前列能力専用（前列配置時のみ発動）
- on_hit = 命中時効果（配置列に関わらず発動）

**timer トリガーの仕様**
- 発動間隔は？（固定？パラメータ指定？）
- 初回発動タイミングは？（バトル開始直後？一定時間後？）

**推奨：**
- skills配列にintervalパラメータを追加
- 例：`{"trigger": "timer", "effect_id": "xxx", "params": {"interval": 5.0}}`

---

## 設計文書の用語統一状況

### ✅ GAME_DESIGN.md
- 盤面構造：統一済み（前列・中列・後列）
- カード効果：「前列能力」「サポート効果」「特性」使用（統一済み）

### 🟡 cards.json
- トリガー名：英語表記（統一済み）
- 効果記述：日本語（一部不統一の可能性あり）

### 🟡 design_principles.md
- 用語使用：概ね統一
- 追加確認：「前列能力」「サポート効果」「特性」の使い分け

---

## 今後の対応タスク

### Phase 6（次期フェーズ）
1. 同義語トリガーの統一（EffectExecutor.gd修正）
2. timer トリガーの仕様確定
3. on_hit / on_front_attack の使い分けルール明文化

### Phase 7以降
4. cards.jsonの効果記述の用語統一チェック
5. 全設計文書の用語統一監査
6. 復活時トリガー（on_revive）の追加検討

---

## 参考：トリガー使用頻度（cards.json）

```
on_play (58回)          - 呪文発動時
on_hit (42回)           - 命中時
always (21回)           - 常時
on_support (18回)       - サポート発動時
on_front_attack (15回)  - 前列攻撃時
on_death (9回)          - 死亡時
timer (7回)             - 時間経過
passive (3回)           - パッシブ
on_damaged (2回)        - 被攻撃時
on_ally_death (2回)     - 味方死亡時
on_unit_placed (1回)    - 配置時
on_unit_died_ally (1回) - 味方死亡時
on_synthesis (1回)      - 合成時
on_summon (1回)         - 召喚時
on_attack (1回)         - 攻撃時
battle_start (1回)      - バトル開始時
```

---

## 更新履歴

- 2026-04-17：初版作成・glossary.md拡充完了
