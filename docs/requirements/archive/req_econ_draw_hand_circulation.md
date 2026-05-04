STATUS: 廃止（→ 対応する REQUIREMENTS_SPRINT_{N}.md を参照）

# Econ MVP v0.2 ドロー・手札循環 要件定義書

**更新日:** 2026-05-02（改訂3：v0.2 再ハンドオフ／ハーベスター廃止・ステータス拡張・カード配置即時消費・兵力蓄積式・UI大改造）
**ステータス:** **実装着手可（v0.2 スコープ）**
**対象:** Econ MVP v0.2（対AI）／scripts/econ_mvp/
**関連:**
- `docs/requirements/req_economy_mvp.md`（1バトル詳細仕様の上位ドキュメント）
- `docs/design/enterprise_draw_design_mvp.md`（Planning 出力／**改訂2 v0.2 仕様 SSOT**）
- `docs/design/ui_draw_hand_gauge_specification.md`（Designer 出力／v0.1 仕様・v0.2 部分は本書 §5 で先行定義）
- `docs/meta/adr/001_econ_spawn_centralized.md`（EconBattle 一元化規約）

---

## 修正履歴

| 日付 | 版 | 修正内容 | 修正者 |
|------|----|---------|------|
| 2026-05-02 | v0.1（初版） | 13枚デッキ・並存システム反映（Designer UI仕様確定後の最終化） | Architect |
| 2026-05-02 | v0.2（最終版） | 矛盾検出レポート反映：§4.3 ドロー保留挙動の自己矛盾解消／§5.3.2 手札6状態フロー追加／§4.6 並存システムマトリクス追加／§7.4 人口上限計算式根拠／§8.5 住居破壊時停止アルゴリズム／§9.5 山札枯渇シナリオ／§11 初期カード仕様完全化 | Architect |
| **2026-05-02** | **v0.3（改訂3／v0.2 再ハンドオフ）** | **企画書改訂2に基づく v0.2 大改造を反映：<br>1) ハーベスター廃止（左側リソース配置UI削除・関連クラス削除）<br>2) BUILD区廃止（手札→盤面ドロップで即時資源消費）<br>3) 兵舎を兵力蓄積式へ（+0.2/秒仮、突撃時1:1ユニット化）<br>4) ステータスフィールド拡張（population_cap=50 拠点効果／military_power／currency=100／food=30／satisfaction=0／initial resources=各5）<br>5) 手札MAX 5→8枚（横スクロール対応）<br>6) HEADER 拡張（人口・満足度・兵力・資金・各資源・ゲージ集約）<br>7) イベント選択区プレースホルダー（v0.3 開放）<br>8) スコープを v0.1 / v0.2 に明示分離<br>9) §13 廃止クラス・関数のリスト追加<br>10) §14 v0.2 向け実装開始前チェックリスト再構成<br>11) §16 確定事項・v0.2 繰越項目を分離** | **Architect** |

---

## 1. 背景・目的

### 1.1 目的

Econ MVP の戦闘・経済ループに「カード循環（デッキ→手札→盤面 / 除外）」と「ターン進行」の概念を導入し、
プレイヤーの介入リズム（30秒ごとの判断＋強制突撃という時間圧）を作る。

これは「**盤面を設計して、介入を仕込んで、答え合わせを観戦する**」核体験のうち、
「盤面を設計する」フェーズの**リズム**を明確化するための実装である。

### 1.2 v0.2 改訂2 への移行理由

旧 v0.1 の以下4点を改訂2で再設計した：

1. **ハーベスター割り当て UI** → 採取建物の自動稼働で代替（操作ステップ削減）
2. **BUILD区（建設待機列）** → 手札→盤面ドロップ即時消費（操作ステップ削減）
3. **兵舎によるユニット直接生産** → 兵力プール式（「ためて、いつ放つか」の戦略軸）
4. **左側リソース配置 UI** → 廃止し HEADER に集約（視線移動最小化）

これらの変更は「**シンプルなルールの掛け合わせで深さを出す**」設計原則（CLAUDE.md）に沿った引き算である。

### 1.3 KISS 適用方針

- 既存リソース（Wood/Stone/Sulfur/Wheat/Iron/Cotton）と通貨・食料・人口・兵力で完結
- 満足度は v0.2 では初期値0のみ・実装は v0.3 へ繰越
- カードは「建設指示の発行手段」として導入する（新規システムを増やさない）
- v0.2 で実装するのはドロー・手札・ターン進行＋ステータス基盤の**最小骨格**のみ

---

## 2. スコープ

### 2.1 v0.2（本要件定義書の実装対象）

| カテゴリ | 実装内容 |
|---------|---------|
| 初期デッキ | **13枚固定**（資源採取建物6種×1 + 住居3 + 書庫1 + 市場1 + 兵舎2） |
| ターン進行 | 1ターン = 30秒、最大10ターン |
| ドロー | 30秒経過 or ドローゲージ満タンで1枚ドロー |
| 手札 | 上限8枚（**横スクロール対応**）。上限到達時はドロー保留 |
| 山札・捨て札・除外 | 4エリア管理（deck / hand / discard / excluded） |
| **カード配置メカニクス** | **手札→盤面D&D で即時資源消費**（BUILD区廃止） |
| **配置済みカード** | **excluded へ移動**（除外） |
| 書庫 | 通貨1で1ドロー（クールダウン5秒） |
| 強制突撃 | 10ターン目ドロー直後に発動／任意タイミング早期突撃可（旗倒しと**並存**） |
| **ステータス基盤** | **population / population_cap / satisfaction / military_power / currency / food / resources** |
| **拠点効果** | **population_cap +50 常駐** |
| **兵舎メカニクス** | **稼働中 +0.2/秒 兵力蓄積／突撃時 1:1 ユニット化** |
| 人口システム | 住居×3 で人口上限を供給（v0.2 では実人口運用なし） |
| **食料システム** | 初期30、人口×N/秒消費（v0.2 では人口がほぼ0のため実害なし） |
| **満足度** | **初期値0のみ・表示のみ**（v0.3 で具体化） |
| UI | **HEADER 拡張（ステータス集約）／FOOTER 手札8枚スクロール／デッキ・捨て札・除外表示／イベント選択区プレースホルダー** |

### 2.2 v0.3 以降に繰越（本要件定義書では実装しない）

| 範囲 | 理由 |
|------|------|
| 満足度システムの具体化 | v0.2 では初期値0のみ・表示のみ |
| 実人口運用（実際の人口数の変動） | v0.2 では人口=0 固定。住居は上限拡張のみ |
| 駐屯地（ユニット出現位置の多様化） | v0.2 では兵舎セルから一律出現 |
| イベント選択区機能 | v0.2 ではロックUI のみ表示 |
| デッキ圧縮（除外/破棄選択） | 戦略レイヤー。v0.2 では建設＝除外固定 |
| ドローエンジン拡張（ドロー+1 系カード） | 書庫1種で挙動検証する |
| マリガン・初手調整 | v0.2 では初期手札0枚固定 |
| 捨て札からのリシャッフル | v0.2 ではデッキ枯渇時「ドロー無効」 |
| カード効果のテキストエンジン化 | v0.2 では建物カードの効果は既存の「建物配置」のみ |

---

## 3. 用語定義

| 用語 | 定義 |
|------|------|
| デッキ（山札） | これからドローされる未公開カードの集合 |
| 手札 | プレイヤーが現在使用可能なカードの集合（**上限8枚・スクロール対応**） |
| 捨て札 | 使用後・効果消化後のカードの一時置き場（v0.2 では未使用想定） |
| 除外 | 二度と山札に戻らないカードの置き場（**カード配置成功後はここ**） |
| ドロー | デッキから1枚を手札に移す行為 |
| ドローゲージ | 次のドローまでの時間進捗（30秒で満タン） |
| 強制突撃ゲージ | バトル全体の経過ターンを示すゲージ（10ターンで満タン→突撃発動） |
| ターン | 30秒の時間単位。バトル全体は最大10ターン |
| 書庫 | 通貨1を消費してドロー1枚を引く特殊建物（クールダウン5秒） |
| 早期突撃 | プレイヤー任意タイミングで発動する一斉突撃（10ターン待たずに開始） |
| **兵力（military_power）** | **兵舎が稼働中に蓄積する float 値。突撃時に整数部分が同数のユニットに変換される** |
| **資金（currency）** | **書庫の通貨と同義。市場で生産・書庫で消費** |
| **拠点効果** | **拠点（BASE）が破壊されない限り常駐する population_cap +50** |

---

## 4. ゲームロジック要件

### 4.0 v0.2 の経済サイクル全体像

v0.2 ではハーベスター割り当てを廃止し、配置済みの採取建物・生産建物が**自動稼働で資源を生み出す**。プレイヤーの介入は「**何を建てるか・どこに建てるか・いつ突撃するか**」の3点に集約される。

```
[手札カード] ─D&D─→ [配置可否チェック] ─OK─→ [資源即時消費＋盤面建物生成]
                          │ NG                          │
                          └ 不可演出（手札に戻る）       ↓
                                          [建物自動稼働]
                                              │
            ┌─────────────────────────────────┼─────────────────────────────┐
            │                                  │                              │
            ↓                                  ↓                              ↓
       [採取建物]                        [生産・支援]                    [兵舎]
       資源6種 +N/秒                     ・住居：population_cap +3       military_power +0.2/秒（仮）
                                          ・書庫：currency-1 → drawcard       │
                                          ・市場：currency +1/10秒（仮）       ↓
                                                                         [突撃時 1:1 ユニット化]
```

### 4.1 ターン進行

| 項目 | 仕様 | 確定/要確認 |
|------|------|-----------|
| 1ターン長 | 30.0秒（定数 `TURN_DURATION_SEC`） | MVP内チューニング |
| 最大ターン数 | 10ターン（定数 `MAX_TURNS`） | MVP内チューニング |
| ターン番号 | 1〜10（1始まり） | 確定 |
| ターン経過のトリガー | `current_turn = int(battle_elapsed_sec / TURN_DURATION_SEC) + 1`（累積タイマー方式） | 確定 |

**実装注意:**
- ターン進行はバトル開始時刻からの累積時間で判定し、フレームスキップ耐性を持たせる
- ターンとドローは**同期**する（§4.2 参照）

### 4.2 ドロー発動タイミング

| 系統 | トリガー | 効果 |
|------|---------|------|
| 基本ドロー | ターン進行（30秒経過） | 山札先頭から1枚を手札に追加 |
| 書庫ドロー | プレイヤーが書庫アイコン押下＋通貨1を支払う | 山札先頭から1枚を手札に追加（CD5秒） |

**初期手札:** **0枚**（バトル開始0秒から30秒後に第1ドロー）

### 4.3 手札上限とドロー保留

**確定方針:** ターン進行はドロー保留と完全に独立。`current_turn` は `battle_elapsed_sec` から算出するため、ドローが保留されても止まらない。

| 項目 | 仕様 |
|------|------|
| **手札上限** | **8枚**（定数 `HAND_MAX_SIZE = 8`） |
| 上限到達時のドロー | **保留**（`pending_draws++`／カードはデッキ先頭に残る） |
| 保留の解除 | 手札 ≤ 7 になった次フレームで `pending_draws` を1つ消化 |
| ドローゲージへの影響 | 満タンで一時停止（手札MAX中はゲージは100%表示で待機） |
| **ターン進行への影響** | **影響なし**（`current_turn` は独立算出） |
| **強制突撃ゲージへの影響** | **影響なし**（ターン進行で進む） |
| 次ターンドロー要求 | 手札MAXのままなら `pending_draws++`（**スタック型**で積み上がる） |

**実装メソッド対応:**
- `draw_card()`: 手札MAX なら `pending_draws += 1` して即 return（draw_gauge_value は 30.0 のまま停止）
- `try_resolve_pending_draws()`: 毎フレーム呼出。`pending_draws > 0 && hand.size() < HAND_MAX_SIZE` なら1枚消化＋ `draw_gauge_value = 0.0`
- `update(delta)`: `battle_elapsed_sec += delta`、`current_turn = int(battle_elapsed_sec / TURN_DURATION_SEC) + 1`

### 4.4 カード配置メカニクス（v0.2 改訂・BUILD区廃止）

v0.1 では「手札→BUILD区→盤面」の3段階だったが、改訂2で**BUILD区を廃止**して以下に簡略化する。

#### 4.4.1 配置フロー

```
[手札カード] ─D&D開始─→ [盤面ホバー] ─資源/人口/配置先チェック─→ [配置確定]
                                                                  │
                                                                  ↓
                                                ① 建設コストを即時消費
                                                ② 手札からカード除外（excluded へ）
                                                ③ 盤面に建物オブジェクト生成・即稼働開始
```

#### 4.4.2 配置時チェック（4条件すべて満たすこと）

| # | 条件 | チェック対象 |
|---|------|------------|
| 1 | 資源充足 | `economy.resources` の各種資源 ≥ `card.cost` の各種資源 |
| 2 | 人口充足 | `economy.population_used + card.population_required ≤ economy.population_cap` |
| 3 | 配置先有効 | 対応タイル隣接（採取） or 自陣プレイエリア（住居・兵舎・書庫・市場） |
| 4 | 強制突撃前 | `force_charge_triggered == false` |

#### 4.4.3 配置成功時の処理

```gdscript
# EconBattle.play_card_and_build(card_idx, target_cell) 内
1. card = deck_manager.hand[card_idx]
2. if not _check_placement_valid(card, target_cell): return false
3. economy.consume_resources(card)             # ① 資源消費
4. deck_manager.exclude_card_at(card_idx)      # ② 除外
5. var building = _create_building_from_card(card, target_cell)
6. register_player_building(building)          # ③ 盤面登録（既存メソッド）
7. economy.population_used += card.population_required
8. if card.population_supply > 0: economy.population_cap += card.population_supply
9. return true
```

#### 4.4.4 配置失敗時の処理

- ドラッグ中、ホバーセルで資源・人口・配置先チェック実行
- 不足/不可ならカードに赤オーバーレイ＋盤面セルもグレーアウト
- ドロップしても何も起きない（手札に戻る・コスト消費なし）

#### 4.4.5 BUILD区廃止に伴う簡略化

- 旧UI：手札5枚 + BUILD区4列 + 盤面
- 新UI：**手札8枚（スクロール）+ 盤面（直接ドロップ）**
- 「建設中」プログレスバーは削除（盤面建物の出現アニメーションに統合）

### 4.5 山札・手札・捨て札・除外の状態遷移

```
[ 山札 (deck) ]
     ↓ ドロー（基本 or 書庫）
[ 手札 (hand) ]  ← 上限8枚
     ↓ 配置（D&D 成功・資源即時消費）
[ 除外 (excluded) ]   ← 配置成功時にここへ

[ 捨て札 (discard) ]  ← v0.2 では未使用（v0.3 以降に効果カードで使用）
```

| イベント | 状態変化 |
|---------|---------|
| ドロー | deck から先頭1枚 pop → hand に push |
| カードを盤面に配置（成功） | hand から該当カード remove → 盤面に建物配置→ 同時に excluded に push |
| デッキ枯渇 | ドロー要求が来ても hand には何も追加されない（ログのみ） |

**v0.2 確定方針:**
- 捨て札からのリシャッフル: **実装しない**（デッキ枯渇＝ドロー無効）
- 「配置成功 → 除外」を確定方針として採用（捨て札に積んで再利用は v0.3 以降）

### 4.6 強制突撃と並存システム

#### 4.6.1 強制突撃の発動条件

| 項目 | 仕様 |
|------|------|
| 発動条件A | ターン10のドロー実行直後に自動発動 |
| 発動条件B | プレイヤーが「早期突撃」ボタンを任意タイミングで押下 |
| 発動内容 | 全プレイヤーユニットの target_priority を「前線制圧」相当に上書き＋敵BASEに向けた強制前進フラグON＋**兵舎の兵力をユニット化**（§4.7 参照） |
| 発動後の操作 | 資源配分・ターゲット指示は引き続き可能。**ドロー・建設は停止** |

#### 4.6.2 並存システムの動作差マトリクス

| 動作 | 旗倒し単独 | 早期突撃 | 強制突撃ゲージ満タン |
|------|----------|---------|--------------------|
| 前進フラグ ON | ✓ | ✓ | ✓ |
| target_priority 上書き（→「前線制圧」） | ✗ | ✓ | ✓ |
| 旗倒しイベント連鎖発火 | -（自身がトリガー） | ✓ | ✓ |
| **兵力→ユニット化（1:1）** | **✗** | **✓** | **✓** |
| ドロー停止（基本＋書庫の両方） | ✗ | ✓ | ✓ |
| 建設停止（手札カードを disabled） | ✗ | ✓ | ✓ |
| 早期突撃ボタンの disabled 化 | ✗ | ✓（押下後） | ✓ |
| 発火元シグナル | `flag_charge_triggered`（既存） | `force_charge_triggered`（新規） | `force_charge_triggered` ＋ `flag_charge_triggered` 連鎖 |

**重要差分（v0.2 改訂2 で追加）:**
- 旗倒し単独：兵舎の兵力は**変換されない**（ユニットは出現しない）。前進フラグONのみ
- 早期突撃 / 強制突撃ゲージ満タン：兵力が即時ユニット化される（§4.7）

#### 4.6.3 UI 配置の分離

- 旗倒し: **盤面上の旗オブジェクト**を直接クリック（既存仕様維持）
- 早期突撃ボタン: **HEADER 右**（強制突撃ゲージのすぐ右隣）

### 4.7 兵舎・兵力・ユニット化フロー（v0.2 改訂2 新規）

#### 4.7.1 兵舎の役割再定義

| 項目 | v0.1（旧） | v0.2（改訂2） |
|------|-----------|--------------|
| 兵舎の役割 | 攻撃ユニットを直接生産（タイマーで盤面に出現） | **兵力プール**：稼働中に「兵力」を蓄積 |
| 兵舎稼働時の効果 | ユニット生産タイマーが進む | `military_power += 0.2 * delta`（基あたり仮値） |
| ユニット出現タイミング | 兵舎ごとのタイマー満了 | **突撃発動時**に兵力→ユニット変換（1:1） |

#### 4.7.2 兵力蓄積ロジック

```gdscript
# EconBattle.update(delta) または EconBuilding._update_barracks(delta)
for barracks in active_barracks:
    if barracks.is_active:  # 稼働中（人口OK）の兵舎のみ
        economy.military_power += BARRACKS_POWER_PER_SEC * delta
```

| 定数 | 値 | 備考 |
|------|-----|------|
| `BARRACKS_POWER_PER_SEC` | **0.2**（仮値） | テストプレイで微調整 |

**注:** 兵力は `EconEconomy.military_power: float` に蓄積する（兵舎個別ではなく総量で保持）。兵舎が複数あるときも合算で増加。

#### 4.7.3 兵力→ユニット変換ルール

```
変換タイミング：
  ① 早期突撃ボタン押下
  ② 強制突撃ゲージ満タン（ターン10自動）
  注：旗倒し単独では発動しない（§4.6.2）

変換式：
  生成ユニット数 = floor(economy.military_power)
  変換後の兵力 = economy.military_power - floor(economy.military_power)
              ≒ 0（小数部のみ残る）

変換場所：
  各兵舎セルから現出（複数兵舎があれば各セルから分散出現）
  分散ロジック：生成ユニット数を兵舎数で均等割り（端数は前から1ずつ）

ユニット種別：
  既存兵舎ユニット仕様（req_economy_mvp.md）に準拠
  ステータス・挙動は v0.1 兵舎ユニットと同一
```

#### 4.7.4 メソッドシグネチャ

```gdscript
# EconEconomy.gd
func accumulate_military_power(delta: float, active_barracks_count: int) -> void:
    military_power += BARRACKS_POWER_PER_SEC * active_barracks_count * delta

# EconBattle.gd
func unitize_military_power() -> int:
    var unit_count: int = int(floor(economy.military_power))
    economy.military_power -= float(unit_count)  # 小数部を残す
    if unit_count <= 0: return 0
    _spawn_units_from_barracks(unit_count)
    return unit_count
```

#### 4.7.5 具体例

```
ターン1〜5：兵舎×2 建設（各 +0.2/秒 × 2基 = +0.4/秒）
ターン5〜9：4ターン × 30秒 = 120秒 蓄積
  → military_power = 0.4 × 120 = 48.0
ターン9：早期突撃ボタン押下
  → unitize_military_power() 呼出
  → ユニット48体が兵舎セル2箇所から分散出現（各24体）
  → military_power = 0.0
```

### 4.8 ドロー保留時のターン進行

**ターン進行は常に30秒周期で独立して進む。**
ドロー受信は手札上限時に保留されるが、ターンカウントは停止しない。

| 項目 | 仕様 |
|------|------|
| ターン進行 | `battle_elapsed_sec` を delta 累積し、`current_turn = int(elapsed / 30) + 1` で独立算出 |
| ドロー保留 | 手札上限到達時、`pending_draws++` でスタック |
| 保留解決 | 手札 ≤ 7 になった次フレームで `pending_draws` を1つ消化 |
| ドローゲージ | 手札MAX中は100%表示で待機（次タイマーは進めない） |
| 強制突撃ゲージ | ドロー保留に**影響されず進む**（ターン進行に同期） |

---

## 5. 画面・UI 要件（v0.2 改訂・大改造）

**Single Source of Truth:** Designer 仕様書（`ui_draw_hand_gauge_specification.md`）は v0.1 仕様で記載されている。本要件定義書 §5 は **v0.2 改訂版企画書 §5.0** に基づき、Designer 仕様書を上書きする形で確定する。Designer は本要件定義書 §5 を v0.2 仕様の SSOT として再設計する。

### 5.0 全体レイアウト（基準解像度 1280×720）

```
┌─ HEADER (y=0, h=80) ─────────────────────────────────────────────────┐
│ [Pop N/M] [Sat N] [Mil N] [Cur NG]  [Draw■■■□]  [Force■■■□□□] [EARLY]│
│ [木 N] [石 N] [硫 N] [小 N] [鉄 N] [綿 N] [食 N]                    │
└────────────────────────────────────────────────────────────────────────┘
┌──────────────┬──────────────────────────────┬──────────────────┐
│              │                              │ [イベント選択区]   │
│  （旧ハー    │                              │  [LOCKED]         │
│   ベスター   │   盤面（プレイエリア）        │  v0.3 で開放      │
│   UI 跡 ／   │                              │                   │
│   空白 ／    │                              ├──────────────────┤
│   盤面拡張） │                              │ [Deck:N]          │
│              │                              │ [Discard:N]       │
│              │                              │ [Excluded:N]      │
└──────────────┴──────────────────────────────┴──────────────────┘
┌─ FOOTER (y=600, h=120) ──────────────────────────────────────────────┐
│ ◀ [Card1][Card2][Card3][Card4][Card5][Card6][Card7][Card8] ▶          │
└────────────────────────────────────────────────────────────────────────┘
```

**主要変更点（v0.1 → v0.2）:**

| UI要素 | v0.1（旧） | v0.2（改訂2） |
|--------|-----------|--------------|
| 手札MAX枚数 | 5枚（並列固定） | **8枚（横スクロール対応）** |
| デッキ・捨て札表示 | なし | **画面右下に Deck/Discard/Excluded を3行表示** |
| BUILD区 | 4列の建設待機列 | **廃止** |
| ハーベスター割り当て UI | 左側パネルに棒グラフ | **完全廃止** |
| 左側リソース配置 UI | ハーベスター割り当てを担う | **廃止**（左側エリアは盤面拡張または空白） |
| HEADER（画面上部） | リソース表示のみ・h=56 | **h=80 に拡張：人口・満足度・兵力・資金・各資源・両ゲージを集約** |
| イベント選択区 | なし | **プレースホルダー（ロック状態UI）**（v0.3 開放） |
| FOOTER 高さ | h=180 | **h=120**（手札のみ） |

### 5.1 HEADER ステータス表示（v0.2 新規）

#### 5.1.1 配置（左上から右へ）

| 要素 | 表示位置（仮） | 形式 | 表示例 |
|------|--------------|------|--------|
| 人口（population） | x=12, y=8 | 「Pop N/M」 | "Pop 0/50" |
| 満足度（satisfaction） | x=120, y=8 | 「Sat N」 | "Sat 0" |
| 兵力（military_power） | x=200, y=8 | 「Mil N」（整数表示） | "Mil 48" |
| 資金（currency） | x=280, y=8 | 「Cur NG」 | "Cur 100G" |
| ドローゲージ | x=400, y=8 | 横棒（160×24） | バー＋"NEXT DRAW" |
| 強制突撃ゲージ | x=600, y=8 | 10分割段階バー（300×24） | バー＋"Turn N/10" |
| 早期突撃ボタン | x=920, y=8 | ボタン（100×32） | "EARLY CHARGE" |
| 各資源（木/石/硫/小/鉄/綿/食） | y=44, 横並び | 「[アイコン] N」×7 | "🪵5 🪨5 ..." |

#### 5.1.2 各ステータス値の表現

| 値 | 表示形式 | 警告色（v0.2） |
|----|---------|--------------|
| population | "N / M" | M到達時は赤太字（v0.2 では人口=0なので発生せず） |
| satisfaction | "N" | v0.2 では常に "0"（変動なし） |
| military_power | floor 値（整数）"N" | 突撃時にユニット化される量を即視認可能 |
| currency | "N G" | 0時は灰色 |
| 各資源 | アイコン+"N" | 0時は灰色 |
| food | アイコン+"N" | 5未満は赤（v0.2 では人口=0で消費されないため警告は出ない） |

#### 5.1.3 ドローゲージ仕様

| 状態 | 進捗 | バー色 | サブテキスト |
|------|-----|-------|------------|
| 通常進行 | 0〜80% | `COLOR_ACCENT_GOLD`(`#B49448`) | 残秒数（例: "23s"） |
| もうすぐドロー | 80〜100% | `COLOR_ACCENT_GOLD_BRIGHT`(`#D4B468`) + 1.0秒明滅 | "Soon..." |
| ドロー発動瞬間 | 100% | 1フレーム白フラッシュ | - |
| 手札MAX保留 | 100%維持 | `COLOR_TEXT_DIM`（グレー化） | **"MAX (8/8)" 赤** |

#### 5.1.4 強制突撃ゲージ仕様

10分割段階バー。ターン1〜10 を可視化し、現在ターン以下のセグメントが点灯。

| ターン範囲 | 色 | 状態名 | 演出 |
|-----------|----|--------|------|
| 1〜3 | `#3F6932`（緑） | 平常 | 静止 |
| 4〜6 | `#A9924F`（黄） | 注意 | 静止 |
| 7〜9 | `#C77A2C`（橙） | 警戒 | 0.8秒周期明滅 |
| 10 | `#9C3A2A`（赤） | 危険 | 0.4秒周期強明滅＋外側赤光 |

#### 5.1.5 早期突撃ボタン

| 項目 | 仕様 |
|------|------|
| 配置 | 強制突撃ゲージのすぐ右隣（HEADER 右側） |
| サイズ | 100×32 |
| ラベル | "EARLY CHARGE" |
| 通常時 | 背景=`COLOR_PANEL`、枠=`COLOR_BORDER`、テキスト=`COLOR_TEXT` |
| 警戒時(Turn 7-9) | 枠線・テキスト橙 |
| 危険時(Turn 10) | 枠線・テキスト赤＋0.4秒明滅 |
| 押下後 | disabled |

### 5.2 FOOTER 手札 UI（v0.2 改訂・8枚スクロール）

#### 5.2.1 レイアウト

| 項目 | 仕様 |
|------|------|
| 配置 | 画面下部 FOOTER（y=600, h=120） |
| 表示枚数 | 0〜8枚を横並び（**スクロール対応**） |
| 1枚あたりサイズ | **96 × 112 px**（v0.1 の 120×160 から縮小・8枚並列対応） |
| カード並び順 | **ドロー順固定**（左→右）。並び替え禁止 |
| 操作方式 | **D&D 主操作**（クリック→PlaceMode は廃止） |
| スクロール | 8枚を超える表示領域で横スクロール（左右矢印 ◀ ▶ ） |
| 8枚到達時 | 通常表示。ドロー保留中は HEADER ドローゲージに「MAX (8/8)」赤表示 |

**画面幅と手札枚数の関係:**
```
1枚 96px + 間隔 8px = 104px/枚
8枚並列：104 × 8 = 832px ≤ 画面幅 1280px → スクロールなしで収まる
※ ただし HUD 余白を考慮しスクロール対応UIで実装（将来カード増対応）
```

#### 5.2.2 カード内レイアウト（縮小版）

```
┌──────────┐  96px
│ [アイコン]│  44×44 サムネ
├──────────┤
│ 名前     │  10px 太字
│ 人口:N   │  9px 灰
├──────────┤
│ 木:N 石:N │  9px コスト
└──────────┘  112px
```

#### 5.2.3 カード状態（v0.1 同様6状態）

| 状態 | トリガー条件 | 視覚表現 | 操作可否 |
|------|------------|---------|---------|
| 使用可能 | 資源OK＋人口OK＋強制突撃前 | 枠線金 / 通常背景 | D&D 可 |
| 資源不足 | 資源不足 | コスト箇所のみ赤 / 80%暗化 | D&D 不可 |
| 人口不足 | population_used + 必要人口 > pop_cap | 枠線赤 / 60%暗化 / 人口アイコン | D&D 不可 |
| 建設不可 | 強制突撃発動後 / 配置先なし | 1px点線枠 / 50%暗化 / 「×」 | D&D 不可 |
| ホバー中 | マウスオーバー | y -8px 浮上 / 配置候補セル点灯 | クリック→D&D |
| ドラッグ中 | D&D 中 | α50% / プレースホルダ | ドロップ待ち |

### 5.3 デッキ・捨て札・除外表示

| 項目 | 仕様 |
|------|------|
| 配置 | 画面右下（イベント選択区の下） |
| 表示形式 | 「Deck: N」「Discard: N」「Excluded: N」を3行表示 |
| 更新タイミング | 状態変化時に即時反映 |
| クリック内訳 | v0.2 では未実装（hover ツールチップ程度） |

### 5.4 イベント選択区プレースホルダー（v0.2 新規）

| 項目 | 仕様 |
|------|------|
| 配置 | 画面右側（盤面右隣・デッキ表示の上） |
| サイズ | 200×120 |
| 状態 | **ロック状態UI**（v0.3 で機能開放） |
| 表示内容 | 中央に錠アイコン（48×48）＋下部テキスト「v0.3 で開放」（10px DIM） |
| 背景 | `COLOR_PANEL` 50%暗化 |
| 操作 | 不可（クリック無反応） |
| 設計意図 | 「ここに将来イベントが入る」という期待を可視化 |

### 5.5 書庫 UI（v0.1 から継承）

| 項目 | 仕様 |
|------|------|
| 配置 | 盤面ヘックスセル（建物配置先） |
| アイコンサイズ | 48×48 |
| CD表示 | 書庫アイコン上に円形プログレス重畳 |
| CD色 | `COLOR_ACCENT_GOLD`、12時起点・時計回り減少 |
| CD完了 | 1フレーム白フラッシュ |
| 通貨不足時 | アイコンα=0.5 + 「×」（赤16×16） |
| 人口不足停止時 | アイコンα=0.4 + 「停止」アイコン |

### 5.6 廃止UI（v0.2 で削除対象）

| 廃止UI | 理由 |
|--------|------|
| 左側ハーベスター割り当てパネル | ハーベスター廃止に伴う |
| BUILD区4列表示 | カード即時消費に変更 |
| 「建設中」プログレスバー | 盤面建物の出現アニメに統合 |
| FOOTER 内のドローゲージ・人口表示・突撃ゲージ | HEADER に集約 |

### 5.7 視線階層（リアルタイム進行中）

```
[1] 盤面（中央・最大領域）          ← 観戦の主軸
[2] 手札（FOOTER 中央）             ← 次の操作候補
[3] HEADER ステータス（上部）       ← リソース・状態確認
[4] HEADER ドロー＆突撃ゲージ       ← 時間圧
[5] イベント選択区（右上）          ← 将来開放予告（ロック）
[6] デッキ・捨て札・除外（右下）    ← 補助情報
[7] 書庫CD（盤面建物上）            ← サブシステム
```

---

## 6. 書庫 要件（v0.1 から継承・変更なし）

### 6.1 基本仕様

| 項目 | 仕様 |
|------|------|
| カード種別 | 建物カード |
| 建設コスト | 木材4 + 石材2（仮確定） |
| 必要人口 | 1 |
| 建設後の効果 | 通貨1を消費して山札から1枚ドロー（CD 5秒） |
| HP | 80（仮確定） |

### 6.2 通貨1で1ドローの確定/調整

| 論点 | v0.2 の方針 |
|------|------------|
| 通貨1で1ドロー | **MVP内チューニング対象**（仮確定値） |

定数 `LIBRARY_DRAW_COST_CURRENCY = 1` を `EconDeckManager.gd` に定義。

### 6.3 CD 実装

| 項目 | 仕様 |
|------|------|
| CD保持 | 各書庫インスタンスに `library_cd_timer: float = 0.0` |
| 加算 | `update(delta)` 内で経過時間を減算 |
| 発動可否 | `library_cd_timer <= 0.0 and economy.currency >= 1 and is_active` 時のみ |
| 発動時 | `library_cd_timer = 5.0` リセット＋通貨消費＋ドロー実行 |

### 6.4 必要人口1 の効果

| 項目 | 仕様 |
|------|------|
| 必要人口 | 1（建設完了時に population_used を1占有） |
| 人口不足時 | 配置可能だが**停止状態**（HP維持・効果無効） |

### 6.5 複数建築

| 論点 | v0.2 の方針 |
|------|------------|
| 複数建築可否 | **可**（CD/通貨が個別） |

---

## 7. データスキーマ要件

### 7.1 カードデータ（data/cards_econ.json）

#### 7.1.1 カードスキーマ（JSON）

```json
{
  "id": "card_library",
  "name": "書庫",
  "type": "building",
  "building_type": "LIBRARY",
  "draw_type": "BASIC",
  "cost": { "wood": 4, "stone": 2, "sulfur": 0, "wheat": 0, "iron": 0, "cotton": 0 },
  "population_required": 1,
  "population_supply": 0,
  "hp": 80,
  "description": "通貨1を消費してカードを引く（CD 5秒）",
  "ui_position_in_hand": 0
}
```

| フィールド | 型 | 必須 | 意味 |
|-----------|---|------|------|
| id | string | ◯ | カード一意ID |
| name | string | ◯ | 表示名 |
| type | string | ◯ | "building"（v0.2 は building のみ） |
| building_type | string | ◯ | "BARRACKS" / "LIBRARY" / "MARKET" / "HOUSE" / "WOOD_EXTRACTOR" / "STONE_EXTRACTOR" / "SULFUR_EXTRACTOR" / "WHEAT_EXTRACTOR" / "IRON_EXTRACTOR" / "COTTON_EXTRACTOR" |
| draw_type | string | ◯ | "BASIC" / "LIBRARY" |
| cost | dict | ◯ | { wood, stone, sulfur, wheat, iron, cotton } 省略可・数値0で表現 |
| population_required | int | ◯ | 必要人口 |
| population_supply | int | △ | 住居のみ。供給人口（住居=3） |
| hp | int | ◯ | 建物HP |
| description | string | ◯ | UI表示用テキスト |
| ui_position_in_hand | int | △ | 手札描画用 |

### 7.2 econ_state スナップショット（v0.2 拡張）

UI（HEADER）が描画に必要とする state セット：

```json
{
  "econ_state": {
    "population": 0,
    "population_cap": 50,
    "population_used": 0,
    "satisfaction": 0,
    "military_power": 0.0,
    "currency": 100,
    "food": 30,
    "resources": {
      "wood": 5,
      "stone": 5,
      "sulfur": 5,
      "wheat": 5,
      "iron": 5,
      "cotton": 5
    },
    "deck_count": 13,
    "hand": [],
    "discard_count": 0,
    "excluded_count": 0,
    "draw_gauge_value": 0.0,
    "draw_gauge_max": 30.0,
    "current_turn": 1,
    "force_charge_triggered": false
  }
}
```

UI 側はこの state を `EconBattle.deck_manager` / `EconBattle.economy` から都度取得（pull型）。push 通知は draw_callback のみ。

### 7.3 EconEconomy への追加・変更フィールド（v0.2）

| フィールド | 型 | 初期値 | 意味 |
|-----------|---|--------|------|
| population | int | **0** | 実人口（v0.2 では変動なし。v0.3 で運用開始） |
| population_cap | int | **50**（拠点効果） | 人口上限 = 拠点(+50) + Σ住居供給 |
| population_used | int | 0 | 稼働中建物の合計必要人口 |
| **satisfaction** | int | **0** | 満足度（v0.2 では変動なし・表示のみ） |
| **military_power** | float | **0.0** | 兵力（兵舎稼働で蓄積） |
| currency | int | **100** | 資金（書庫消費・市場生産） |
| **food** | int | **30** | 食料（人口×N/秒で消費・v0.2 ではほぼ消費なし） |
| **resources** | Dictionary | **各5** | { wood:5, stone:5, sulfur:5, wheat:5, iron:5, cotton:5 } |

### 7.4 人口上限の計算式（v0.2 改訂）

```
population_cap = BASE_POPULATION_CAP + Σ(active_houses) × HOUSE_POPULATION_SUPPLY
```

| 定数 | 値 | 根拠 |
|------|-----|------|
| `BASE_POPULATION_CAP` | **50**（拠点効果・改訂2） | 序盤デッドロック防止／拠点が落ちると人口上限が一気に消える演出 |
| `HOUSE_POPULATION_SUPPLY` | 3 | 住居1棟あたりの供給量 |
| `MAX_HOUSES_IN_DECK` | 3 | 初期デッキの住居枚数 |

**バトル中の人口上限の理論最大値:**

```
住居3棟すべて建設＆稼働: 50 + 3 × 3 = 59
```

**v0.2 における設計意図:**
- 拠点(+50) のみで全建物（必要人口合計12）が余裕で稼働可能
- 住居3棟は「v0.3 実人口運用への先行投資」
- 住居破壊で人口上限が下がる演出は v0.3 で意味を持つ

### 7.5 EconDeckManager の状態管理

| フィールド | 型 | 意味 |
|-----------|---|------|
| deck | Array[Dictionary] | 山札（先頭が次にドロー） |
| hand | Array[Dictionary] | 手札（**上限8枚**） |
| discard_pile | Array[Dictionary] | 捨て札（v0.2 では未使用） |
| excluded | Array[Dictionary] | 除外（配置成功カード） |
| draw_gauge_value | float | 0.0〜30.0 |
| draw_gauge_max | float | 30.0 |
| current_turn | int | 1〜10 |
| pending_draws | int | ドロー保留数 |
| force_charge_triggered | bool | 強制突撃発動フラグ |
| battle_elapsed_sec | float | バトル開始累積秒 |
| draw_callback | Callable | UI通知 |
| battle | EconBattle | 親バトル参照 |

---

## 8. クラス・メソッド要件（v0.2 改訂）

### 8.1 新規クラス: `EconDeckManager`

**ファイル:** `scripts/econ_mvp/EconDeckManager.gd`

#### 8.1.1 クラス構造

```gdscript
class_name EconDeckManager extends Node

# 定数（パラメータ化）
const TURN_DURATION_SEC: float = 30.0
const MAX_TURNS: int = 10
const HAND_MAX_SIZE: int = 8                # ★ v0.2 で 5→8 に変更
const LIBRARY_CD_SEC: float = 5.0
const LIBRARY_DRAW_COST_CURRENCY: int = 1

# 状態
var deck: Array = []
var hand: Array = []
var discard_pile: Array = []
var excluded: Array = []

var draw_gauge_value: float = 0.0
var current_turn: int = 0
var pending_draws: int = 0
var force_charge_triggered: bool = false
var battle_elapsed_sec: float = 0.0

var draw_callback: Callable
var battle: EconBattle = null
```

#### 8.1.2 メソッドシグネチャ

| メソッド | シグネチャ | 責務 |
|---------|----------|------|
| `setup` | `setup(initial_deck: Array, battle_ref: EconBattle, on_draw: Callable) -> void` | 初期化 |
| `update` | `update(delta: float) -> void` | ターン進行・ドロー |
| `draw_card` | `draw_card() -> Dictionary` | 山札先頭1枚を hand へ |
| `discard_card` | `discard_card(card: Dictionary) -> void` | 手札→捨て札（v0.2 未使用・API のみ） |
| `exclude_card_at` | `exclude_card_at(idx: int) -> Dictionary` | hand[idx] を excluded へ移動 |
| `play_card` | `play_card(card_idx: int) -> Dictionary` | hand から取得→excluded 化（建設実行は呼出側） |
| `request_library_draw` | `request_library_draw() -> bool` | 通貨1消費＋ドロー |
| `try_resolve_pending_draws` | `try_resolve_pending_draws() -> void` | 手札<8 のとき pending を1つ消化 |
| `trigger_force_charge` | `trigger_force_charge() -> void` | 強制突撃発動 |
| `refresh_hand_ui` | `refresh_hand_ui() -> void` | UI再描画 |
| `is_battle_ended_by_turn_limit` | `is_battle_ended_by_turn_limit() -> bool` | ターン上限到達判定 |
| `get_econ_state_snapshot` | `get_econ_state_snapshot() -> Dictionary` | UI 描画用 state |

### 8.2 EconBattle への追加（v0.2 改訂）

```gdscript
# EconBattle.gd 追加
var deck_manager: EconDeckManager = null

func setup_deck(initial_deck: Array, on_draw: Callable) -> void:
    deck_manager = EconDeckManager.new()
    add_child(deck_manager)
    deck_manager.setup(initial_deck, self, on_draw)

func update(delta: float) -> void:
    # ... 既存処理 ...
    if deck_manager != null:
        deck_manager.update(delta)
        deck_manager.try_resolve_pending_draws()
    # 兵舎の兵力蓄積（v0.2 新規）
    _accumulate_barracks_power(delta)

# v0.2 新規：カード使用→建物配置（資源即時消費）
func play_card_and_build(card_idx: int, target_cell: Vector2i) -> bool:
    if deck_manager.force_charge_triggered: return false
    var card: Dictionary = deck_manager.hand[card_idx]
    if not _check_placement_valid(card, target_cell): return false
    economy.consume_resources(card)               # ① 資源即時消費
    deck_manager.exclude_card_at(card_idx)        # ② 除外
    var building = _create_building_from_card(card, target_cell)
    register_player_building(building)            # ③ 盤面登録
    economy.population_used += card.population_required
    if card.has("population_supply"):
        economy.population_cap += card.population_supply
    return true

# v0.2 新規：兵力蓄積
func _accumulate_barracks_power(delta: float) -> void:
    var active_count: int = 0
    for b in player_buildings:
        if b.building_type == "BARRACKS" and b.is_active:
            active_count += 1
    if active_count > 0:
        economy.accumulate_military_power(delta, active_count)

# 早期突撃エントリポイント
func trigger_early_charge() -> void:
    deck_manager.trigger_force_charge()
    unitize_military_power()  # ★ v0.2 新規：兵力→ユニット化

# v0.2 新規：兵力→ユニット変換
func unitize_military_power() -> int:
    var unit_count: int = int(floor(economy.military_power))
    economy.military_power -= float(unit_count)
    if unit_count <= 0: return 0
    _spawn_units_from_barracks(unit_count)
    return unit_count

# v0.2 新規：兵舎セルからのユニット分散出現
func _spawn_units_from_barracks(unit_count: int) -> void:
    var barracks_cells: Array = []
    for b in player_buildings:
        if b.building_type == "BARRACKS" and b.is_active:
            barracks_cells.append(b.cell)
    if barracks_cells.size() == 0: return
    var per_cell: int = int(unit_count / barracks_cells.size())
    var remainder: int = unit_count % barracks_cells.size()
    for i in range(barracks_cells.size()):
        var n: int = per_cell + (1 if i < remainder else 0)
        for _j in range(n):
            spawn_player_unit(barracks_cells[i])  # 既存メソッド
```

**ADR-001 整合性:**
- DeckManager は EconBattle の子ノード
- 外部クラスは `EconBattle.play_card_and_build()` / `EconBattle.trigger_early_charge()` 経由
- 配列直接操作禁止

### 8.3 EconEconomy への新規メソッド（v0.2）

```gdscript
# EconEconomy.gd 追加
const BARRACKS_POWER_PER_SEC: float = 0.2  # 仮値・テストプレイで微調整

# v0.2 新規：カード配置時の資源消費
func consume_resources(card: Dictionary) -> void:
    var cost: Dictionary = card.get("cost", {})
    for resource_key in cost.keys():
        if resources.has(resource_key):
            resources[resource_key] -= cost[resource_key]

# v0.2 新規：資源充足チェック
func can_afford(card: Dictionary) -> bool:
    var cost: Dictionary = card.get("cost", {})
    for resource_key in cost.keys():
        if not resources.has(resource_key): return false
        if resources[resource_key] < cost[resource_key]: return false
    return true

# v0.2 新規：兵力蓄積
func accumulate_military_power(delta: float, active_barracks_count: int) -> void:
    military_power += BARRACKS_POWER_PER_SEC * float(active_barracks_count) * delta

# v0.2 新規：ステータス自動更新（毎フレーム呼出）
func update_status(delta: float) -> void:
    # 食料消費（v0.2 では人口=0なので実害なし）
    food -= int(population) * 0  # v0.3 で具体化
    # 満足度更新（v0.3 で具体化）
```

### 8.4 EconBuilding（書庫・兵舎）への追加（v0.2 改訂）

`scripts/econ_mvp/EconBuilding.gd` に以下を追加。

| 追加フィールド | 型 | 初期値 | 意味 |
|-------------|---|--------|------|
| library_cd_timer | float | 0.0 | 書庫CD残秒 |
| construction_order | int | 0 | 建設順カウンタ（停止優先順位用） |

**v0.2 で削除されるフィールド:**

| 削除フィールド | 理由 |
|------------|------|
| barracks_unit_spawn_timer | 兵舎ユニット直接生産が廃止されたため |

**v0.2 で追加されるメソッド:**

| メソッド | シグネチャ | 責務 |
|---------|----------|------|
| `_update_library` | `_update_library(delta: float, economy, deck_manager) -> void` | CD減算 |
| `try_request_draw` | `try_request_draw(deck_manager) -> bool` | 書庫ドロー実行 |

**v0.2 で削除されるメソッド:**

| 削除メソッド | 理由 |
|------------|------|
| `_update_barracks_spawn` 等 | 兵舎の兵力蓄積は EconBattle 側で一括処理（§8.2） |

### 8.5 UI 側

| クラス/シーン | ファイル | 責務 |
|------------|--------|------|
| EconHeaderUI | EconMain.gd 内に統合（または分離） | HEADER ステータス・両ゲージ・早期突撃ボタン |
| EconHandUI | EconMain.gd 内に統合 | 手札8枚スクロール |
| EconRightPanelUI | EconMain.gd 内に統合 | イベント選択区プレースホルダー・デッキ表示 |
| 書庫CDオーバーレイ | EconBuilding._draw 内 | 書庫アイコン上の円形ゲージ |

**ファイルサイズ判定（実装着手前必須）:**
- EconMain.gd 現在行数を実装着手前に確認
- 800行超予測なら分離する。分離方針は Architect が判断

### 8.6 人口連携（v0.2 ハーベスター廃止）

書庫・兵舎・採取建物の必要人口は **EconEconomy.population_used / population_cap** で管理。

- 建物建設完了時: `economy.population_used += card.population_required`
- 住居建設完了時: `economy.population_cap += card.population_supply`（住居=+3）
- 建物破壊時: `economy.population_used -= card.population_required`
- 住居破壊時: `economy.population_cap -= 3` → 超過分の建物が§8.6.1 のアルゴリズムで停止

**ハーベスター廃止に伴う変更:**
- ハーベスター人数による採取量決定は廃止
- 採取建物は人口を1占有して**自動稼働**で資源生産
- 採取量は建物ごとに固定値（例：木材採取は +1 木材/秒・テストプレイで微調整）

#### 8.6.1 住居破壊時の建物停止アルゴリズム（v0.1 から継承）

```
function on_house_destroyed():
    economy.population_cap -= 3
    while economy.population_used > economy.population_cap:
        target = select_building_to_stop(active_buildings)
        target.is_active = false
        economy.population_used -= target.population_required

function select_building_to_stop(active_buildings):
    # 優先順位1: 必要人口の大きい建物から停止（兵舎優先）
    sorted = active_buildings.sorted_by(b -> -b.population_required)
    # 優先順位2: 同人口なら最後に建設された建物（LIFO）
    sorted = sorted.sorted_stable_by(b -> -b.construction_order)
    return sorted[0]
```

**注:** v0.2 は拠点+50 が常駐するため、本アルゴリズムは「v0.3 以降の実人口運用」で意味を持つ。v0.2 単体では停止が起きにくい。

---

## 9. バトル進行 要件

### 9.1 時系列（v0.2 改訂）

```
t=0秒:    バトル開始
          ・draw_gauge_value = 0.0
          ・current_turn = 1
          ・hand = []（初期手札0枚）
          ・force_charge_triggered = false
          ・economy.resources = { wood:5, stone:5, sulfur:5, wheat:5, iron:5, cotton:5 }
          ・economy.currency = 100
          ・economy.food = 30
          ・economy.population_cap = 50（拠点効果）
          ・economy.military_power = 0.0
          ・economy.satisfaction = 0

t=0〜30秒: ターン1進行
          ・draw_gauge_value が delta ごとに加算
          ・UI: ドローゲージ進行表示

t=30秒:   draw_gauge_value >= 30.0 検知
          ・current_turn += 1（→ 2）
          ・draw_card() 実行
          ・draw_gauge_value = 0.0 リセット
          ・UI: 強制突撃ゲージのセグメント1点灯
          ・UI: カード飛来Tween 0.3秒

t=60〜270秒: ターン2〜9 ドロー
          ・各ターン終端で1枚ドロー
          ・兵舎稼働中なら military_power += 0.2 × active_barracks × delta
          ・カード配置時に economy.consume_resources(card) で資源消費

t=300秒:  ターン10のドロー → 直後に trigger_force_charge() 自動発動
          ・force_charge_triggered = true
          ・全プレイヤーユニットの target_priority 上書き
          ・unitize_military_power() 呼出 → 兵力→ユニット化
          ・旗倒しイベント連鎖発火
          ・以降、ドロー停止

早期突撃時:
          ・任意タイミングで EconBattle.trigger_early_charge() 呼出
          ・current_turn 値に関わらず即発動
          ・unitize_military_power() 呼出 → 兵力→ユニット化
          ・ボタンは disabled
          ・以降、ドロー停止
```

### 9.2 ユニット化タイミング（v0.2 改訂2 新規明記）

| トリガー | unitize_military_power() 呼出 | 備考 |
|---------|-----------------------------|------|
| 旗倒し単独 | **呼出しない** | 既存ユニット挙動のみ・前進フラグON |
| 早期突撃ボタン押下 | **呼出する** | 兵力48 → ユニット48体 |
| 強制突撃ゲージ満タン | **呼出する** | 自動発動と同時 |

### 9.3 1ターン = 30秒

- 定数 `EconDeckManager.TURN_DURATION_SEC = 30.0`
- バトル開始時刻から累積秒で算出
- フレームスキップ耐性: `int(battle_elapsed_sec / TURN_DURATION_SEC) + 1`

### 9.4 最大10ターン

- 定数 `EconDeckManager.MAX_TURNS = 10`
- 10ターン目のドロー実行**直後**に `trigger_force_charge()` を自動呼出

### 9.5 山札枯渇シナリオ（v0.2 はリシャッフルなし）

**v0.2 の確定方針:** リシャッフルしない／ドロー無効。

```
[draw_card() 呼出]
        │
        ▼
  deck.is_empty()?
   ├─ Yes → ログ出力「山札切れ」 → 何もせず return
   │        （pending_draws も増やさない）
   │        （draw_gauge_value は 0.0 にリセット）
   └─ No → 通常ドロー処理
```

### 9.6 強制突撃発動後の挙動

| 項目 | 挙動 |
|------|------|
| ドロー | 停止（基本＋書庫の両方） |
| 建設 | **停止**（手札カードは disabled） |
| 資源配分操作 | 継続可能（既存挙動） |
| ターゲット指示 | 継続可能（既存挙動） |
| ユニット target_priority | 全プレイヤーユニットを「前線制圧」相当に上書き |
| **兵力ユニット化** | **即時実行**（早期突撃 / 強制突撃ゲージ満タン時のみ） |
| 旗倒しイベント | 自動連鎖発火 |
| 勝敗判定 | 既存 req_economy_mvp.md §10（拠点破壊）に準拠 |

---

## 10. 検証論点（v0.2 内チューニング対象）

| # | 論点 | 確定値 | 備考 |
|---|------|-------|------|
| 16.1 | ターン長 30秒 | **30.0秒で確定** | 5分バトル × 10ターン |
| 16.2 | 基本ドロー枚数 1枚/ターン | **1枚/ターン で確定** | パラメータ化のみ |
| 16.3 | 手札上限 | **8枚で確定**（v0.2 改訂） | スクロール対応 |
| 16.4 | 書庫強度（通貨1=1ドロー、CD5秒） | **確定**（パラメータ化） | テストプレイで微調整 |
| 16.5 | デッキ圧縮 | v0.2 は **配置＝除外固定** | 戦略レイヤーは v0.3 |
| 16.6 | 初期手札枚数 | **0枚** | バトル開始30秒後に第1ドロー |
| 16.7 | デッキ枯渇時 | **ドロー無効（リシャッフルなし）** | |
| 16.8 | 強制突撃後の建設可否 | **停止** | |
| 16.9 | 通貨フィールド | **EconEconomy.currency: int 新設** | 初期値 100 |
| 16.10 | population 実装方式 | **案A（population_used / population_cap）** | |
| 16.11 | 書庫の建設コスト・HP | 木材4 + 石材2 / HP=80（仮確定） | |
| 16.12 | 鉄鉱石・綿花採取の v0.2 包含 | **含める** | 13枚の内訳保証 |
| **16.13** | **拠点効果（population_cap）** | **+50（常駐）で確定** | **v0.2 改訂2 新規** |
| **16.14** | **兵舎メカニクス** | **兵力蓄積式 +0.2/秒（仮）／突撃時 1:1 ユニット化** | **v0.2 改訂2 新規** |
| **16.15** | **カード配置時の資源消費** | **配置確定時に即時消費（BUILD区廃止）** | **v0.2 改訂2 新規** |
| **16.16** | **初期資源** | **各5・食料30・資金100** | **v0.2 改訂2 新規** |
| **16.17** | **満足度** | **初期値0・表示のみ（v0.3 で具体化）** | **v0.2 改訂2 新規** |

---

## 11. 初期デッキ構成（13枚・v0.2 改訂）

### 11.1 全カード一覧（仕様完全版）

| カードID | 種別 | 枚数 | 必要人口 | 供給人口 | 建設コスト | HP | 効果 | 配置制約 |
|---------|------|------|---------|---------|----------|-----|------|---------|
| card_wood_extractor | 資源採取 | 1 | 1 | 0 | 木材2 | 50 | 木材採取 +1/秒（仮） | 木材タイル隣接セル |
| card_stone_extractor | 資源採取 | 1 | 1 | 0 | 木材2 | 50 | 石材採取 +1/秒（仮） | 石材タイル隣接セル |
| card_sulfur_extractor | 資源採取 | 1 | 1 | 0 | 木材2 | 50 | 硫黄採取 +1/秒（仮） | 硫黄タイル隣接セル |
| card_wheat_extractor | 資源採取 | 1 | 1 | 0 | 木材2 | 50 | 小麦採取 +1/秒（仮） | 小麦タイル隣接セル |
| card_iron_extractor | 資源採取 | 1 | 1 | 0 | 木材2 + 石材1 | 50 | 鉄鉱石採取 +1/秒（仮） | **山岳タイル隣接セルのみ** |
| card_cotton_extractor | 資源採取 | 1 | 1 | 0 | 木材2 | 50 | 綿花採取 +1/秒（仮） | 綿花タイル隣接セル |
| card_house | 住居 | 3 | 0 | **+3** | 木材3 | 60 | 人口上限供給 | 自陣プレイエリア |
| card_library | 書庫 | 1 | 1 | 0 | 木材4 + 石材2 | 80 | 通貨1=1ドロー、CD5秒 | 自陣プレイエリア |
| card_market | 市場 | 1 | 1 | 0 | 木材3 + 石材2 | 70 | 通貨生成 +1/10秒（仮） | 自陣プレイエリア |
| **card_barracks** | **兵舎** | **2** | **2** | **0** | **木材5 + 石材3** | **100** | **兵力蓄積 +0.2/秒（仮）／突撃時 1:1 ユニット化** | **自陣プレイエリア** |

**合計: 13枚**

**v0.2 改訂2 での変更点:**
- 兵舎の効果が「攻撃ユニット直接生産」→「兵力蓄積式」に変更（§4.7 参照）

### 11.2 人口バランスチェック（v0.2 改訂）

| 項目 | 値 |
|------|-----|
| 拠点効果（BASE_POPULATION_CAP） | **50** |
| 住居3棟による供給 | +9 |
| **最大人口上限（住居3棟稼働時）** | **59** |
| 全機能建物の必要人口（住居除く10棟） | 12 |
| 取捨選択の幅 | **拠点+50 で全建物余裕で稼働可能**（v0.3 で実人口運用が始まれば変化） |

---

## 12. 実装優先度

### P0（v0.2 必須）

- **EconEconomy 新フィールド追加**（population/population_cap=50/satisfaction/military_power/currency=100/food=30/resources=各5）
- **EconEconomy.consume_resources / can_afford / accumulate_military_power 追加**
- **EconBattle.play_card_and_build 改訂**（資源即時消費・BUILD区廃止）
- **EconBattle.unitize_military_power 新規**（兵力→ユニット化）
- **EconBattle._accumulate_barracks_power 新規**（兵舎兵力蓄積）
- EconDeckManager クラス実装（§8.1 全メソッド・HAND_MAX_SIZE=8）
- 初期デッキ13枚ロード（data/cards_econ.json・兵舎を兵力蓄積式に修正）
- **HEADER ステータス UI**（人口・満足度・兵力・資金・各資源）
- **手札8枚スクロール UI**（§5.2）
- ドローゲージ・強制突撃ゲージ UI（HEADER 内）
- カード飛来Tween
- 配置候補ハイライト

### P1（v0.2 内）

- 書庫の通貨ドロー実装
- 書庫CD円形オーバーレイ UI
- 早期突撃ボタン
- 強制突撃ゲージ満タン時の自動 trigger_force_charge
- 山札切れ時のドロー無効ロジック
- 住居配置時の人口プレビュー `[+3]`
- **イベント選択区プレースホルダー（ロックUI）**
- **デッキ・捨て札・除外表示（画面右下）**

### P2（v0.3 以降）

- 満足度システムの具体化
- 実人口運用（人口数の変動・食料消費の本格運用）
- 駐屯地（ユニット出現位置の多様化）
- イベント選択区機能
- 捨て札からのリシャッフル
- デッキ圧縮（除外/破棄選択）
- カード裏面フリップ演出
- カード並び替え（コスト順等）
- 警告音
- 山札・捨て札・除外のクリック内訳表示

---

## 13. 制約・注意事項

### 13.1 設計原則との整合性

- **核体験との整合**: ドロー＝「介入リズムの離散化」であり、観戦体験を損なわない
- **3秒ルール**: ドローゲージ・突撃ゲージ・手札MAXラベル・ステータス表示は「見て3秒で状態が分かる」UI設計
- **KISS**: BUILD区廃止・ハーベスター廃止により操作ステップ削減。引き算優先

### 13.2 ADR-001 規約（疎結合の徹底）

- **EconDeckManager は EconBattle の直接の子ノード**として配置
- 外部クラスから deck/hand/excluded 配列を**直接操作しない**（append・代入禁止）
- 建物登録は `EconBattle.register_player_building(b)` 経由
- カード除外は `EconBattle.deck_manager.exclude_card_at()` 経由
- 早期突撃は `EconBattle.trigger_early_charge()` のみ
- 資源消費は `EconEconomy.consume_resources(card)` のみ
- 新しいクラス間連携が必要になったら、まず ADR に記録

### 13.3 v0.2 での廃止クラス・関数（実装時削除対象）

| 種別 | 名称 | 廃止理由 |
|------|------|---------|
| クラス | `EconHarvester`（既存） | ハーベスター割り当て廃止 |
| クラス | `EconBuilder`（削除済 / git status M で確認） | BUILD区廃止 |
| メソッド | `EconBattle.assign_harvester_to_building()` | ハーベスター廃止 |
| メソッド | `EconBuilding._update_construction_progress()` | BUILD区廃止（即時建設） |
| メソッド | `EconBuilding._update_barracks_spawn()` | 兵力蓄積式へ移行 |
| フィールド | `EconBuilding.construction_progress` | 即時建設化 |
| フィールド | `EconBuilding.barracks_unit_spawn_timer` | 兵力蓄積式へ移行 |
| UI | 左側ハーベスター割り当てパネル | UI 大改造 |
| UI | BUILD区4列表示 | 廃止 |
| UI | 「建設中」プログレスバー | 即時建設化 |

**実装注意:** 廃止対象は Implementer が削除する。Architect は要件定義書で「廃止する」と明記するのみ。削除順序や削除範囲の最終決定は Implementer 着手時に再確認。

### 13.4 既存実装との非競合

- req_economy_mvp.md の §1〜§18 と矛盾しない（ドロー導入は§9 UIへの追加・§5 建造物への書庫追加のみ）
- バトル時間 5分は既存仕様。ターン10×30秒 = 5分整合
- 既存の旗倒しシステム（req_econ_charge_system.md）は維持
- 兵舎の v0.1 仕様（直接生産）は v0.2 で**全置換**

### 13.5 UI 層との整合（双方向参照）

- 本要件定義書 §5（v0.2 仕様）と Designer 仕様書 `ui_draw_hand_gauge_specification.md`（v0.1 仕様）の不整合を Designer が解消する
- v0.2 では本要件定義書 §5 を SSOT とする
- Designer 仕様書を更新したら本書 §5 を同期させる

### 13.6 パラメータ化の徹底

```gdscript
# EconDeckManager.gd
const TURN_DURATION_SEC: float = 30.0
const MAX_TURNS: int = 10
const HAND_MAX_SIZE: int = 8                     # ★ v0.2 改訂
const LIBRARY_CD_SEC: float = 5.0
const LIBRARY_DRAW_COST_CURRENCY: int = 1

# EconEconomy.gd
const BASE_POPULATION_CAP: int = 50              # ★ v0.2 改訂（拠点効果）
const HOUSE_POPULATION_SUPPLY: int = 3
const BARRACKS_POWER_PER_SEC: float = 0.2        # ★ v0.2 新規
const INITIAL_RESOURCES: Dictionary = {          # ★ v0.2 新規
    "wood": 5, "stone": 5, "sulfur": 5,
    "wheat": 5, "iron": 5, "cotton": 5
}
const INITIAL_FOOD: int = 30                     # ★ v0.2 新規
const INITIAL_CURRENCY: int = 100                # ★ v0.2 新規
```

### 13.7 ファイルサイズ予防（実装着手前必須）

- **EconMain.gd 現在行数を確認**（実装着手前）
- 新規追加が以下の範囲：
  - HEADER ステータス UI（推定 +200行）
  - 手札8枚スクロール（推定 +150行）
  - イベント選択区プレースホルダー（推定 +50行）
  - デッキ・捨て札・除外表示（推定 +50行）
  - 廃止UIの削除（−推定 200行）
  - 差し引き **+250行程度の追加**を予測
- **EconMain.gd が 800行超になる場合は分離必須**：
  - `EconHeaderUI.gd`（HEADER 全体）
  - `EconHandUI.gd`（FOOTER 手札）
  - `EconRightPanelUI.gd`（イベント選択区＋デッキ表示）

---

## 14. 実装開始前チェックリスト（v0.2 向け再構成）

Implementer は実装着手前に以下を全てチェックすること。未確認項目があれば CEO に差し戻す。

### 14.1 v0.2 設計・データ確認

- [ ] EconDeckManager のクラス設計確認（§8.1 全メソッド・HAND_MAX_SIZE=8）
- [ ] EconEconomy 新フィールド確認（§7.3：population_cap=50 / satisfaction / military_power / currency=100 / food=30 / resources=各5）
- [ ] 初期デッキ13枚のカードデータ確認（§11、`data/cards_econ.json` のスキーマ §7.1 に準拠・**兵舎を兵力蓄積式に変更**）
- [ ] 全10種カードの建設コスト・HP・必要人口・配置制約を §11.1 で確認
- [ ] 人口計算式（拠点+50 + 住居×3）の実装ロジック確認（§7.4）

### 14.2 v0.2 ロジック実装確認

- [ ] **カード配置時の資源即時消費**ロジック確認（§4.4・`EconBattle.play_card_and_build` 改訂）
- [ ] **兵舎の兵力蓄積**ロジック確認（§4.7・`EconBattle._accumulate_barracks_power`）
- [ ] **兵力→ユニット化**ロジック確認（§4.7.4・`EconBattle.unitize_military_power`・1:1変換・兵舎セル分散出現）
- [ ] **早期突撃 / 強制突撃ゲージ満タン時のユニット化発動**確認（§9.2・旗倒し単独では発動しない）
- [ ] ドロー保留と独立ターン進行のロジック確認（§4.8）
- [ ] 山札枯渇時のドロー無効処理確認（§9.5）
- [ ] 並存システム3トリガー（旗倒し / 早期突撃 / ゲージ満タン）の実装フロー確認（§4.6.2）

### 14.3 v0.2 UI 実装確認

- [ ] **HEADER ステータス UI**（人口・満足度・兵力・資金・各資源）配置確認（§5.1）
- [ ] **手札8枚スクロール UI** 配置確認（§5.2）
- [ ] **デッキ・捨て札・除外表示**（画面右下3行）配置確認（§5.3）
- [ ] **イベント選択区プレースホルダー**（ロック状態UI）配置確認（§5.4）
- [ ] ドローゲージ・強制突撃ゲージのアニメーション実装手順確認（§5.1.3 / §5.1.4）
- [ ] カード飛来Tween 0.3秒の実装方法確認
- [ ] 手札カード6状態の遷移フロー確認（§5.2.3）

### 14.4 v0.2 廃止対象の確認

- [ ] **ハーベスター関連クラス・UI 削除リスト**確認（§13.3）
- [ ] **BUILD区関連クラス・UI 削除リスト**確認（§13.3）
- [ ] **兵舎の直接生産関連メソッド・フィールド削除リスト**確認（§13.3）
- [ ] 削除対象の影響範囲（呼び出し元）を grep で事前確認

### 14.5 規約・整合性確認

- [ ] ADR-001 準拠の設計確認（§13.2、配列直接操作禁止）
- [ ] UI色定数の定義確認（`COLOR_ORANGE` / `COLOR_RED` / `COLOR_ACCENT_GOLD_BRIGHT`）
- [ ] **EconMain.gd 現在行数確認**（800行超予測なら分離・§13.7）
- [ ] 並存システムのシグナル設計確認（§9.6）
- [ ] Designer 仕様書（v0.1 仕様）と本要件定義書 §5（v0.2 仕様）の不整合は本書 §5 を SSOT として実装
- [ ] check_syntax.sh が実装後に通ることを最終チェック

---

## 15. 参照

- `docs/requirements/req_economy_mvp.md`（1バトル詳細仕様・上位ドキュメント）
- `docs/design/enterprise_draw_design_mvp.md`（Planning 出力／**v0.2 改訂2 SSOT**）
- `docs/design/ui_draw_hand_gauge_specification.md`（Designer 出力／v0.1 仕様・v0.2 部分は本書 §5 で先行定義）
- `docs/design/econ_mvp_run_structure.md`（ラン全体構造）
- `docs/meta/adr/001_econ_spawn_centralized.md`（EconBattle 一元化規約）
- `docs/meta/req_econ_charge_system.md`（既存旗式突撃要件）
- `docs/meta/req_econ_rally_point.md`（旗の集結点 UI 要件）
- `docs/GAME_DESIGN.md`（設計・最優先）
- `docs/game_philosophy.md`（ゲーム哲学）
- `CLAUDE.md`（開発ルール）

---

## 16. 確定事項サマリ

### 16.1 v0.2 で確定（実装対象）

| # | 論点 | **確定値** | 影響範囲 |
|---|------|-----------|---------|
| Q1 | 初期手札枚数 | **0枚**（バトル開始30秒後に第1ドロー） | EconDeckManager.setup |
| Q2 | デッキ枯渇時の挙動 | **ドロー無効（リシャッフルなし）** | draw_card() |
| Q3 | 強制突撃後の建設可否 | **停止** | EconBattle 建設フロー |
| Q4 | 通貨フィールドの新設 | **EconEconomy.currency: int 新設・初期100** | EconEconomy / 市場 |
| Q5 | population 実装方式 | **案A（population_used / population_cap）** | EconEconomy |
| Q6 | 鉄鉱石・綿花採取の v0.2 包含 | **含める** | カードデータ |
| Q7 | 住居の効果 | **人口供給 +3/棟** | カードデータ |
| Q8 | 市場の通貨生成レート | **+1 通貨 / 10秒**（仮確定） | カードデータ |
| Q9 | 書庫の建設コスト・HP | **木材4 + 石材2 / HP=80**（仮確定） | カードデータ |
| Q10 | 書庫の複数建築可否 | **可**（CD/通貨が個別） | EconBuilding |
| Q11 | ドロー保留中の draw_gauge 挙動 | **満タンで停止／ターンは独立進行** | EconDeckManager.update |
| Q12 | カードJSON配置 | **分離（data/cards_econ.json）** | データ管理 |
| **Q13** | **手札上限** | **8枚（スクロール対応）** | EconDeckManager / 手札UI |
| **Q14** | **拠点効果（population_cap）** | **+50 常駐** | EconEconomy |
| **Q15** | **兵舎メカニクス** | **兵力蓄積式 +0.2/秒（仮）／突撃時 1:1 ユニット化** | EconBattle / EconEconomy |
| **Q16** | **カード配置時の資源消費** | **配置確定時に即時消費（BUILD区廃止）** | EconBattle.play_card_and_build |
| **Q17** | **初期資源** | **各5・食料30・資金100** | EconEconomy 初期化 |
| **Q18** | **HEADER 集約** | **人口・満足度・兵力・資金・各資源・両ゲージを HEADER 集約** | UI |
| **Q19** | **イベント選択区** | **v0.2 ではロックUI のみ** | UI |
| **Q20** | **ハーベスター・BUILD区廃止** | **完全廃止（既存クラス・UI 削除）** | EconHarvester / EconBuilder / 関連 UI |

### 16.2 v0.3 以降に繰越（v0.2 では実装しない）

| # | 項目 | v0.3 で具体化する内容 |
|---|------|--------------------|
| 1 | **満足度システム** | 何で増減するか・建物稼働への影響・敗北条件への影響 |
| 2 | **実人口運用** | 実際の人口数の変動メカニクス・食料消費の本格運用 |
| 3 | **駐屯地** | ユニット出現位置の多様化（兵舎セル以外） |
| 4 | **イベント選択区機能** | カードプール拡張・選択メカニクス |
| 5 | **捨て札からのリシャッフル** | デッキ圧縮システム |
| 6 | **食料消費レートの確定** | 人口×N/秒の N 値（v0.2 では仮値） |
| 7 | **兵力蓄積レートの確定** | BARRACKS_POWER_PER_SEC の最終値（v0.2 では 0.2 仮値） |
| 8 | **市場の通貨生成レートの確定** | +1/10秒 の最終値 |

**実装フロー:**
1. ✅ Planning 改訂2 確定（enterprise_draw_design_mvp.md）
2. ✅ 本要件定義書 v0.2 改訂3 確定（本書）
3. ⚠️ Designer 仕様書 v0.2 改訂は v0.2 実装と並行して進める（本書 §5 を SSOT）
4. → **Implementer に着手指示可能（v0.2 スコープ）**
