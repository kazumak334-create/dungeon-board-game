# Sprint 8 要件定義書 — UI・ログ・デバッグ

ステータス: 実装リソース（一時）
対応Sprint: Sprint 8
参照Final企画書: `docs/sprint8_ui_logs_debug_final_revised.md`（SSoT）
参照Designer企画書: `docs/design/sprint8_designer_plan.md`
参照Sprint 7要件: `docs/requirements/REQUIREMENTS_SPRINT_7.md`（前提・未実装含む）
統合先: `docs/requirements/REQUIREMENTS_V0_2_MVP.md`（Sprint 8 セクション）
作成日: 2026-05-04
更新日: 2026-05-04（Design Review 反映：建設キュー データソース SSoT 明示／FOOTER 高さ 180px 制約明記／F7 建設順番号バッジ仕様格上げ）

> 本書は Sprint 7 の建設フロー（建設予定地・建設進捗・人手スライダー）の上に、UI・ログ・デバッグ機能を載せる。Sprint 7 の実装が前提となるため、共通データ構造（`EconGrid.construction_sites`、`EconEconomy.get_total_labor()` 等）は Sprint 7 要件定義書を参照する。

---

## 1. 目的

### 1.1 目的
Sprint 8 では Sprint 1〜7 で定義した都市成長・建築・建物稼働・人手配分・人口・食料値・満足度・兵力/兵数/ユニットを、プレイヤーが理解できる UI と、開発者が検証できるログ／デバッグ機能に接続する。5分のテストプレイで以下を判定可能な状態にする。

```text
- 建物が建つ
- 建設順を制御できる
- 建物が稼働する
- 建設中／稼働中／停止中が見分けられる
- 食料値・人口・満足度・兵力／兵数／ユニットが伸びる
- 人手配分により建設／稼働が変化する
- ログとデバッグ操作で詰まり要因を確認できる
```

### 1.2 核となる体験との整合
- **盤面設計の延長**: 建設キュー順制御は「設計の続き」であり、バトル開始後でもキュー順を介して盤面設計を継続できる。
- **介入の仕込み**: 即時建設G・建設キャンセル・人手スライダー再配分が「介入」として機能する。
- **観戦**: BPB式進捗 Overlay／Mask、HEADER 常時表示、停止理由アイコンで「答え合わせの観戦」を成立させる。
- 詳細表示は右側パネルやボトムシートではなく、その場で開く小型ポップアップに限定し、盤面（観戦対象）の視認性を最優先する。

### 1.3 KISS 適用（Designer 企画 §1.4 準拠）
- 新規色定義は **0 個**（既存 `EconMain.gd` の `COLOR_*` 定数のみ流用）。
- 詳細表示は **小型ポップアップ 1 種**（パネル形式は満足度／兵力／建物の 3 種で共通）。
- 停止理由は **アイコン 1 個 + ❌ 表記のみ**（複合原因は建物詳細ポップアップ側に格納）。
- 建設中ポップアップは作らない（建設キュー＋盤面表示で十分）。
- 人手詳細ポップアップは作らない（Sprint 7 の既存スライダーを継続使用）。
- ログ形式は 1 行テキスト（`timestamp key=value` 形式）に統一。CSV／JSON 出力の作り込みは非対象。
- データ構造は専用クラスを作らず Dictionary／Array で保持（Sprint 7 流儀を踏襲）。

---

## 2. 用語定義（企画書 §2 と完全一致）

| 用語 | 定義 | コード上の対応（実装の指針） |
|---|---|---|
| 常時表示 UI | プレイ中に常に表示される都市状態 UI。人口・食料値・満足度段階・兵力・兵数・ユニット数・既存人手表示などを扱う | HEADER 内のラベル群（既存 HEADER 拡張） |
| 詳細ポップアップ | 対象をタップ／クリックした位置の近くに表示する小型情報表示。右側パネルやボトムシートは使わない | `PanelContainer`（最大 240×280） |
| 人手 | 人口から算出される作業可能枠（既存システム） | `EconEconomy.get_total_labor()`（Sprint 7 で新設） |
| 稼働人手 | 完成済み建物の効果発動に使う人手 | `EconEconomy.get_operation_labor()`（Sprint 7） |
| 作業人手 | 建設中建物の建設進捗に使う人手 | `EconEconomy.get_work_labor()`（Sprint 7） |
| 人手スライダー | 人手総量を稼働人手と作業人手に配分する既存 UI | Sprint 7 の LABOR ブロック（既存） |
| 建設予定地 | 建物カード使用時に指定される、建設中の土地パネル | Sprint 7 の `EconGrid.construction_sites: Dictionary` |
| 建設キュー | 建設予定中の建物を建設順に並べる UI／内部順序。盤面左側に積み上げ表示する | 新設 `BuildQueueUI`（後述）／内部順序は `construction_sites` の `started_at` 昇順 |
| 建設順番号 | 建設キュー内の順番を示す番号（1 始まり）。建設予定地にも同じ番号を表示する | キュー順の index（int） |
| 建設進捗 | 建設完了までの進行度。建設キュー順と作業人手に応じて進む | Sprint 7 の `construction_sites[panel_id].construction_progress` |
| 建物効果進捗 | 周期発動建物や累計条件型建物の効果発動までの進行度（0.0〜1.0） | 新設 `EconBuilding.effect_progress_rate: float` |
| BPB 形式 | Backpack Battles 風の進捗表現。対象オブジェクト上に進捗 Overlay／Mask を重ねて、発動／完了までの進行を視覚化する方式 | `_draw()` の `draw_rect()` で下→上塗り |
| 建設進捗 Overlay | 建設中の進捗を示す Overlay／Mask。リング型（Sprint 7 の半透明シルエット＋金色リングを継承） | Sprint 7 の建設中表現（既存） |
| 建物効果進捗 Overlay | 稼働中建物の効果発動進捗を示す Overlay／Mask。下→上塗り型 | 新設（Sprint 8 で追加） |
| 停止理由 | 資源不足・稼働人手不足・作業人手不足など、建設や建物稼働が止まっている理由 | 既存の停止判定フラグ（Sprint 7 の `is_operating == false` ＋停止理由 String） |
| 即時建設 | 建設キュー上の項目をクリックし、通貨 G を消費して建設を即時完了する操作 | 新設関数 `BuildQueue.complete_now(panel_id) -> bool` |
| 建設キャンセル | 建設キュー上の項目を右クリックし、建設予定地を解除して支払済み建設コストを返却する操作 | 新設関数 `BuildQueue.cancel(panel_id) -> bool` |
| 通貨 G | ラン中に保持される通常通貨。Sprint 8 では即時建設コストに使用する | 既存 `_gold_label` 表示の通貨（既存実装あり） |
| 通常資源 | 木・樹脂・石・鉄鉱石・小麦・綿花。建築や建物稼働に使う | 既存 `EconEconomy` の資源辞書 |
| BUILD QUEUE | 建設キュー UI のラベル名（英字大文字）。Designer 企画準拠 | UI ラベル文字列 |
| DEBUG TOOLS | デバッグツールパネルのラベル名（英字大文字）。Designer 企画準拠 | UI ラベル文字列 |

> **Sprint 7 との整合**: `is_operating`（稼働中フラグ）、`stop_reason`（停止理由 String）、`required_work_labor` / `required_operation_labor` などの建物側フィールドは Sprint 7 の要件定義書で規定済み。Sprint 8 ではそれらを参照表示するのみで、新フィールドは最小限に抑える。

---

## 3. 実装スコープ

### 3.1 対象機能

| 機能 ID | 機能 | 概要 |
|---|---|---|
| F1 | 常時表示 UI（HEADER 上段拡張） | 人口・食料値・満足度段階・兵力・兵数・ユニット数を 1 段（高さ 36px）で常時表示 |
| F2 | 人口表示フォーマット | `150k / 250k` 形式（k／M 単位、「人」を付けない） |
| F3 | 満足度詳細ポップアップ | 満足度ラベルクリックで小型ポップアップ表示（値%・傾き・内訳） |
| F4 | 兵力詳細ポップアップ | 兵力／兵数／ユニットラベルクリックで小型ポップアップ表示（必要スタック数・補正内訳） |
| F5 | 建物詳細ポップアップ | 完成済み建物クリックで小型ポップアップ表示（分類・状態・進捗・効果・足元土地・停止理由） |
| F6 | 建設キュー UI | 盤面左側 (140×420、y=100-520) に建設順に積み上げ表示 |
| F7 | 建設順番号バッジ | 建設予定地パネル左上に直径 18px の番号バッジを表示 |
| F8 | 建設順入れ替え | キュー項目ドラッグで順序変更（10px 閾値） |
| F9 | 即時建設 | キュー項目クリックで G 消費 → 進捗 100% 化 |
| F10 | 建設キャンセル | キュー項目右クリックで予定地解除＋コスト返却＋番号再採番 |
| F11 | 建物効果進捗 Overlay（BPB 形式） | 完成済み稼働建物上に下→上塗り Overlay を表示（共通仕様） |
| F12 | 停止理由アイコン | 停止中のみ建物パネル右上／キュー項目内に「❌資／❌小／❌人／❌作」を表示 |
| F13 | 足元土地情報表示 | 建物詳細ポップアップ内に地形・通常資源・複合資源・特殊タグを表示 |
| F14 | ログ出力（9 種） | 人口／食料値／満足度／建物稼働／建築／人手／資源獲得／兵力・兵数・ユニット／防衛突破 |
| F15 | デバッグツールパネル | FOOTER 右端 (320×180) に資源加算・建設操作・疑似障害ボタン群を配置 |
| F16 | デバッグログオーバーレイ | 画面右上 (320×200) に直近 10 件のログをトグル表示 |

### 3.2 非対象機能（企画書 §4 準拠）

- 通常マイルストーン報酬 UI、特殊マイルストーン報酬 UI、宝箱 UI、報酬 3 択 UI、土地カード配置 UI（Sprint 9）。
- 次ゲーム遷移、豪華な演出、完成版チュートリアル。
- 詳細グラフ UI、リプレイ機能、長期分析ダッシュボード、CSV／JSON 出力の完成実装。
- UI アニメーション作り込み、サウンド演出。
- 人手詳細ポップアップ新規追加、建設詳細ポップアップ新規追加。

---

## 4. データ構造

### 4.1 建物効果進捗（F11）

`EconBuilding.gd` に最小限のフィールドを追加。

```gdscript
# 0.0 〜 1.0。0 で発動準備中、1 で発動瞬間。発動後は 0 にリセット
var effect_progress_rate: float = 0.0
# 効果発動瞬間の発光（残り時間秒）。0 ならば非発光
var effect_flash_remaining: float = 0.0
const EFFECT_FLASH_DURATION_SEC := 0.20
```

> 既存タイマー値（例: `_diner_timer`、`_village_wheat_timer` 等）と発動間隔（例: `DINER_INTERVAL`）を組み合わせて `effect_progress_rate = clamp(1.0 - timer / interval, 0.0, 1.0)` で更新する。新タイマーは作らない。

### 4.2 建設キュー UI データソース（F6）

**SSoT（Single Source of Truth）**: `EconBattle.grid.construction_sites: Dictionary`

Sprint 7・ADR-003 により、`construction_sites` は `EconBattle` が所有する Construction 状態の唯一のデータソース。
建設キュー UI は **必ずこの SSoT を参照** し、他のデータ（例: `EconBattle.player_buildings`）から建設中の建物を取得してはならない。

**取得ロジック**:

```gdscript
# BuildQueueUI.gd
func get_queue_buildings() -> Array:
    # SSoT は EconBattle.grid.construction_sites（ADR-003）
    var sites: Array = battle.grid.construction_sites.values()
    # started_at 昇順でソート（古い順 = キュー順）
    sites.sort_custom(func(a, b): return a["started_at"] < b["started_at"])
    return sites

# キュー順番号（1 始まり）を取得
func get_queue_index(panel_id: Vector2i) -> int:
    var sorted: Array = get_queue_buildings()
    for i in range(sorted.size()):
        if sorted[i].panel_id == panel_id:
            return i + 1
    return -1
```

**禁止**:
- `battle.player_buildings` から建設中の建物を取得すること（`is_built==false` 等のフィルタ含む）
- `construction_sites` の Dictionary を直接 mutate すること（疎結合違反）

**理由**: ADR-003 に基づき、`construction_sites` が「Construction 状態」の SSoT。`player_buildings` は完成済み建物の SSoT であり、責務を混在させない。

**完了条件**: `BuildQueueUI.gd` の `get_queue_buildings()` が `battle.grid.construction_sites` ベースで動作し、`player_buildings` を参照しないこと（grep で確認）。

> **EconGrid 補助関数（Sprint 7 由来）**:
>
> ```gdscript
> # EconGrid.gd には公開ゲッターのみ提供
> func get_build_queue_order() -> Array:
>     return EconBattle.instance.get_queue_buildings()  # SSoT 参照を統一
> ```
> （実装上、`BuildQueueUI` から直接 `battle.grid.construction_sites` にアクセス可。`EconGrid.get_build_queue_order()` は後方互換用ラッパー）

### 4.3 建設キュー順入れ替え（F8）

ドラッグで順序を変更する場合、`started_at` を再採番する（KISS：別フィールドを増やさない）。

```gdscript
# 例: panel_id を target_index（1 始まり）の位置に移動
func reorder_queue(panel_id: Vector2i, target_index: int) -> void:
    var sorted: Array = get_build_queue_order()
    var moving = construction_sites[panel_id]
    sorted.erase(moving)
    sorted.insert(clamp(target_index - 1, 0, sorted.size()), moving)
    # started_at を 0,1,2,... に再採番（順序保証のみが目的）
    for i in range(sorted.size()):
        sorted[i].started_at = i
    queue_order_changed.emit()
```

### 4.4 即時建設コスト（F9）

**計算ロジック:**
- 工数単価（全建物共通）× 残工数（総工数は建物固有）

```gdscript
# 全建物共通の工数単価
const LABOR_COST_PER_UNIT: int = 5  # G/工数（単価）

# 残工数 = 総工数 - 完了工数
# 総工数 = Sprint 7 の construction_time をそのまま「工数（人時相当）」として扱う
#         （Sprint 7 では float 秒値だが、Sprint 8 では同値を工数単位として再解釈する）
# 完了工数 = 総工数 × 進捗率

func calc_instant_build_cost(panel_id: Vector2i) -> int:
    var site = construction_sites.get(panel_id, null)
    if site == null:
        return 0
    var total_labor_units: float = float(site.construction_time)  # 総工数（建物ごと、float キャストで型を明示）
    var progress: float = clamp(float(site.construction_progress), 0.0, 1.0)
    var remaining_labor: float = total_labor_units * (1.0 - progress)
    if remaining_labor <= 0.0:
        return 0  # 既に完成（クリックは無視）
    return int(ceil(remaining_labor * float(LABOR_COST_PER_UNIT)))
```

**計算例（Designer §4.2.1 と完全一致）:**

| 建物 | 総工数 | 進捗率 | 残工数 | 即時建設コスト |
|---|---:|---:|---:|---:|
| 住宅 | 12 | 0% | 12 | 12 × 5 = **60G** |
| 住宅 | 12 | 50% | 6 | 6 × 5 = **30G** |
| 兵舎 | 40 | 0% | 40 | 40 × 5 = **200G** |
| 兵舎 | 40 | 75% | 10 | 10 × 5 = **50G** |
| 食堂（停止中）| 16 | 25% | 12 | 12 × 5 = **60G**（参考値・実UI上は停止理由を優先表示） |
| 任意 | 任意 | 100% | 0 | **0G**（既に完成） |

> **総工数の出処**: `site.construction_time` が `float` 秒値で保持されている場合も、Sprint 8 では同値をそのまま「工数（人時）」として再解釈する。Sprint 7 で定義された値（住宅=20、兵舎=35 など）は本要件定義書では引き継ぎ前提であり、Designer 例（住宅=12、兵舎=40）はバランス調整候補値として §8.6 残論点で扱う。

> **int/float 誤差防止**: `ceil(remaining_labor * 5.0)` で float 演算を行い、最終的に `int` キャストする。`int * float` の暗黙変換を避けるため `float(LABOR_COST_PER_UNIT)` で明示する。`remaining_labor <= 0.0` の判定で「進捗 1.0 ピッタリ」「浮動小数誤差で僅かに 1.0 を超えた」両方のケースを 0G に丸める。

> **0G（既に完成）の挙動**: 進捗率 1.0 到達でフレーム内に Sprint 7 の完了処理（`construction_sites` から削除→ `EconBuilding` 化）が走るため、通常はキューから消滅する。ただし完了処理が次フレームに持ち越される間にプレイヤーがクリックした場合、`calc_instant_build_cost` は 0 を返し、`_on_queue_item_clicked` 側で `cost_g <= 0` のとき何もせずに早期 return する（赤フラッシュも金色フラッシュも出さない）。

> **LABOR_COST_PER_UNIT = 5 の妥当性（バランス観点）**: 5G は「住宅（総工数12）= 60G、兵舎（総工数40）= 200G」というレンジに収まり、ラン中の所持 G（Sprint 6 既存）の 1〜2 桁レベルで支払い得る現実的な値。具体値は §8.6 残論点に従いテストプレイで再調整する。本要件定義書は `LABOR_COST_PER_UNIT` を `const`（定数）として実装し、調整時は 1 行変更で済むこと（マジックナンバー化禁止）を要求する。

### 4.5 停止理由表現（F12）

`EconBuilding.stop_reason: String`（Sprint 7 で導入）と `construction_sites[panel_id].stop_reason: String`（Sprint 8 で追加）を共通の文字列定数で扱う。

```gdscript
# 共通定数（EconBuilding.gd または共通定数ファイル）
const STOP_REASON_NONE       := ""
const STOP_REASON_RESOURCE   := "資源不足"
const STOP_REASON_WHEAT      := "小麦不足"
const STOP_REASON_OP_LABOR   := "稼働人手不足"
const STOP_REASON_WORK_LABOR := "作業人手不足"

# 表示用アイコン文字列マッピング
static var STOP_REASON_ICON: Dictionary = {
    "資源不足":     "❌資",
    "小麦不足":     "❌小",
    "稼働人手不足": "❌人",
    "作業人手不足": "❌作",
}
```

> 1 建物につき主要 1 個のみ表示する（優先度: 資源不足 > 小麦不足 > 稼働／作業人手不足）。複合原因の全リストは建物詳細ポップアップで表示する。

### 4.6 ポップアップ管理（F3／F4／F5）

既存 `EconMain._header_detail_popup`（PanelContainer）を再利用しつつ、表示種別を識別する `String` 変数を追加する。

```gdscript
# EconMain.gd（既存変数 _header_detail_popup を流用）
var _detail_popup_type: String = ""    # "" / "satisfaction" / "troop" / "building"
var _detail_popup_target: Variant = null  # 対象（建物の場合 EconBuilding、それ以外 null）
```

### 4.7 ログレコード（F14）

専用クラスは作らない。既存 `LogManager.log_event(data: Dictionary)` を 9 種のイベントタイプで呼び分ける。

```gdscript
# 共通フィールド
{ "type": <イベントタイプ>, "timestamp": <float秒> }

# イベントタイプ（企画書 §18.2〜§18.9）
const LOG_TYPE_POPULATION       := "POPULATION"
const LOG_TYPE_FOOD             := "FOOD"
const LOG_TYPE_SATISFACTION     := "SATISFACTION"
const LOG_TYPE_BUILDING         := "BUILDING_TICK"
const LOG_TYPE_CONSTRUCTION     := "CONSTRUCTION"
const LOG_TYPE_LABOR            := "LABOR"
const LOG_TYPE_RESOURCE_GAIN    := "RESOURCE_GAIN"
const LOG_TYPE_MILITARY         := "MILITARY"
const LOG_TYPE_BREACH_DAMAGE    := "BREACH_DAMAGE"
```

各レコードのキー詳細は §5.6 に記載。

### 4.8 デバッグ操作トグル（F15／F16）

```gdscript
# EconMain.gd
const DEBUG_MODE := true   # 本番ビルドで false に切り替え
var _debug_log_overlay_visible: bool = false  # デフォルト OFF
var _debug_force_op_shortage: bool = false    # 稼働人手不足を疑似発生
var _debug_force_work_shortage: bool = false  # 作業人手不足を疑似発生
```

---

## 5. システム仕様

### 5.1 UI 更新フロー（毎フレーム）

```
EconMain._process(delta):
  1. EconEconomy が tick 進行（既存）
  2. EconGrid.update_construction(delta) ← Sprint 7
  3. EconBuilding._process(delta) ← 既存
     a. 各タイマー更新（既存）
     b. effect_progress_rate を計算（4.1）
     c. 効果発動瞬間: effect_flash_remaining = EFFECT_FLASH_DURATION_SEC
  4. UI 更新（_update_ui()）
     a. HEADER 上段ラベル更新（人口／食料値／満足度／兵力／兵数／ユニット）
     b. BuildQueueUI.refresh()
        - get_build_queue_order() で順序取得
        - 各キュー項目を描画（番号・アイコン・名称・進捗バー・停止理由 or G コスト）
     c. 建設予定地番号バッジ更新（construction_sites の panel_id ごと）
     d. 完成済み建物の effect_progress_rate に応じた Overlay 描画（_draw() 内）
     e. 停止理由アイコン更新（is_operating==false の建物のみ表示）
     f. 詳細ポップアップ位置補正（画面外チェック）
  5. ログ出力（_log_periodic_snapshot()）
     a. 1 秒間隔で人口／食料値／満足度／人手／兵力ログを出力
     b. イベント発生時に建物稼働／建築／資源獲得／防衛突破ログを出力
```

### 5.2 建設キュー UI 更新フロー（F6・F7・F8）

#### 描画（Designer §4.2 改訂版に準拠）

```
BuildQueueUI._refresh():
  1. get_build_queue_order() で順序リストを取得
  2. 既存子ノードをクリア（または再利用）
  3. 各 site について:
     a. PanelContainer 高さ 56px を生成（Designer 改訂：64px → 56px）
        - 1行目（18px）: 番号バッジ（① ② ③...）+ 建物アイコン (16×16) + 建物名（11px Bold）
        - 中央領域（22px）: BPB 式進捗 Overlay（背景全域に下→上塗り）
        - 3行目（16px）: 停止中 → 停止理由アイコン「❌作」 / 進行中 → "G:%d" % calc_instant_build_cost(panel_id)
     b. BPB 進捗 Overlay は §5.5 と同じ描画ロジックを再利用（_draw 内で draw_rect）
     c. ホバー時: 枠を COLOR_ACCENT_GOLD 1px に変更、コスト表示の α=1.0 強調
     d. G 不足時: コスト数値を COLOR_RED で描画
  4. 同時に建設予定地パネルの番号バッジを更新（_update_construction_site_badges()）
  5. 5項目までスクロールなし、6項目以上は ScrollContainer で縦スクロール
```

> **キュー項目内 BPB 進捗 Overlay の仕様（Designer §4.2 BPB式進捗の視覚化）**:
> - 進行中: 項目背景中央領域全域に COLOR_ACCENT_GOLD α=0.4 を `construction_progress` 分の高さで下から塗る
> - 停止中: COLOR_TEXT_DIM α=0.3、進捗高さ保持
> - 完成瞬間: COLOR_ACCENT_GOLD α=0.6 で 200ms 全面発光 → キューから消滅
> - 番号バッジ・建物名・コスト/停止理由テキストは Overlay の上に描画（テキスト視認性を保つ）

#### ドラッグ並び替え（F8）

```
BuildQueueUI._gui_input(event):
  - ButtonPressed: drag_start_pos = event.position
  - MouseMotion (押下中): drag_distance >= 10px で drag 開始フラグ
  - drag 中: マウス Y 座標から target_index を計算
  - ButtonReleased:
    if drag_active:
      EconGrid.reorder_queue(panel_id, target_index)
    else:
      _on_queue_item_clicked(panel_id)  # 即時建設へ
```

### 5.3 即時建設（F9）

```
BuildQueueUI._on_queue_item_clicked(panel_id):
  1. cost_g = EconGrid.calc_instant_build_cost(panel_id)
  2. if cost_g <= 0:
       return  # 既に完成済み（進捗 1.0 到達フレームのレース対策）。フラッシュなし
  3. if economy.gold < cost_g:
       _flash_red(item_node, 500ms)
       return
  4. economy.gold -= cost_g
  5. EconGrid.complete_construction_now(panel_id)  ← 進捗を 1.0 に強制 → 既存完了処理発火
  6. LogManager.log_event({type:"INSTANT_BUILD", panel_id, cost_g})
  7. 金色フラッシュ 300ms（COLOR_GOLD_COIN）
```

### 5.4 建設キャンセル（F10）

```
BuildQueueUI._on_queue_item_right_clicked(panel_id):
  1. site = construction_sites[panel_id]
  2. economy.refund(site.cost)            # 支払い済みコストを全額返却
  3. EconDeckManager.return_card(site.card_id)  # 通常建物は捨て札へ、特殊建物は除外解除
  4. EconGrid.cancel_construction(panel_id)
       - construction_sites.erase(panel_id)
       - panel の建設中表示をクリア
  5. _refresh()  # 残ったキュー項目を再採番（started_at は §4.3 で連番化される）
  6. LogManager.log_event({type:"CONSTRUCTION_CANCEL", panel_id, refund: site.cost})
```

> ペナルティなし（企画書 §12.2）。返却資源量は支払い額と同一。

### 5.5 BPB 形式 効果進捗 Overlay 描画方法（F11）

> **共通仕様**: 「BPB 式 下→上塗り Overlay」は本 Sprint で 2 箇所に適用される：
> 1. **盤面の完成済み稼働建物**（本節・§6.4）: `EconBuilding._draw()` で描画。進捗値は `effect_progress_rate`
> 2. **建設キュー項目内**（§5.2・§6.2）: `BuildQueueUI` の各 PanelContainer 内 `_draw()` で描画。進捗値は `construction_progress`
>
> **Overlay ロジックの共有方針**: 描画スタイル（下→上塗り・色・αチャンネル・発動瞬間の発光）は同一だが、進捗値の出処が異なるため、共通ヘルパー関数として `EconUI.draw_bpb_overlay(canvas, rect, rate, is_stopped, flash_remaining)` を `scripts/econ_mvp/ui/EconUI.gd` に新設し、両者から呼び出す（コード重複を避けつつ各クラスの内部状態を直接共有しない＝疎結合維持）。
> Sprint 7 の建設リング型表現（円弧）は本節の対象外（盤面建設予定地の半透明シルエット＋金色リングはそのまま継承）。

実装は `EconBuilding._draw()` 内で共通ヘルパー経由で `draw_rect()` を使う（新規 Sprite ノードは作らない・既存パネル描画と同レイヤー）。

```gdscript
func _draw() -> void:
    # 既存の建物パネル描画（省略）...
    
    # 建物効果進捗 Overlay（is_built かつ effect_progress_rate > 0 のときのみ）
    if is_built and effect_progress_rate > 0.0:
        var w: float = panel_width
        var h: float = panel_height
        var rate: float = clamp(effect_progress_rate, 0.0, 1.0)
        var fill_h: float = h * rate
        var color: Color = EconMain.COLOR_ACCENT_GOLD
        color.a = 0.4
        if not is_operating:  # 停止中
            color = EconMain.COLOR_TEXT_DIM
            color.a = 0.3
        # 下から上へ塗る（y=h-fill_h から fill_h ぶん）
        draw_rect(Rect2(0, h - fill_h, w, fill_h), color, true)
    
    # 効果発動瞬間の発光（200ms）
    if effect_flash_remaining > 0.0:
        var flash_color := EconMain.COLOR_ACCENT_GOLD
        flash_color.a = 0.6 * (effect_flash_remaining / EFFECT_FLASH_DURATION_SEC)
        draw_rect(Rect2(0, 0, panel_width, panel_height), flash_color, true)
    
    # 停止理由アイコン（is_built かつ not is_operating のときのみ）
    if is_built and not is_operating and stop_reason != "":
        var icon_text: String = STOP_REASON_ICON.get(stop_reason, "❌")
        # 右上 16x16 領域に描画（Label を生成する場合は _draw() 外で _ready() に作る）
```

> **建設進捗との区別**: 建設中表示は Sprint 7 の半透明シルエット＋金色リング（円弧）を継承する。Sprint 8 の建物効果進捗は下→上塗り（矩形）。形状（円弧 vs 矩形）で識別可能。

### 5.6 ログ出力フロー（F14）

#### 周期ログ（毎 1 秒）

```
EconMain._log_periodic_snapshot():
  - 1 秒に 1 回呼ばれる（_process 内のタイマーで管理）
  - 以下を順次 LogManager.log_event() に渡す
  - timestamp は EconMain._elapsed_time（既存）を秒で出力
```

#### 各ログのキー仕様（企画書 §18.2〜§18.9 と完全一致）

| ログ種別 | type | キー | 例 |
|---|---|---|---|
| 人口ログ | `POPULATION` | timestamp, population, population_cap, population_delta, growth_blocked, food_required | `120.0s pop=150.3 cap=250 delta=+0.04 blocked=false food_required=4` |
| 食料値ログ | `FOOD` | timestamp, food_value, maintenance_cost, food_shortage_count, food_shortage_state | `125.0s food=18 maint=4 shortage_count=0 shortage=false` |
| 満足度ログ | `SATISFACTION` | timestamp, satisfaction_value, satisfaction_stage, satisfaction_slope, base_slope, population_scale_effect, population_growth_effect, building_effect, food_shortage_penalty | `126.0s sat=62 stage=満足 slope=-0.08 base=+0.03 pop_scale=-0.06 pop_growth=-0.04 building=+0.05 food_penalty=0.00` |
| 建物稼働ログ | `BUILDING_TICK` | timestamp, building_id, building_name, is_active, stop_reason, required_operation_labor, base_interval, current_interval, progress_rate, output | `130.0s building=食堂 active=false stop_reason=小麦不足 progress=0.62` |
| 建築ログ | `CONSTRUCTION` | timestamp, building_id, building_name, panel_id, queue_index, construction_started, construction_progress, construction_completed, stop_reason, required_work_labor | `80.0s construction_start building=住宅 panel=12_5 queue=1 cost=木2 石1` |
| 人手ログ | `LABOR` | timestamp, population, total_labor, operation_ratio, work_ratio, operation_labor, work_labor, operation_labor_shortage, work_labor_shortage | `120.0s pop=150 total_labor=30 op_ratio=0.7 work_ratio=0.3 op_labor=21 work_labor=9 op_shortage=false work_shortage=true` |
| 資源獲得ログ | `RESOURCE_GAIN` | timestamp, resource, amount, source_building, source_panel | `132.0s gain=食料+2 src=食堂 panel=12_5` |
| 兵力ログ | `MILITARY` | timestamp, population, satisfaction_stage, military_power, soldier_count, basic_unit_count, required_stack_count | `150.0s pop=500 stage=安定 power=44 soldiers=40 units=40 stacks=14` |
| 防衛突破ログ | `BREACH_DAMAGE` | timestamp, breached_enemy_units, population_damage, population_before, population_after, clamped_by_min_population | `210.0s breach_units=4 damage=4 pop_before=80 pop_after=76 clamped=false` |

#### 出力形式
- ファイル出力: `user://logs/run_<timestamp>.jsonl`（既存 `LogManager` に準拠）
- 画面表示: デバッグログオーバーレイ（§6.7）に直近 10 件の整形済みテキストを表示
- 整形ルール: `<timestamp>s <key>=<value> ...`（半角スペース区切り）

### 5.7 デバッグ操作（F15）

各ボタンの動作を以下で固定する。

| ボタン | 動作 |
|---|---|
| `+人口` | `economy.add_population(10)` |
| `+食料` | `economy.add_food(10)` |
| `+資源` | 全通常資源 +5（木・樹脂・石・鉄鉱石・小麦・綿花） |
| `+G` | `economy.gold += 100` |
| `満足±` | `economy.satisfaction_value += 10`（クリックで＋10、Shift+クリックで -10） |
| `人口上限+` | `economy.population_cap += 50` |
| `満足度段階強制` | クリックごとに段階を循環（満足→普通→不満→満足） |
| `建設+25%` | 全 `construction_sites` の `construction_progress += 0.25`（上限 1.0） |
| `建設100%` | 全 `construction_sites` の `construction_progress = 1.0`（即時完成） |
| `効果+25%` | 全完成済み建物の `effect_progress_rate += 0.25`（上限 1.0） |
| `疑似突破` | `EconBattle.trigger_breach(units=4)` |
| `稼働不足ON` | `_debug_force_op_shortage = !_debug_force_op_shortage` |
| `作業不足ON` | `_debug_force_work_shortage = !_debug_force_work_shortage` |
| `ログ表示ON/OFF` | `_debug_log_overlay_visible = !_debug_log_overlay_visible` |

> `_debug_force_op_shortage` が true のとき、稼働人手割当ロジックは「すべての建物を停止」とみなす（停止理由＝稼働人手不足）。`_debug_force_work_shortage` も同様。

### 5.8 ポップアップ表示挙動（F3／F4／F5）

```
_show_detail_popup(type: String, target: Variant, click_pos: Vector2):
  1. _detail_popup_type = type
  2. _detail_popup_target = target
  3. ポップアップ内容を再構築（type ごとに分岐）
  4. ポップアップ位置 = click_pos + Vector2(12, 12)
  5. 画面外補正:
     if popup_pos.x + popup_size.x > screen_width:
         popup_pos.x = click_pos.x - popup_size.x - 12  # 左反転
     if popup_pos.y + popup_size.y > screen_height:
         popup_pos.y = click_pos.y - popup_size.y - 12  # 上反転
  6. 出現アニメーション: scale 0.9 → 1.0、80ms ease-out

_close_detail_popup():
  1. _detail_popup_type = ""
  2. _detail_popup_target = null
  3. popup.visible = false

# 別対象クリック時は _show_detail_popup を再呼び出しで即時切り替え（中間状態なし）
# 何もない場所クリックで _close_detail_popup
```

---

## 6. UI 仕様詳細（Designer 企画 §4 と連携）

### 6.1 常時表示 UI（HEADER 上段）

| 項目 | 表示形式 | 既存変数（流用） | クリック挙動 |
|---|---|---|---|
| 人口 | `人口: 150k / 250k` | `_pop_label`（既存） | なし |
| 食料値 | `食料: 24` | `_status_food_label`（既存） | なし |
| 満足度段階 | `満足度: 満足` | `_status_sat_label`（既存・段階のみ表示に変更） | クリック → 満足度詳細 |
| 兵力 | `兵力: 88` | `_troop_label`（既存） | クリック → 兵力詳細 |
| 兵数 | `兵: 80` | `_soldiers_header_label`（既存） | クリック → 兵力詳細 |
| ユニット数 | `U: 80` | `_units_header_label`（既存） | クリック → 兵力詳細 |

#### 人口フォーマット関数（F2）

```gdscript
# 企画書 §6 準拠
func format_population(value: int) -> String:
    if value >= 1000:
        return "%.1fM" % (value / 1000.0)
    return "%dk" % value
# 内部人口 50 → "50k"、100 → "100k"、1000 → "1.0M"
```

### 6.2 建設キュー UI レイアウト（Designer §2.1 改訂版に準拠）

| 要素 | 値 |
|---|---|
| 配置 | 盤面左側（x=0, y=100, 幅 140, 高さ 420） |
| 上下余白 | HEADER 下端（y=80）→ キュー上端（y=100）= 20px、キュー下端（y=520）→ FOOTER 上端（y=540）= 20px |
| ヘッダー | "BUILD QUEUE"（高さ 24px、11px Bold、COLOR_TEXT） |
| 内側パディング | 上下 8px ずつ |
| キュー項目 | 各 56px（1行目 18px：番号バッジ＋アイコン＋名称 / 中央 22px：BPB 進捗 Overlay / 3行目 16px：コスト or 停止理由） |
| 項目間マージン | 4px |
| 内訳合計 | 24（ヘッダー）+ 16（パディング上下）+ 280（56×5）+ 16（マージン 4×4）= 336px / 確保 420px → 余裕 84px |
| スクロール | 5項目までスクロールなし、6項目以上は ScrollContainer（細い縦スクロールバー右端） |
| 背景 | COLOR_BG（α=0.95） |
| 枠 | COLOR_BORDER 1px |

### 6.3 建設予定地番号バッジ（F7・格上げ仕様）

**仕様**: 建設予定地パネル**左上**（パネル相対座標 x+4, y+4）に直径 **18px** の番号バッジを表示。

**配置数・順序**: 建築キューに表示されている順番（① ② ③ ④ ⑤）。
6項目以上の場合、**⑥以降は "..." で表示**（盤面の視覚的混雑を避けるため）。

**色仕様**:

| 要素 | 通常（進行中） | 停止中 | ホバー |
|---|---|---|---|
| 背景 | `Color(0.15, 0.14, 0.13, 0.8)` | 同左 | 同左 |
| 枠 | `COLOR_ACCENT_GOLD` 1px | `COLOR_TEXT_DIM` 1px | `COLOR_ACCENT_GOLD` 2px |
| 数字 | `COLOR_TEXT` 11px Bold | `COLOR_TEXT_DIM` | `COLOR_TEXT` |
| サイズ | 直径 18px | 同左 | 同左 |

**関連表示**:
盤面の建設進捗リング + BuildQueueUI 左側 アイコン + バッジの**三者で「キュー順 = 建設優先度」を視覚的に伝える**。
- BuildQueueUI 上の番号（①②③...）と盤面バッジ番号は完全に対応する
- キュー並び替え（F8）時は盤面バッジも同フレーム内で再採番される

**完了条件 C15（拡充）**:
- [ ] 建設予定地ごとに順番バッジ（直径 18px）が表示できる
- [ ] BuildQueueUI の順番（①②③...）と盤面バッジ番号が完全対応する
- [ ] 6項目以上のキュー時、⑥以降の盤面バッジは "..." で表示される
- [ ] バッジ位置がパネル左上（相対 x+4, y+4）に固定されている
- [ ] キュー並び替え（F8）時、盤面バッジが同フレーム内で再採番される

### 6.4 BPB 式 効果進捗 Overlay 表現（F11）

| 進捗率 | Overlay 表現 |
|---|---|
| 0% | 非表示 |
| 1〜99% | 下から上へ進捗率分の高さで `COLOR_ACCENT_GOLD α=0.4` を塗る |
| 100%（発動瞬間） | 200ms `COLOR_ACCENT_GOLD α=0.6→0` 全体発光、その後 0% へリセット |
| 停止中 | `COLOR_TEXT_DIM α=0.3` で塗る（高さ保持） |

### 6.5 停止理由アイコン（F12）

| 停止理由 | アイコン表記 | 表示位置 |
|---|---|---|
| 資源不足（小麦以外） | `❌資` | 建物パネル右上 |
| 小麦不足 | `❌小` | 食堂等の食料系建物パネル右上 |
| 稼働人手不足 | `❌人` | 完成済み建物パネル右上 |
| 作業人手不足 | `❌作` | 建設予定地パネル右上 ／ 建設キュー項目内 |

色は `COLOR_RED` 固定。点滅なし。

### 6.6 小型詳細ポップアップ仕様

#### 共通レイアウト
- サイズ: 240px 幅 × 可変高（最大 280px）
- 背景: `COLOR_PANEL α=0.95`
- 枠: `COLOR_BORDER 1px`
- ヘッダー: 高さ20px、12px Bold、COLOR_TEXT
- 各行: 高さ18px、左寄せラベル＋右寄せ値
- 区切り線: 内訳セクションは `COLOR_BORDER` 1px 線

#### 6.6.1 満足度詳細ポップアップ（F3）

```text
ヘッダー: 満足度詳細
段階: <stage>
値: <value>%
傾き: <slope>%/秒
─────────────────
傾き内訳
基礎: <base>%/秒
人口規模: <pop_scale>%/秒
人口増加: <pop_growth>%/秒
建築物: <building>%/秒
食料不足: <food_penalty>%/秒
合計: <total>%/秒
```
高さ: 約 200px

#### 6.6.2 兵力詳細ポップアップ（F4）

```text
ヘッダー: 兵力詳細
兵力: <power>
兵数: <soldiers>
ユニット数: <units>
必要スタック数: <stacks>
─────────────────
兵力内訳（補正があれば）
兵数由来: <base>
兵舎補正: <barracks>%
その他: なし／<text>
```
高さ: 約 160〜200px

#### 6.6.3 建物詳細ポップアップ（F5）

```text
ヘッダー: <building_name>
分類: 通常建物 ／ 特殊建物
発動: 周期発動 ／ 累計条件型 ／ 条件進捗型
状態: 稼働中 ／ 停止中
進捗: <rate>%
停止理由: <stop_reason>（停止中のみ）
─────────────────
必要稼働人手: <required_op_labor>
基礎発動間隔: <base_interval>秒
現在発動間隔: <current_interval>秒
─────────────────
効果
<effect_text>
─────────────────
足元土地
<land_text>
特殊タグ: <tag>
```
高さ: 約 200〜280px

> 建設中ポップアップは作らない。建設中状態は建設キュー＋盤面表示で完結する。

### 6.7 デバッグツールパネル（F15・開発環境のみ）

**条件**: `DEBUG_MODE = true`（ゲーム内トグルキー: [`'`]）

**サイズ**: 320×180（BUILD ブロック領域と共用）

**配置**: FOOTER 内（x=240, y=1100-1280）

| 項目 | 値 |
|---|---|
| 配置 | FOOTER 内 (x=240, y=1100-1280, 320×180)（BUILD と共用） |
| ヘッダー | "— DEBUG TOOLS —" 14px Bold |
| ボタンサイズ | 各 60×24px |
| ボタン配置 | 4 列 × 4 行（§5.7 のボタン全 14 個＋ログトグル 1 個） |
| 表示制御 | `DEBUG_MODE` フラグで本番ビルド時に非表示 |

> **【重要】FOOTER 高さ 180px 維持制約**:
>
> - FOOTER 全体の高さは **180px で固定**（Sprint 7 §6.1 で定義された恒久ルール）
> - `DEBUG_MODE = true` 時は BUILD HAND の領域を上書き表示する（高さ 180px 内に収まる）
> - `DEBUG_MODE = false` 時は非表示（本番ビルドでは BUILD HAND が表示される）
> - デバッグパネルは絶対に FOOTER 高さ（y=1100-1280 の 180px 範囲）を超えてはならない
>
> **完了条件**:
> - `DEBUG_MODE` 切替時、FOOTER の Y 範囲が 1100-1280 を超えない
> - `grep -n "FOOTER_H" scripts/econ_mvp/EconMain.gd` で 180.0 が定数定義されていることを確認

### 6.8 デバッグログオーバーレイ（F16）

| 項目 | 値 |
|---|---|
| 配置 | 画面右上 (320×200) |
| 背景 | `COLOR_BG α=0.85` |
| テキスト | 9px Regular `COLOR_TEXT`、直近 10 件 |
| トグル | `_debug_log_overlay_visible`（デフォルト OFF） |
| 表示優先度 | 詳細ポップアップ＞デバッグログオーバーレイ＞建物 Overlay＞番号バッジ＞停止理由アイコン |

### 6.9 アニメーション仕様

| 演出 | 所要時間 | 補間 |
|---|---|---|
| ポップアップ出現 | 80ms（scale 0.9→1.0） | ease-out |
| ポップアップ切り替え | 0ms（即時） | - |
| 効果 Overlay 進行 | リアルタイム | 線形 |
| 効果発動時の発光 | 200ms（α 0.6→0） | ease-in-out |
| キュー項目ホバー | 100ms（枠色変化） | 線形 |
| 即時建設成功フラッシュ | 300ms（COLOR_GOLD_COIN）| ease-out |
| 即時建設コスト計算 | `calc_instant_build_cost()` = ceil(残工数 × 5G) | - |
| 建設キャンセル | 200ms（縮小フェードアウト） | ease-in |

---

## 7. 完了条件チェックリスト

企画書 §20「完了条件」を実装可能粒度で展開した **全 40 項目**（C1〜C40）。すべて満たしたとき Sprint 8 完了とする。

### 7.1 常時表示 UI
- [ ] C1: HEADER 上段に人口・食料値・満足度段階・兵力・兵数・ユニット数の 6 項目を常時表示できる（F1）
- [ ] C2: 人口表示が `150k / 250k` 形式（k／M 単位、「人」を付けない）になっている（F2）
- [ ] C3: 常時表示 UI に満足値%／満足値傾きを表示していない（段階のみ表示）
- [ ] C4: HEADER 下段の既存資源ラベル群と人手スライダーは Sprint 7 から変更しない（既存維持）

### 7.2 詳細ポップアップ
- [ ] C5: 満足度ラベルクリックで満足度詳細ポップアップ（値%・傾き・5 項目内訳・合計）を表示できる（F3）
- [ ] C6: 兵力／兵数／ユニット数ラベルクリックで兵力詳細ポップアップ（兵力・兵数・ユニット・必要スタック数・補正内訳）を表示できる（F4）
- [ ] C7: 完成済み建物クリックで建物詳細ポップアップ（分類・発動・状態・進捗・必要人手・発動間隔・効果・足元土地・停止理由）を表示できる（F5）
- [ ] C8: 建設中建物用の詳細ポップアップを実装していない（建設キュー＋盤面表示で代替）
- [ ] C9: ポップアップは右側パネル／ボトムシートではなく、クリック位置近傍 (+12px) に出現する
- [ ] C10: ポップアップが画面外にはみ出す場合、左／上方向へ反転表示できる
- [ ] C11: 別対象クリックでポップアップ内容が即時切り替わる
- [ ] C12: 何もない場所クリックでポップアップが閉じる

### 7.3 建設キュー
- [ ] C13: 盤面左側 (140×420、x=0, y=100-520) に建設キュー UI を表示できる。HEADER 下端と FOOTER 上端それぞれに 20px の余白がある（F6）
- [ ] C14: キュー項目（高さ 56px）に建設順番号・建物アイコン・建物名・BPB 式進捗 Overlay・コスト/停止理由を表示できる。5項目までスクロールなし、6項目以上はスクロール
- [ ] C15: 建設予定地パネル左上（相対 x+4, y+4）に直径 18px の建設順番号バッジが表示できる。BuildQueueUI 順番と完全対応し、6項目以上は "..." 表示（F7・§6.3 参照）
- [ ] C16: キュー項目ドラッグで順番を入れ替えられる（10px 閾値）（F8）
- [ ] C17: キュー順変更時に建設予定地番号も即時更新される
- [ ] C18: 作業人手の割当優先順位が建設キュー順（`started_at` 昇順）に従う

### 7.4 即時建設・キャンセル
- [ ] C19: キュー項目クリックで G を消費して即時建設できる（F9）
- [ ] C20: 即時建設コストが `工数単価 5G × 残工数` で算出される（工数単価 `LABOR_COST_PER_UNIT = 5` は全建物共通の `const`、`ceil` で整数化、進捗 1.0 ピッタリ／浮動小数誤差で 1.0 を超えた場合は 0G を返す）
- [ ] C20.1: 0G（既に完成）状態でクリックされた場合、何もせず early return（フラッシュ・コスト消費なし）
- [ ] C21: G が不足している場合は赤フラッシュ 500ms で拒否される
- [ ] C22: キュー項目右クリックで建設キャンセルできる（F10）
- [ ] C23: 建設キャンセル時に支払った建設コストが全額返却される
- [ ] C24: 建設キャンセル時に建設予定地が解除される
- [ ] C25: 建設キャンセル時にキュー番号が再採番される

### 7.5 進捗表示・停止理由
- [ ] C26: 完成済み稼働建物に BPB 式 下→上塗り Overlay で効果進捗を表示できる（F11）
- [ ] C27: 効果発動瞬間に 200ms 全体発光し、進捗が 0% にリセットされる
- [ ] C28: 盤面建設予定地の進捗（リング型・Sprint 7 継承）と建物効果進捗（下→上塗り型・Sprint 8）を形状で区別できる
- [ ] C28.1: BPB Overlay 描画は盤面建物（`EconBuilding`）と建設キュー項目（`BuildQueueUI`）の両方で共通ヘルパー `EconUI.draw_bpb_overlay()` を経由する（描画ロジック重複なし）
- [ ] C29: 停止中のみ停止理由アイコン（❌資／❌小／❌人／❌作）が表示される（F12）
- [ ] C30: 通常稼働中／通常建設中は停止理由アイコンを表示しない

### 7.6 ログ・デバッグ
- [ ] C31: 9 種のログ（人口／食料値／満足度／建物稼働／建築／人手／資源獲得／兵力／防衛突破）を `LogManager` 経由で出力できる（F14）
- [ ] C32: ログは `user://logs/run_<timestamp>.jsonl` にファイル出力される
- [ ] C33: デバッグツールパネル（FOOTER 右端 320×180）から §5.7 の 14 種操作を実行できる（F15）
- [ ] C34: デバッグログオーバーレイ（画面右上 320×200）を `ログ表示ON/OFF` ボタンでトグルできる（F16・デフォルトOFF）
- [ ] C35: `DEBUG_MODE = false` で本番ビルド時にデバッグツールパネルとオーバーレイが非表示になる

### 7.7 KISS・整合性
- [ ] C36: 新規色定義を追加していない（既存 `COLOR_*` のみ使用）
- [ ] C37: 人手詳細ポップアップを新規追加していない（Sprint 7 の既存スライダー流用）
- [ ] C38: 建設詳細ポップアップを新規追加していない
- [ ] C39: 疎結合ルール遵守（`construction_sites` への直接 append 禁止・`EconGrid` のメソッド経由のみ）
- [ ] C40: `check_syntax.sh` がエラー 0 件で通過する

> チェックリスト全 40 項目（C1〜C40）に加え、追補として C20.1（0G時挙動）・C28.1（BPB Overlay 共通ヘルパー）を含む計 42 項目。実装中に各 ID のうちどれが完了したかを Implementer がコメントで明示する。

---

## 8. 依存関係・注意事項

### 8.1 Sprint 7 との依存

Sprint 8 は以下を **Sprint 7 の実装前提** とする。Sprint 7 が未完了の場合は Sprint 7 を先に完了させること。

| 依存箇所 | Sprint 7 で実装される機能 |
|---|---|
| `EconGrid.construction_sites: Dictionary` | 建設予定地データ構造 |
| `EconGrid.update_construction(delta)` | 建設進捗更新ロジック |
| `EconEconomy.get_total_labor() / get_operation_labor() / get_work_labor()` | 人手算出関数 |
| `EconEconomy.alloc_work_ratio` | 稼働／作業比率（既存） |
| `EconBuilding.is_operating: bool` | 稼働中フラグ |
| `EconBuilding.required_operation_labor: int` | 必要稼働人手 |
| Sprint 7 の建設リングゲージ表現（建設中 Overlay） | 建設進捗の視覚表現 |
| Sprint 7 の人手スライダー（LABOR ブロック） | 既存 UI 流用 |

> Sprint 7 で `is_operating` や `stop_reason` のフィールド名が変わった場合は、本書を Sprint 7 完了後に追従更新する。

### 8.2 ファイルサイズ管理

実装対象ファイルの現状と追加予測：

| ファイル | 現在行数 | Sprint 8 追加予測 | 判定 |
|---|---:|---:|---|
| `EconMain.gd` | 2452 | +400〜600 | **要分割**（既に閾値超過） |
| `EconUI.gd` | 145 | +50〜100 | OK |
| `EconBuilding.gd` | 458 | +80〜120 | 500行付近に到達 |
| `EconGrid.gd` | 960 | +100〜150 | 1100行に達する見込み |
| `LogManager.gd` | 174 | +120〜180 | OK |

#### 分割方針（必須）

1. **`scripts/econ_mvp/ui/BuildQueueUI.gd`（新規・推定 250〜350 行）**
    - 建設キュー UI の生成・更新・ドラッグ並び替え・即時建設／キャンセルのハンドラ
    - `EconMain.gd` から呼び出す疎結合な UI モジュール
2. **`scripts/econ_mvp/ui/DetailPopup.gd`（新規・推定 200〜300 行）**
    - 満足度／兵力／建物の 3 種ポップアップを共通パネルで管理
    - `_show(type, target, click_pos)` / `_close()` API
3. **`scripts/econ_mvp/ui/DebugToolsPanel.gd`（新規・推定 150〜200 行）**
    - デバッグツールパネルとデバッグログオーバーレイを統括
    - `DEBUG_MODE` フラグで一括表示制御
4. **`scripts/econ_mvp/EconLogger.gd`（新規・推定 200〜300 行）または既存 `LogManager.gd` 拡張**
    - 9 種ログのフォーマット関数を集約（`format_population_log()` 等）
    - `EconMain` 内のログ呼び出しをこのモジュールに寄せ、`EconMain.gd` の肥大化を抑える

> `EconMain.gd` への直接追記は最小限（UI モジュールのインスタンス化と `_process` 内の updater 呼び出しのみ）にとどめる。Sprint 8 完了時の `EconMain.gd` 行数増加は +200 行以内が目標。

### 8.3 疎結合ルール（必守）

- `EconGrid.construction_sites` への直接 `append` ／ `erase` ／ 内部辞書操作を禁止する。必ず `start_construction()` / `complete_construction_now()` / `cancel_construction()` / `reorder_queue()` / `update_construction()` 経由で操作する。
- `BuildQueueUI` から `EconBuilding` の内部フィールド（`hp` 等）への直接代入を禁止する。
- `DetailPopup` は表示専用とし、対象オブジェクトを変更しない（read only）。
- `LogManager` への呼び出しは `LogManager.log_event(data)` 1 関数経由で行い、`LogManager` 内部の `_file` 等に直接アクセスしない。
- 新しいクラス間連携が必要になった場合は、まず `docs/meta/adr/` に ADR を起票してから実装する。

### 8.4 用語整合性チェック

実装時に以下を確認すること（CLAUDE.md「用語統一ルール」に従う）：

- [ ] 企画書の用語（建設キュー／建設予定地／建設順番号／建物効果進捗 ...）とコード上の識別子（変数名・関数名）が一致しているか？
- [ ] 「稼働」と「作業」の対応関係が Sprint 7 の `alloc_work_ratio`（作業比率）と整合しているか？
- [ ] `EconBuilding.is_operating == false` のとき、停止理由文字列が必ず非空か？

### 8.5 既存実装との互換

- HEADER の既存ラベル（`_pop_label`、`_status_food_label`、`_troop_label` 等）は再利用する。新ラベルを増やさない。
- `_header_detail_popup` PanelContainer は流用し、内容を満足度／兵力／建物の 3 種に切り替える。
- 既存 `LogManager.log_event()` API のシグネチャを変更しない。引数 `data: Dictionary` のキー追加のみ行う。
- Sprint 7 の建設リングゲージ表現は **触らない**（視覚的整合のため）。BPB 式 Overlay は完成済み建物に対してのみ追加。

### 8.6 残論点（テストプレイ調整項目・企画書 §22）

実装は確定値で行い、テストプレイで以下を調整する：

- 即時建設コスト「工数単価 5G × 残工数」の妥当性（`LABOR_COST_PER_UNIT` 定数 1 行で調整可能にしておく）
- 総工数の値（Sprint 7 `construction_time` から引き継ぎ。Designer 例値 住宅=12 / 兵舎=40 はあくまで案、Sprint 7 の実装値 住宅=20 / 兵舎=35 と差異あり → テストプレイで Sprint 7 値か Designer 案値かを決定）
- 建設キュー幅 140px の視認性
- キュー項目高さ 56px の視認性（番号・名称・BPB 塗り・コスト/停止理由が 1 項目内で読み取れるか）
- 停止理由アイコン 1 個表示（複合原因の優先度）
- ポップアップサイズ 240×280px の情報密度
- デバッグログオーバーレイのデフォルト OFF 妥当性

調整が確定したら本書を更新する（更新日を書き換え）。

### 8.7 整合性チェック結果（2026-05-04 実施）

本要件定義書（更新版）と関連ドキュメントの整合性を以下の観点で確認した。

| 観点 | 結果 | 確認箇所 |
|---|---|---|
| 工数単価×残工数方式の全体整合 | ✅ OK | §4.4 / §6.9 アニメーション仕様 / C20 / §8.6 残論点 / Designer §4.2.1 と完全一致 |
| キュー高さ y=100-520（420px）統一 | ✅ OK | §3.1 F6 / §6.2 / C13 / §8 KISS 注記 / Designer §2.1 と一致 |
| キュー項目 56px 統一 | ✅ OK | §5.2 / §6.2 / C14 / Designer §2.1, §4.2 と一致 |
| BPB Overlay 描画ロジックの共有方針 | ✅ OK | §5.5（共通仕様注記）/ C28.1（共通ヘルパー要求）/ ファイル分割 §8.2 で `EconUI.gd` に `draw_bpb_overlay` 配置 |
| キュー進捗 = `construction_progress`、建物効果進捗 = `effect_progress_rate` の使い分け | ✅ OK | §4.1 / §5.5 / §5.2 |
| 0G（既に完成）クリック挙動 | ✅ OK | §4.4（return 0 + 注記）/ §5.3 step 2 / C20.1 |
| int/float 誤差防止 | ✅ OK | §4.4（`float()` キャスト・`<= 0.0` 判定・`ceil` 後 `int` キャスト） |
| `LABOR_COST_PER_UNIT = 5` の調整可能性 | ✅ OK | §4.4 注記（const として 1 行変更）/ §8.6 残論点 |
| Designer 例値（住宅=12 / 兵舎=40）と Sprint 7 実装値（住宅=20 / 兵舎=35）の差異明示 | ✅ OK | §4.4 注記 / §8.6 残論点（テストプレイで決定） |
| 4 ファイル分割（BuildQueueUI / DetailPopup / DebugToolsPanel / EconLogger）の妥当性 | ✅ OK | §8.2 — 各ファイル 150〜350 行で 500 行を超えない設計、`EconMain.gd` への追記は +200 行以内目標。`EconUI.gd` には BPB Overlay 共通ヘルパーを追加（既存 145 行 + 50〜100 行で OK） |
| 疎結合ルール（CLAUDE.md「疎結合ルール」） | ✅ OK | §8.3 — `construction_sites` への直接 append 禁止、`BuildQueueUI` から `EconBuilding` 内部フィールドへの直接代入禁止、`DetailPopup` は read only、`LogManager.log_event` 1 関数経由を明文化 |
| Sprint 7 BuildingSystem との疎結合 | ✅ OK | `complete_construction_now()` / `cancel_construction()` / `reorder_queue()` は `EconGrid` に新設し、`BuildQueueUI` からは公開メソッド経由のみ呼ぶ。Sprint 7 の `is_operating` / `stop_reason` / `required_*_labor` は読み取り専用で参照 |
| `LogManager.log_event()` API シグネチャ非変更 | ✅ OK | §8.5 / §4.7 — 引数 `data: Dictionary` のキー追加のみ |

#### 注意事項

1. **Sprint 7 の `construction_time` 値が「秒」か「工数」か** は実装着手時に再確認する。本要件定義書では「同値を工数単位として再解釈」とし、ロジック上の混乱を避ける（実装は `float` 値をそのまま使用、係数なし）。バランス調整は `LABOR_COST_PER_UNIT` だけで完結させる。
2. **キュー側 BPB Overlay の進捗値再利用**: `BuildQueueUI` は `construction_sites[panel_id].construction_progress` を毎フレーム読むが、これは `EconGrid` の公開ゲッター `get_build_queue_order()` 経由で配列ごと取得する形にする（Dictionary への直接アクセスを避ける）。
3. **整合性の継続維持**: Designer 企画書 (`docs/design/sprint8_designer_plan.md`) の数値変更があった場合、本書 §3.1 F6 / §4.4 / §5.2 / §5.5 / §6.2 / §6.4 / §6.9 / §7（C13・C14・C20・C28・C28.1）を併せて更新する。

---

## 9. 参照

- 企画書（確定版）: `docs/sprint8_ui_logs_debug_final_revised.md`
- Designer 企画書: `docs/design/sprint8_designer_plan.md`
- Sprint 7 要件定義書: `docs/requirements/REQUIREMENTS_SPRINT_7.md`
- 既存実装（色定数）: `scripts/econ_mvp/EconMain.gd:116-133`
- 既存実装（建物パネル描画）: `scripts/econ_mvp/EconBuilding.gd`
- 既存実装（ログ基盤）: `scripts/econ_mvp/LogManager.gd`
- 設計判断基準: `docs/design/design_principles.md`
- 用語: `docs/design/glossary.md`
- ゲーム哲学: `docs/game_philosophy.md`
- 核となる体験: `CLAUDE.md`「盤面を設計して、介入を仕込んで、答え合わせを観戦する」
