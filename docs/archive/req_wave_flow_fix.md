# req_wave_flow_fix.md — Wave進行フロー修正要件定義書

作成日: 2026-04-24
ステータス: 実装待ち
担当Architect: claude-sonnet-4-6

---

## 1. 問題整理

| # | 問題 | 箇所 | 症状 |
|---|------|------|------|
| 1 | `WaveState.COMBAT` 参照バグ | `Main.gd L622` | WaveManager経由の勝利処理が一切呼ばれない（条件が永遠にfalse） |
| 2 | ボスWave判定が小Wave番号依存 | `WaveManager.gd` 定数 `BOSS_WAVE_PHASE1=3`, `BOSS_WAVE_PHASE2=4` | BW1のSW3でもボス扱いになる。BW4のSW1/SW2でボスにすべき |
| 3 | `_advance_to_next_wave` の進行フロー不整合 | `WaveManager.gd` `SHOP_TRIGGER_WAVES=[2,4,6]` | 累積小Wave番号で判定。各BW内でSW2後にショップという設計意図と不整合 |
| 4 | `boss_id` 密結合 | `WaveManager.gd` `_build_enemy_for_wave()` | `GameSession.boss_id` を直接参照。WaveManagerがbossのID解決責任まで持っている |

---

## 2. 修正後の設計（Wave進行フロー）

### 2-1. BW1〜BW3（通常ビッグウェーブ）

```
BW_N開始
  └─ SW1（通常戦）
       └─ クリア → SW2（通常戦）
                    └─ クリア → ショップ（intermission_requested emit）
                                  └─ resume_from_intermission → BW_{N+1}開始
```

- **小Wave番号（_current_small）はBW移行時に1にリセットする**
- ショップ後の再開で `_current_small = 1` から新BW開始
- `SHOP_TRIGGER_WAVES` は廃止。代わりに「SW2クリアかつBW4未満」でショップを発火する

### 2-2. BW4（ボスビッグウェーブ）

```
BW4開始
  └─ SW1（ボスPhase1）
       └─ クリア → SW2（ボスPhase2）
                    └─ クリア → ゲームクリア（big_wave_completed emit）
```

- BW4開始時（`_start_wave(4, 1)` 呼び出し前）: `GameSession.boss_phase = 1`
- BW4-SW1クリア後（`_advance_to_next_wave` でSW2へ進む前）: `GameSession.boss_phase = 2`
- ボスWave判定は **`_current_big == TOTAL_BIG_WAVES`（=4）かつ通常戦状態** で行う
- `BOSS_WAVE_PHASE1` / `BOSS_WAVE_PHASE2` 定数は廃止する

### 2-3. 状態遷移表

| BW | SW | WaveState | 処理 |
|----|----|-----------|------|
| 1 | 1 | SMALL_WAVE | 通常戦 |
| 1 | 2 | SMALL_WAVE | 通常戦 → クリアでショップ |
| 2 | 1 | SMALL_WAVE | 通常戦 |
| 2 | 2 | SMALL_WAVE | 通常戦 → クリアでショップ |
| 3 | 1 | SMALL_WAVE | 通常戦 |
| 3 | 2 | SMALL_WAVE | 通常戦 → クリアでショップ |
| 4 | 1 | BOSS_PHASE1 | ボスPhase1戦 |
| 4 | 2 | BOSS_PHASE2 | ボスPhase2戦 → クリアでゲームクリア |

---

## 3. boss_id疎結合設計

### 3-1. 案比較

| 案 | 方法 | WaveManagerの知識 | 採用可否 |
|----|------|------------------|---------|
| 案1（シグナル） | `boss_wave_reached(bw_index)` をemit、Main.gdがlistenしてboss_idをセット | bossが何かを知らない | **採用** |
| 案2（Callable注入） | `boss_resolver: Callable` を外部セット | Callableの存在は知っている | 可だが案1と同等。GDScriptの慣習から外れる |
| 案3（データドリブン） | wave_configやcards.jsonにboss_idをwave定義として持つ | データファイルのスキーマに依存する | 新ファイル導入が必要で足し算になる |

### 3-2. 採用案: 案1（シグナル）

**採用理由:**
- Main.gdはすでに4本のWaveManagerシグナルをlistenしている（既存パターンと一貫性）
- WaveManagerが新たなデータファイルやCallableを知る必要がない
- boss_id解決ロジックをMain.gdに集約でき、責任が明確

### 3-3. 追加シグナル仕様

```gdscript
# WaveManager.gd に追加
signal boss_wave_reached(bw_index: int)
```

- **emit タイミング**: `_start_wave(4, 1)` を呼ぶ直前（BW4突入時）
- **引数**: `bw_index` = 4（将来の拡張余地として渡す）
- **WaveManagerはこのシグナルを発火するだけ。boss_idは参照しない**

### 3-4. boss_id解決ロジックの責任者: Main.gd

Main.gdが `boss_wave_reached` を受信し、以下を実行する:

```
受信 boss_wave_reached(bw_index)
  └─ GameSession.race_theme からboss_idを解決（cards.jsonのbossesを参照）
       例: race_theme="beast" かつ act=1 → boss_id="boss_beast_king"
  └─ GameSession.boss_id = 解決したboss_id
  └─ GameSession.boss_phase = 1
```

解決ロジックの実装先: `Main.gd` の新関数 `_on_boss_wave_reached(bw_index: int)`

---

## 4. 修正対象ファイルと変更箇所

### scripts/WaveManager.gd

| 変更箇所 | 変更内容 |
|---------|---------|
| シグナル定義（L7〜10付近） | `signal boss_wave_reached(bw_index: int)` を追加 |
| 定数（L14〜15） | `BOSS_WAVE_PHASE1 = 3`, `BOSS_WAVE_PHASE2 = 4` を削除 |
| 定数（L18） | `SHOP_TRIGGER_WAVES` を削除 |
| `_start_wave()` | ボスWave判定を `_current_big == TOTAL_BIG_WAVES` に変更。BW4-SW1のときboss_wave_reached.emit(4)を発火 |
| `_advance_to_next_wave()` | SHOP_TRIGGER_WAVES依存を削除。「SW2クリアかつBW4未満」でショップ発火に変更。BW4-SW1クリア時にboss_phase=2をセット |
| `_build_enemy_for_wave()` | `GameSession.boss_id` の直接参照を削除。`_current_big == TOTAL_BIG_WAVES` でbattle_type="boss"にセットするだけにする |

### scripts/Main.gd

| 変更箇所 | 変更内容 |
|---------|---------|
| L622 | `wave_manager.WaveState.COMBAT` を `wave_manager.WaveState.SMALL_WAVE` に修正 |
| WaveManager初期化箇所（L123〜126付近） | `wave_manager.boss_wave_reached.connect(_on_boss_wave_reached)` を追加 |
| 新関数追加 | `_on_boss_wave_reached(bw_index: int)` を追加（boss_id解決ロジック） |

---

## 5. 受け入れ基準

- [ ] BW1→BW2→BW3→BW4の順に8戦（各BW=SW×2）進行する
- [ ] BW4がボスバトルになる（WaveState.BOSS_PHASE1/BOSS_PHASE2が正しくセットされる）
- [ ] WaveManagerがGameSession.boss_idに直接依存しない
- [ ] Main.gdのWaveState.COMBAT参照がなくなる
- [ ] check_syntax.sh エラー0件

