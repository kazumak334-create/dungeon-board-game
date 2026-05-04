STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# サポート効果パーティクル可視化 要件定義書

## 1. 概要

サポートスキルが発動した際、発動元ユニットのセルから対象ユニットのセルへ向けて、弧を描くパーティクルアニメーションを表示する。バフ/デバフの種別を色で区別し、バトル観戦中にサポート効果の発動を視覚的に把握できるようにする。

---

## 2. 表示仕様

### 2-1. 色分け

| 対象種別 | 色 | 適用条件 |
|---|---|---|
| 味方マス（バフ・回復系） | `Color(0.3, 0.8, 1.0, 0.9)` 青緑系 | `is_enemy_target == false` |
| 敵マス（デバフ・毒系） | `Color(0.7, 0.2, 1.0, 0.9)` 紫系 | `is_enemy_target == true` |

### 2-2. パーティクル仕様

| 項目 | 値 |
|---|---|
| 粒子数 | 2〜3個 / 対象マス |
| 形状 | ColorRect または Node2D（6px 円形） |
| アニメーション | 発動元セル中心 → 対象セル中心へ放物線移動 |
| 所要時間 | 0.4秒 |
| z_index | 65（攻撃ラインのz_index=60 より上） |
| 消滅 | 到達後 queue_free() |

### 2-3. 放物線（弧）計算式

Tweenによる2段階補間で弧を表現する。

```
頂点位置 = (発動元中心 + 対象中心) / 2 + Vector2(0, -arc_height)
arc_height = 40px（固定）

フェーズ1: 発動元 → 頂点  (時間: 0.2秒)
フェーズ2: 頂点 → 対象    (時間: 0.2秒)
```

各粒子は 0〜0.08秒のランダムな発火ディレイを持つ（粒子が同時発射にならないよう散らす）。

### 2-4. 攻撃ラインとの空間的干渉

攻撃ライン（黄色・水平方向・z_index=60）は Line2D で同一平面上に描画される。
パーティクルは弧を描く軌道であり、かつ z_index=65 で上位レイヤーに存在するため、視覚的な干渉は発生しない。追加対応不要。

---

## 3. 発火条件

### 3-1. タイミング

`SupportSystem.apply_support_effects()` 内の `always` トリガースキル処理ループ、
`bm.effect_executor.execute()` 呼び出しの直後に発火する。

具体的には SupportSystem.gd の以下のブロック（line 59-64）の直後：
```gdscript
bm.effect_executor.execute(skill["effect_id"], merged_params, {
    "trigger": "always", "side": s, "row": r, "col": c,
    "source": u, ...
})
# ← ここでパーティクル発火
```

注：`_process_unit_support()` は呼び出し元が存在しないデッドコードのため使用しない。

### 3-2. ターゲット解決方法

`merged_params` に含まれる `"target"` 文字列から対象を特定する。
EffectTargets インスタンスを `apply_support_effects()` 内で生成し、`resolve()` で対象ユニットリストを取得する。

```gdscript
var targets_resolver = load("res://scripts/EffectTargets.gd").new()
var is_ally = not (target_str.begins_with("enemy") or target_str == "all_enemies")
var targets = targets_resolver.resolve(merged_params, context_dict, is_ally)
```

各ターゲットユニットのセル位置は bm.board を走査して特定する。

### 3-3. 発火の判定

targets が空配列の場合はパーティクルを生成しない。
`target` が "self" の場合は from_pos == to_pos になるため、上昇・落下のみ（弧なし）でよい。

---

## 4. 実装対象ファイルと変更方針

### 4-1. GameUIOverlay.gd（既存パターンに合わせた実装場所）

既存の `spawn_attack_line` / `spawn_effect_text` / `spawn_damage_float` は **GameUIOverlay.gd** に実装されており、GameUI.gd がデリゲートするアーキテクチャになっている。パーティクルも同一パターンで実装する。

**追加する関数：**

```
GameUIOverlay.gd:
  func spawn_support_particles(from_pos: Vector2, to_pos: Vector2, is_enemy_target: bool) -> void
```

| 引数 | 型 | 説明 |
|---|---|---|
| from_pos | Vector2 | 発動元セルの中心座標（スクリーン座標） |
| to_pos | Vector2 | 対象セルの中心座標（スクリーン座標） |
| is_enemy_target | bool | true=敵対象（紫）/ false=味方対象（青緑） |

### 4-2. GameUI.gd（デリゲート追加）

既存の `spawn_attack_line` デリゲートと同パターンで追加する。

```
GameUI.gd:
  func spawn_support_particles(from_pos: Vector2, to_pos: Vector2, is_enemy_target: bool) -> void:
      _overlay.spawn_support_particles(from_pos, to_pos, is_enemy_target)
```

### 4-3. SupportSystem.gd（呼び出し追加）

`bm`（BoardManager）は `get_node_or_null("/root/Main")` 経由で `main.game_ui` を取得できる（BoardManager.gd で確認済みのパターン）。

`_process_unit_support()` の targets ループ内で、セル座標をスクリーン座標に変換して呼び出す。

**セル中心座標の算出式（既存の `_cell_x` 相当）：**

BoardManager は `bm` 経由で `main` ノードに到達し、`main.BOARD_TOP / CELL_W / CELL_H / CENTER_X` を参照できる。

```
from_x = (セル左上X) + CELL_W / 2
from_y = BOARD_TOP + src_row * CELL_H + CELL_H / 2
to_x   = (セル左上X) + CELL_W / 2
to_y   = BOARD_TOP + dst_row * CELL_H + CELL_H / 2
```

セル左上X の算出は `GameUIOverlay._cell_x(side, col)` と同等のロジックを SupportSystem 内で再現するか、main への参照を使って計算する（実装者判断）。

**GameUI への参照取得：**

```gdscript
var main_node = bm.get_node_or_null("/root/Main")
if main_node and main_node.game_ui:
    main_node.game_ui.spawn_support_particles(from_pos, to_pos, is_enemy_target)
```

---

## 5. 複数対象の処理

対象が複数マスの場合（前列全体・同行など）、各対象マスに対して独立して `spawn_support_particles` を呼び出す。1回の発動で複数回呼ぶことが前提であり、ライン描画は行わない。

---

## 6. 除外事項（やらないこと）

- `_process_unit_support()` の活用は対象外（デッドコードのため）。
- アーティファクトの `always` スキル処理（line 66-78）への発火追加は対象外。
- `_apply_class_skills()` への対応は対象外。
- パーティクルの残像・フェードアウト効果は対象外（到達後即 queue_free）。
- GPU パーティクル（GPUParticles2D）の使用は対象外（GDScript Tween + Node2D のみ）。
- サポート効果音は対象外。

---

## 7. ファイルサイズ確認（予防的品質管理）

| ファイル | 現在行数 | 追加予測行数 | 判定 |
|---|---|---|---|
| GameUIOverlay.gd | 約170行 | +40行（spawn関数+update処理） | 210行予測・問題なし |
| GameUI.gd | 約505行 | +5行（デリゲート） | 510行予測・問題なし |
| SupportSystem.gd | 318行 | +20行（呼び出し追加） | 338行予測・問題なし |

いずれも500行未満の範囲に収まるため、ファイル分割は不要。

---

## 8. 制約・注意事項

- Godot 4.6.2 / GDScript のみ使用。外部プラグイン不可。
- Tween は `main.create_tween()` を使用すること（`Node` の `create_tween` が必要なため、RefCounted ベースの SupportSystem から直接生成不可）。GameUI 側（Overlay）で生成する。
- `_process_unit_support()` は `apply_support_effects()` から呼び出されていない（現状デッドコードの可能性あり）。実装前に呼び出し元を確認すること（Grep 必須）。
- 既存の `_attack_lines` / `_effect_floats` の update ループと同様に、パーティクルの生存管理（timer による自動削除）を GameUIOverlay._process または update 関数に追加する。
