# Sprint 6 実装リクエスト：戦闘・人口減少システム

**作成日**: 2026-05-03  
**対象**: Econ MVP V0.2  
**Sprint**: 6 / 8

---

## 実装概要

Sprint 6 では、戦闘システムと戦闘による人口減少を実装する。

**核となる仕様:**
- 突撃（charge）: 敵兵力を減らすが、**人口には影響しない**
- 防衛突破（defense breakthrough）: 敵が自拠点を突破した場合のみ人口が減少
- 防衛突破ダメージ計算: `damage = breakthrough_units × 1`（1ユニット = 内部人口5）
- 即時人口減少: Sprint 3 の `apply_population_loss(amount)` を使用
- 兵力補正の適用: 戦闘時に満足度段階による兵力効果補正を適用

---

## 根拠ドキュメント

以下のドキュメントを参照して実装してください：

1. **企画書（確定版）**
   - G:\マイドライブ\ざったなファイル\ゲームアイデア系\v0.2_MVP用\sprint6_battle_population_system_final.md

2. **要件定義書**
   - `docs/requirements/req_econ_battle_population_sprint6.md`

**重要**: 企画書 Final 版が Single Source of Truth です。

---

## 実装対象ファイル

主要変更対象:
- 戦闘処理ファイル（PvE ウェーブ処理など）
  - 防衛突破判定ロジック
  - 人口減少の適用タイミング
  
- `scripts/econ_mvp/EconEconomy.gd`
  - `apply_population_loss(amount)` の呼び出し
  - 戦闘結果の人口減少反映

---

## 実装内容

### 1. 戦闘フェーズ終了時の判定

#### 1.1 突撃（Charge）
- **効果**: 敵兵力を減らす
- **人口への影響**: **なし**
- **兵力補正**: 満足度段階による兵力効果補正を適用可能
  ```
  有効攻撃兵力 = 突撃兵力 × (1 + 兵力効果補正)
  ```

#### 1.2 防衛突破（Defense Breakthrough）
- **発生条件**: 敵が防衛陣地を突破した場合
- **効果**: 敵突破兵力 = 敵兵力 - 防衛兵力（敵兵力がマイナスにならない）
- **人口ダメージ**: `敵突破兵力 × 1` = `敵突破兵力 × 内部人口5` ÷ 5
  
  > 簡潔にするため、敵突破兵力をそのまま内部人口として減少させる：
  ```
  apply_population_loss(enemy_breakthrough_units)
  ```

### 2. ユニット換算

```
1ユニット = 内部人口5
```

例：
```
敵突破兵力: 10ユニット
→ apply_population_loss(10)
→ 内部人口 10 減少（表示: 10k人減少）
```

### 3. 即時人口減少処理

Sprint 3 で実装済みの `apply_population_loss(amount)` を呼び出す：

```gdscript
# 防衛突破時
if enemy_breakthrough_units > 0:
    economy.apply_population_loss(float(enemy_breakthrough_units))
```

### 4. 戦闘終了後の反映

- 防衛突破による人口減少は即時に反映
- 満足度は次フレームから傾きに反映されるため、自動的に下落が始まる
- 人口が下限 10 を下回らないようにクランプ

### 5. 兵力補正の戦闘への適用（オプション）

满足度段階による兵力効果補正を戦闘計算に組み込む場合：

```gdscript
# 兵力効果補正を取得
satisfaction_stage = economy.get_satisfaction_stage()
military_effectiveness = get_military_effectiveness_modifier(satisfaction_stage)
# -20% ～ +10% (-0.20 ～ +0.10)

# 有効兵力を計算
effective_military = current_military * (1.0 + military_effectiveness)

# 戦闘計算で有効兵力を使用
```

---

## 完了条件

要件定義書 `req_econ_battle_population_sprint6.md` のチェックリストをすべて満たすこと：

### 戦闘フェーズ
- [ ] 突撃が敵兵力を減らす
- [ ] 突撃時に人口が減少しない

### 防衛突破
- [ ] 防衛突破判定が正しく実行される
- [ ] 敵突破兵力が計算される
- [ ] 敵突破兵力がそのまま内部人口減少に変換される

### 人口減少適用
- [ ] `apply_population_loss(amount)` が正しく呼び出される
- [ ] 人口が即座に減少する
- [ ] 人口下限 10 を下回らない

### 兵力補正（オプション）
- [ ] 満足度段階から兵力効果補正が取得できる
- [ ] 戦闘時に兵力補正が適用される（実装の場合）

### テスト
- [ ] `bash check_syntax.sh` エラー 0 件
- [ ] 戦闘フェーズが正常に完了する

---

**実装準備完了。Codex へお願いします。**
