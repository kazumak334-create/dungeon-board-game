STATUS: 廃止（→ docs/requirements/REQUIREMENTS_SPRINT_7.md）
最終更新: 2026-05-04

# 要件定義書: EconMVP ユニット種別陣形システム + Priority AIパターン拡張

更新日: 2026-05-01
STATUS: 企画確定（実装は次回MVP以降）

企画書: ユーザー指示 2026-05-01 / Planning設計成果物 2026-05-01

---

## 0. スコープ

EconMVP のユニット行動に「陣形システム」を追加し、Priority AIパターンを3種から6種に拡張する。

### 核となる体験との整合性

- 「建物ごとに陣形を設定する」= バトル前の設計フェーズで完結する
- 陣形 × Priority AI の組み合わせが「設計の深み」になる
- KISS原則: formation_mode フィールド1つを建物に追加するだけで実現

### スコープ外

- 旗ごとの陣形設定（旗が複数になってから検討）
- バトル中の陣形変更（「設計して観戦する」体験と矛盾するため廃止）

---

## 1. ユニット種別陣形システム

### 1.1 設計原則

パラメータを最小化する。「追従モード（CHARGE/HOLD/FOLLOW）」1フィールドのみで陣形の深みを出す。

削除した候補パラメータとその理由:
- 「追い越し可否」→ CHARGE/FOLLOW の2値で表現可能（統合）
- 「目標優先度」→ 既存 target_priority で制御済み（重複）
- 「集結点内での立ち位置」→ 六角展開の自然な秩序に任せる（実装コスト高・効果低）

### 1.2 formation_mode 仕様

```gdscript
# EconBuilding.gd に追加するフィールド
enum FormationMode {
    CHARGE = 0,  # 前方に向かって前進する。前にいる味方を追い越す（デフォルト）
    HOLD   = 1,  # 集結点周辺に留まり、近づく敵を迎え撃つ
    FOLLOW = 2,  # 前に HOLD ユニットがいれば射程距離を維持。いなければ CHARGE と同様
}
var formation_mode: int = FormationMode.CHARGE
```

### 1.3 各モードの行動仕様

#### CHARGE（突撃）

- 最短経路で敵に前進する（現行動作・変更なし）
- デフォルトモード
- 前にいる味方ユニットを回り込んで追い越す

#### HOLD（守備）

- 突撃指示後も集結点から N マス（N=3 固定）以内にとどまる
- N マス以内に敵が入ってきた場合は通常攻撃AIで応戦
- N マス以内に敵がいない場合は集結点近辺を巡回（または静止）
- 敵BASE攻撃は行わない（N マス以内に敵がいないとき）

#### FOLLOW（追従）

- 自分より前方に HOLD モードのユニットが1体以上存在する間は、
  最も近い HOLD ユニットの位置から（自分の attack_range - 1）マス後方を目標位置として移動する
- HOLD ユニットが存在しない場合は CHARGE と同様に動作する
- 「守が盾・崩が後方射撃」という陣形を自然に実現する

### 1.4 陣形設定のタイミング

建物設置時（UI: 建物設置後に右クリック → 陣形選択メニュー）。

理由:
- バトル前に設計が完結する（「設計して観戦する」体験と整合）
- バトル中の変更は操作コストが高く KISS 違反
- 旗設置時だと「旗ごとに異なる陣形」が生まれ複雑化する

### 1.5 種別ごとのデフォルト陣形

| 建物（生産するユニット種別） | デフォルト陣形 | 推奨理由 |
|--------------------------|--------------|---------|
| 兵舎（突） | CHARGE | 突撃が本来の役割 |
| 要塞（守） | HOLD | 守備が本来の役割 |
| 工房（崩） | FOLLOW | 守の盾の後ろから射撃するのが最も強い |

### 1.6 戦術コンボ例

| 設定 | 効果 |
|------|------|
| 要塞(HOLD) + 工房(FOLLOW) | 守が盾・崩が後方爆撃 → 崩が前に出て自爆せず継続射撃できる |
| 全兵舎(CHARGE) | 全員突撃（現行と同じ） |
| 要塞(HOLD) + 兵舎(CHARGE) | 守が前線維持・突撃が守の横を抜けて侵入 |
| 兵舎(CHARGE) + 工房(FOLLOW) | 突が先行・崩が距離を保って追随 |

---

## 2. 実装仕様（陣形システム）

### 2.1 データ構造の変更

```gdscript
# EconBuilding.gd へ追加
enum FormationMode { CHARGE = 0, HOLD = 1, FOLLOW = 2 }
var formation_mode: int = FormationMode.CHARGE
```

### 2.2 ユニットへの継承

```gdscript
# EconBuilding.gd の _spawn_unit() 内
var u: EconUnit = ...
u.formation_mode = formation_mode   # 建物の設定をユニットに継承
```

```gdscript
# EconUnit.gd へ追加
var formation_mode: int = 0  # FormationMode.CHARGE がデフォルト
```

### 2.3 EconUnit.gd の update() 変更

```gdscript
# 突撃指示後の移動ロジック（is_idle = false になった後）
# 既存の _try_move_toward() 呼び出し前に以下を挿入

if formation_mode == 1:  # HOLD
    var dist_to_rally: int = grid.hex_distance(grid_pos, rally_point)
    if dist_to_rally > HOLD_RADIUS:  # HOLD_RADIUS = 3
        _try_move_toward(delta, grid, all_units, rally_point)
    return   # HOLD は rally_point 周辺でのみ戦闘

elif formation_mode == 2:  # FOLLOW
    var hold_units: Array = []
    for u in all_units:
        if u.get("is_alive") == null or not u.is_alive: continue
        if u.get("side") == null or u.side != side: continue
        if u.get("formation_mode") == null or u.formation_mode != 1: continue
        if u.get("is_idle") != null and u.is_idle: continue
        hold_units.append(u)
    if hold_units.size() > 0:
        # 最も近い HOLD ユニットを探す
        var nearest_hold: Node = null
        var nearest_d: int = 999999
        for hu in hold_units:
            var d: int = grid.hex_distance(grid_pos, hu.grid_pos)
            if d < nearest_d:
                nearest_d = d
                nearest_hold = hu
        # HOLD ユニットの後方 (attack_range - 1) マスを目標にする
        var follow_range: int = maxi(1, attack_range - 1)
        if nearest_hold != null and nearest_d > follow_range:
            _try_move_toward(delta, grid, all_units, nearest_hold.grid_pos)
        return   # FOLLOW は HOLD の後ろで待機
    # HOLD ユニットがいなければ CHARGE と同じ動作（フォールスルー）
```

定数: `const HOLD_RADIUS: int = 3`（EconUnit.gd に追加）

---

## 3. Priority AIパターン拡張

### 3.1 現行実装（変更前）

```gdscript
# EconUnit.gd の prio_table（現行）
var prio_table: Array = [
    [0, 1, 2, 3],  # 0: 標準       BASE > 建物 > ユニット > 非戦闘
    [2, 1, 0, 3],  # 1: 前線制圧   ユニット > 建物 > BASE > 非戦闘
    [1, 0, 2, 3],  # 2: 経済破壊   建物 > BASE > ユニット > 非戦闘
]
```

prio_table の列の定義: [BASE, 建物, ユニット, 非戦闘]（小さいほど優先）

### 3.2 追加パターン（変更後）

```gdscript
# EconUnit.gd の prio_table（拡張後）
var prio_table: Array = [
    [0, 1, 2, 3],  # 0: 標準       BASE > 建物 > ユニット > 非戦闘（変更なし）
    [2, 1, 0, 3],  # 1: 前線制圧   ユニット > 建物 > BASE > 非戦闘（変更なし）
    [1, 0, 2, 3],  # 2: 経済破壊   建物 > BASE > ユニット > 非戦闘（変更なし）
    [2, 1, 3, 0],  # 3: 略奪       非戦闘（ハーベスター）> 建物 > ユニット > BASE
    [3, 0, 1, 2],  # 4: 突破口     建物 > ユニット > 非戦闘 > BASE（BASEは最後）
    [3, 2, 0, 1],  # 5: 殲滅       ユニット > 非戦闘 > 建物 > BASE（BASEは最後）
]
```

### 3.3 追加パターンの説明

| # | パターン名 | 一行説明 | 推奨ユニット種別 |
|---|-----------|---------|----------------|
| 3 | 略奪 | ハーベスター（非戦闘）を最優先で狩り、敵経済を止める | 崩（爆発範囲で複数同時撃破） |
| 4 | 突破口 | 建物を壊して前進路を確保し、BASEは後回し | 突（高移動速度で建物を踏み荒らしながら侵入） |
| 5 | 殲滅 | 敵ユニットを全滅させてから拠点を攻める | 守（高HP・引き付け）+ 崩（殲滅） |

### 3.4 戦術コンボ（陣形との組み合わせ）

| 陣形 × Priority AI | 戦術効果 |
|-------------------|---------|
| 工房(FOLLOW) × 略奪(3) | 崩が守の後ろに隠れながらハーベスターを狙い撃ち → 敵経済を破壊しつつ自分が生き残る |
| 兵舎(CHARGE) × 突破口(4) | 突が建物を破壊しながら前進 → 後続ユニットの侵入路を確保 |
| 要塞(HOLD) × 殲滅(5) | 守が全ユニットを引きつけてゼロにしてから BASE 攻撃 |

### 3.5 target_priority フィールドの変更

```gdscript
# EconUnit.gd（変更前）
var target_priority: int = 0  # 0=標準, 1=前線制圧, 2=経済破壊

# EconUnit.gd（変更後）
var target_priority: int = 0  # 0=標準, 1=前線制圧, 2=経済破壊, 3=略奪, 4=突破口, 5=殲滅
```

clamp 変更（変更前 `clampi(target_priority, 0, 2)` → 変更後 `clampi(target_priority, 0, 5)`）:

```gdscript
var prios: Array = prio_table[clampi(target_priority, 0, 5)]
```

### 3.6 建物への target_priority 追加

```gdscript
# EconBuilding.gd へ追加（formation_mode と同様に建物設置時に設定）
var unit_target_priority: int = 0  # 生産するユニットに継承
```

---

## 4. 実装対象ファイル

| ファイル | 変更内容 | 変更種別 |
|---------|---------|---------|
| scripts/econ_mvp/EconUnit.gd | formation_mode フィールド追加・HOLD/FOLLOW ロジック追加 | 修正 |
| scripts/econ_mvp/EconUnit.gd | prio_table を 3行→6行に拡張・clamp 変更 | 修正 |
| scripts/econ_mvp/EconBuilding.gd | formation_mode・unit_target_priority フィールド追加 | 修正 |
| scripts/econ_mvp/EconBuilding.gd | _spawn_unit() で formation_mode・target_priority を継承 | 修正 |

---

## 5. 制約・注意事項

- EconUnit.gd の update() 内の移動ロジック変更は既存の ATTACK_HARVESTERS / GUARD モードと干渉しないこと
- FOLLOW モードは HOLD ユニットが存在する場合のみ動作。存在しない場合は CHARGE にフォールスルー
- prio_table の拡張は clamp の上限変更のみ。既存の 0/1/2 のパターンは変更しない
- 疎結合ルール（CLAUDE.md 準拠）: EconBuilding から EconUnit への値渡しはスポーン時の直接代入のみ（生産時は値渡しなので疎結合ルール対象外）

---

## 6. 完了定義

- [ ] 建物に formation_mode フィールドが追加されている
- [ ] 建物設置後の右クリックメニューで陣形を選択できる
- [ ] 要塞(HOLD) + 工房(FOLLOW) の組み合わせで、崩が守の後方に留まって射撃する
- [ ] prio_table が 6パターンに拡張されている
- [ ] 略奪(3) で ハーベスターを優先攻撃する
- [ ] 突破口(4) で 建物を優先的に破壊して前進する
- [ ] 殲滅(5) で ユニット全滅後に BASE を攻撃する
- [ ] check_syntax.sh が通る
- [ ] CEO承認済み
