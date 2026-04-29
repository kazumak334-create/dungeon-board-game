# ADR-001: EconBattle へのスポーン・登録処理一元化

**ステータス:** 採択  
**日付:** 2026-04-29  
**対象:** scripts/econ_mvp/

---

## 背景

EconAI と EconMain が `_battle.enemy_units.append()` 等を直接呼び出しており、
EconBattle の内部状態が複数クラスから変更されていた（疎結合度 C）。

## 決定

EconBattle にユニット・建物・ハーベスターの生成・登録メソッドを一元化する。

| メソッド | 責務 |
|---------|------|
| `spawn_enemy_unit(utype, pos)` | 敵ユニット生成 + enemy_units 管理 |
| `spawn_enemy_harvester(pos, economy)` | 敵ハーベスター生成 + enemy_harvesters 管理 |
| `register_enemy_building(b)` | 敵建物を enemy_buildings に登録 + _grid に追加 |
| `spawn_player_harvester(pos, economy)` | プレイヤーハーベスター生成 + player_harvesters 管理 |
| `register_player_building(b)` | プレイヤー建物を player_buildings に登録 + _grid に追加 |

**外部クラスからの直接配列操作は禁止。**

## 代替案（却下）

- 各クラスが配列を持つ分散管理: 責任の所在が曖昧になるため却下

## 見直しタイミング

- EconBattle を複数の責務に分割する場合（例: SpawnManager 分離）
- マルチプレイヤー対応でユニット管理が変わる場合

## 関連

- `check_syntax.sh` coupling lint（施策1）でリグレッションを自動検出
