# 要件定義書: ハーベスター採取範囲制限・農村配置制限なし・生産速度修正

更新日: 2026-05-01
STATUS: 確定

---

## 0. 関連企画書

- `docs/design/econ_building_system.md` §16（ハーベスター採取範囲制限）
- `docs/design/econ_building_system.md` §17（農村配置制限なし）
- `docs/design/econ_building_system.md` §18（生産速度仕様）

---

## 1. 変更1: ハーベスター採取範囲制限

### 企画書引用（§16）

> ハーベスターは「自分の建物の半径3マス以内」にある資源タイルのみ採取できる。
> 候補タイルを `grid.hex_distance(tile_pos, b.grid_pos) <= 3` で全プレイヤー建物に対してチェック。
> 1つでも条件を満たす建物があるタイルのみ採取対象とする。

### 実装仕様

**対象ファイル**: `scripts/econ_mvp/EconHarvester.gd`

**変更関数**: `_try_move_with_villages()` および `_try_move()`

**ロジック**:
1. `targets` 配列（採取候補タイル）を絞り込む
2. 各候補タイル `t` について、`buildings` 配列の全建物 `b` に対し `grid.hex_distance(t, b.grid_pos) <= 3` をチェック
3. 1棟でも条件を満たす建物があるタイルのみ `filtered_targets` に残す
4. `filtered_targets` が空の場合は移動しない（ターゲットなし）

**buildings 配列の渡し方**:
- `_try_move_with_villages()` はすでに `buildings` を引数として受け取っていない
- `update()` から呼び出し時に `buildings` を渡すよう引数追加が必要
- `_try_move()` も同様

**注意**: ハーベスター側では `is_player_side` の判定は不要。EconBattle.gd がプレイヤー側ハーベスターにはプレイヤー側建物のみ、敵側ハーベスターには敵側建物のみを渡す想定で、`buildings` 引数がすでに「自分側の建物のみ」である前提で実装する。

---

## 2. 変更2: 農村配置制限なし

### 企画書引用（§17）

> 農村（VILLAGE）はプレイヤーエリア（col 0〜7）内であればどこでも配置可能。
> 特別な配置制限は設けない（EconMain.gd に農村固有の制限がある場合は削除する）。

### 実装仕様

**対象ファイル**: `scripts/econ_mvp/EconMain.gd`

**変更内容**:
- `_place_building()` 内に農村（VILLAGE）固有の配置制限コードが存在する場合、削除する
- 農村は他の建物と同様に col 0〜7 の範囲内で自由に配置できる
- 農村固有の制限が存在しない場合は変更不要（確認のみ）

---

## 3. 変更3: 生産速度修正

### 企画書引用（§18）

> 農村または鉱山隣接ボーナスあり: 5秒（`BARRACKS_PRODUCE_INTERVAL / 2.0` ではなくハードコード値 `5.0` を使用）。

### 実装仕様

**対象ファイル**: `scripts/econ_mvp/EconBuilding.gd`

**変更箇所**:

| 関数 | 変更前 | 変更後 |
|------|--------|--------|
| `_update_barracks` | `BARRACKS_PRODUCE_INTERVAL / 2.0 if _placement_bonus_active else BARRACKS_PRODUCE_INTERVAL` | `5.0 if _placement_bonus_active else BARRACKS_PRODUCE_INTERVAL` |
| `_update_fortress` | `FORTRESS_PRODUCE_INTERVAL / 2.0 if _placement_bonus_active else FORTRESS_PRODUCE_INTERVAL` | `5.0 if _placement_bonus_active else FORTRESS_PRODUCE_INTERVAL` |
| `_update_workshop` | `WORKSHOP_PRODUCE_INTERVAL / 2.0 if _placement_bonus_active else WORKSHOP_PRODUCE_INTERVAL` | `5.0 if _placement_bonus_active else WORKSHOP_PRODUCE_INTERVAL` |

**理由**: `BARRACKS_PRODUCE_INTERVAL = 20.0` なので `/ 2.0` は `10.0` になるが、正しい仕様は `5.0`。

---

## 4. 完了定義（Checker チェックリスト）

- [ ] `EconHarvester.gd` の `_try_move_with_villages()` でターゲットが建物半径3マス以内に制限されている
- [ ] `EconHarvester.gd` の `_try_move()` でターゲットが建物半径3マス以内に制限されている
- [ ] buildings が空の場合（全建物消滅時）はターゲットなしになる
- [ ] `EconBuilding.gd` の `_update_barracks` でボーナス時 interval が `5.0`
- [ ] `EconBuilding.gd` の `_update_fortress` でボーナス時 interval が `5.0`
- [ ] `EconBuilding.gd` の `_update_workshop` でボーナス時 interval が `5.0`
- [ ] `EconMain.gd` に農村固有の配置制限がないことを確認（あれば削除済み）
- [ ] `check_syntax.sh` エラー0件

---

## 5. 対象外（変更しない）

- EconBuilding.gd のコスト半減ロジック（ `ceili(cost / 2.0)` ）はそのまま維持
- ハーベスターの採取ボーナス計算（SAWMILL/MINE隣接ボーナス）はそのまま維持
- 逃走ロジック（`_flee_move`）は範囲制限の対象外
- 建設モード（ROLE_BUILD）は範囲制限の対象外
