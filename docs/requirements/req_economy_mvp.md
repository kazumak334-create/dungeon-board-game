# 経済設計MVP 要件定義書

**更新日:** 2026-04-30（ビルダー廃止・ハーベスター三役制（採掘/建設/交易）・UIをバーグラフ方式に変更・EconAI target_count にROLE_BUILD追加）
**ステータス:** 実装済み（正規化版）
**対象:** MVP（対AI／将来的に同期PvP拡張）

---

## 1. 概要・コンセプト

### 1.1 ゲームコンセプト

> **「盤面を設計して、介入を仕込んで、答え合わせを観戦する」**

### 1.2 ジャンル

経済設計 × 自動戦闘 × リアルタイム戦術介入

### 1.3 対戦形式

- **MVP:** 対AI
- **将来:** 同期PvP

### 1.4 1ゲームの長さ

約5分

### 1.5 設計の核

- 採掘・建設・生産の経済ループを土台とする
- 自動戦闘をベースとし、ユニット指示・建設指示でリアルタイム介入する
- 三すくみは特攻倍率ではなく、射程・速度・耐久のパラメータ差から創発（emergent）する

---

## 2. ゲームフロー

### 2.1 フェーズ構成（合計約5分）

| 時間帯 | フェーズ名 | 主な活動 |
|--------|-----------|---------|
| 0〜1分 | 土台フェーズ | 建設指示・資源優先度・配分の設定。ハーベスター採掘開始。速攻戦略（突全振り）も成立 |
| 1〜3分 | 接敵フェーズ | ユニット衝突（中央〜敵陣）。ユニット指示・建設指示で軌道修正。資源配分スライダーはリアルタイムで調整可能 |
| 3分〜 | 決着フェーズ | 拠点攻防。勝ちに行く／耐えるの判断。資源配分・建設指示は継続して操作可能 |

**バトルフェーズ中のプレイヤー操作範囲：**

| 操作 | バトル中の可否 | 備考 |
|------|--------------|------|
| ユニット戦闘 | 完全自動（プレイヤー介入不可） | 「観戦」とはこれを指す |
| 資源配分スライダー | リアルタイムで調整可能 | 採掘方針を即座に変更できる |
| 建物建設 | 手動で配置可能 | 建設キューに登録→資源が溜まり次第自動建設 |
| ユニット指示 | 可能（§7参照） | ターゲット優先度を個別・全体で変更 |

バトルフェーズは「ユニットを観戦しながら経済を操作し続ける」フェーズとして設計する。

### 2.2 フェーズ移行条件

- 時間経過のみ（明示的なフェーズ切替UIなし）
- フェーズはあくまで設計上の目安。実プレイは連続的なリアルタイム進行

---

## 3. マップ仕様

### 3.1 構造

| 項目 | 値 |
|------|-----|
| サイズ | 12行（row 0-11）× 偶数行13列/奇数行12列（ヘックスオフセット座標） |
| グリッド形式 | ヘックスグリッド（offset座標） |
| 霧戦争 | なし |
| パネルサイズ前提 | 1080px幅（HEX_SIZEは自動計算） |

#### HEX_SIZE 自動計算式

```
HEX_SIZE = floor(panel_width / (hex_width_per_col * 13.5))
```

実装者がパネル幅・余白に応じて調整可能。基準値は 13.5（偶数行13列＋オフセット余裕）。

### 3.2 ゾーン定義（4分割）

| ゾーン名 | 行範囲 | 内容 |
|---------|--------|------|
| プレイヤー建設ゾーン | row 0-2 | プレイヤーが建物を建設可能（BASE自動配置含む） |
| プレイヤー資源ゾーン | row 0-3 | 資源タイル（WOOD/STONE/SULFUR/WHEAT）が配置される |
| 中央戦闘ゾーン | row 4-7 | 地形タイル（山岳・砂漠・平原）のみ。建設不可・資源なし |
| 敵資源ゾーン | row 8-11 | 資源タイル（敵側） |
| 敵建設ゾーン | row 9-11 | AIが建物を建設するゾーン |

注：プレイヤー資源ゾーン（row 0-3）と建設ゾーン（row 0-2）は重なる（row 0-2 は資源も建設も可能。ただし資源タイル上には建設不可）。
同様に敵側も資源ゾーン（row 8-11）と建設ゾーン（row 9-11）が重なる。

### 3.3 資源エリア

- シード値でランダム生成
- **プレイヤー資源ゾーン（row 0-3）と敵資源ゾーン（row 8-11）に同種・同数の資源を対称配置する**
- 各エリアを独立してシャッフルし、各エリアにWood/Stone/Sulfur/Wheatを配置
- 各サイド保証数：WOOD×4, STONE×4, SULFUR×4, WHEAT×2
- 中央戦闘ゾーン（row 4-7）は資源なし
- 資源タイルの地形は常に PLAIN（§3.5）

### 3.4 BASE（拠点）配置

| 項目 | 仕様 |
|------|------|
| プレイヤーBASE | ゲーム開始時に row 0 の中央列に自動配置（プレイヤー操作不要） |
| 敵BASE | ゲーム開始時に row 11 の中央列に自動配置 |
| PlaceMode.BASE | **廃止**。ゲーム開始直後からバトル準備フェーズへ即遷移 |
| 勝利条件 | 変わらず（BASE破壊 = ゲーム終了） |

中央列は偶数行（row 0, row 11 ともに偶数）13列のため、index=6（中央）が標準。

### 3.5 地形タイルシステム

`ResourceType`（資源）とは独立した属性 `TileType` を導入する。

```
enum TileType { PLAIN, MOUNTAIN, DESERT }
```

各セルは `ResourceType` と `TileType` の2つの属性を持つ。

#### 地形の効果

| 地形 | 効果 |
|------|------|
| PLAIN（平原） | 効果なし（標準セル） |
| MOUNTAIN（山岳） | ユニット通行不可（BFSでblocked扱い）、ハーベスターも通行不可、建設不可 |
| DESERT（砂漠） | ユニットの move_spd を 0.5倍にする |

#### 地形と資源の関係

- 資源タイルのセル → 地形は常に PLAIN
- 地形（MOUNTAIN/DESERT）は資源タイル以外のセルにのみ割り当て可能

### 3.6 地形生成アルゴリズム

#### Step 1: 資源タイル配置（row 0-3 / row 8-11）

- §3.3 のロジックを継承（WOOD×4, STONE×4, SULFUR×4, WHEAT×2 per side, シード固定でシャッフル）
- 配置されたセルの TileType = PLAIN

#### Step 2: 地形タイル生成（非資源セル）

| 行範囲 | 地形分布 |
|--------|---------|
| row 0-3 / row 8-11 の非資源セル | PLAIN のみ（建設ゾーンなのでフラット） |
| row 4-7（中央戦闘ゾーン）の全セル | Mountain / Desert / Plain を比率で生成 |

**中央ゾーン(row 4-7)の比率（デフォルト値）：**

| 地形 | 比率 |
|------|------|
| MOUNTAIN | 35% |
| DESERT | 25% |
| PLAIN | 40% |

比率はデバッグUI（§9.5）で動的に変更可能。

#### Step 3: 山岳経路保証（必須）

生成後、以下のBFSチェックを行う：

1. row 3 の各セルから row 8 の各セルへの到達可能性をチェック
2. MOUNTAIN セルはブロック扱い（BFS で skip）
3. 到達不可能な場合：ブロッキング山岳を1つずつ PLAIN に変換し、BFSを再チェック（繰り返し）
4. 最終的に必ず1本以上の経路を保証する

実装ファイル：`scripts/econ_mvp/EconGrid.gd`（地形生成・経路保証ロジック）

---

## 4. 資源システム仕様

### 4.1 採掘資源（4種）

| 資源 | 対応建造物 | 生産ユニット |
|------|-----------|------------|
| 木材 | 兵舎 | 突（Attacker・近接高速） |
| 石材 | 砦 | 守（Tank・近接高耐久） |
| 硫黄 | 工房 | 崩（Breaker・遠距離範囲） |
| 小麦（採掘） | - | - |

※小麦はフィールド上の小麦タイルでハーベスターが採掘可能。農村の小麦生産（§8）とは別の経路。

### 4.2 特殊資源

| 資源 | 用途 | 生産元 | 備考 |
|------|------|--------|------|
| 小麦 | ユニット維持コスト | 農村（+2/5秒）・フィールド採掘（§4.1） | 農村が主要生産元。フィールドの小麦タイルも採掘可能 |

### 4.3 採掘レート（仮置き・PoC後に調整）

| 項目 | 値 |
|------|-----|
| ハーベスター1体の採掘速度 | 1資源 / 5秒 |
| 採掘対象 | 担当資源（配分比率と優先度に従い自動決定） |

### 4.4 ハーベスター役割割り当て（target_count 直接指定）

- **target_count:** 各役割・資源に何人割り当てるかを直接人数で指定する Dictionary
- **役割一覧:**

| キー | 意味 |
|------|------|
| ResourceType.WOOD | 木材採掘 |
| ResourceType.STONE | 石材採掘 |
| ResourceType.SULFUR | 硫黄採掘 |
| ResourceType.WHEAT | 小麦採掘 |
| ROLE_BUILD (=10) | 建設担当（未建設建物に向かい建設進捗を蓄積） |
| ROLE_TRADE (=11) | 交易担当（将来実装・現在はidle） |

- **割り当てアルゴリズム:** target_count から割り当てリスト（assignment）を生成し、ハーベスターindex でラウンドロビン割り当て
- **デフォルト値（プレイヤー）:** WOOD=1, STONE=1, SULFUR=1, WHEAT=0, ROLE_BUILD=0, ROLE_TRADE=0
- ハーベスターは自分の役割に応じて採掘・建設・待機を自動切替する

---

## 5. 建造物仕様

### 5.1 一覧

| 建造物 | 建設コスト | 機能 | 生産レート | HP |
|--------|-----------|------|-----------|-----|
| 兵舎 | 木材 8 | 突ユニット自動生産 | 木材 3 / 8秒 | 100 |
| 砦 | 石材 6 | 守ユニット自動生産 | 石材 3 / 10秒 | 200 |
| 工房 | 硫黄 6 | 崩ユニット自動生産 | 硫黄 3 / 12秒 | 100 |
| 農村 | 木材4+石材3+小麦2 | 小麦+2/5秒・ハーベスター+1/20秒 | - | 80 |
| 拠点 | 初期配置（建設不可） | 破壊されたら敗北 | - | 500 |

### 5.2 建造物の挙動

- 建物は攻撃対象になる
- 建物単体は攻撃能力なし
- バトル中にリアルタイムで建設指示を出せる

### 5.3 建設UI／ハーベスター建設方式（ビルダー廃止）

- **建設UI:** 建物タイプ選択 → マップクリックで設置場所指定
- **建物はis_built=false（ブループリント状態）で配置される**
- **配置はコスト不要・無料でキューに追加される**
- **ROLE_BUILD に割り当てられたハーベスターが最近傍の未建設建物に向かい、到着後 build_progress を蓄積する**
- **到着後、`economy.can_afford(cost)` = true のときのみ build_progress を蓄積する**
- **資材不足の場合は build_progress 停止（値は保持したまま）。資材回復後に自動再開**
- **build_progress >= required_construction 達成時に `economy.spend(cost)` を実行して is_built = true になる**
- ブループリント状態の建物は半透明表示

### 5.4 農村の建設制約

- VILLAGE は「小麦タイル（ResourceType.WHEAT）に隣接するセル」にのみ建設可能
- プレイヤーが非隣接セルをクリックした場合：ステータスラベルに「農村は小麦マスに隣接して建設してください」と表示、建設しない
- AI は建設時に計画位置の小麦隣接チェックを行い、無効なら敵建設ゾーン（row 9-11）内で小麦隣接の最近セルを動的探索して建設する。有効位置が見つからない場合はそのビルドオーダーエントリをスキップする

### 5.5 建設ゾーン制限（共通）

- プレイヤーの建設操作は `cell.y <= 2`（row 0-2）のみ許可。`cell.y > 2` の場合はエラー（旧仕様: `cell.y > 4`）
- MOUNTAIN セル（TileType.MOUNTAIN）への建設は不可。資源タイル上への建設も不可
- 上記制約はEconMain.gdの建設フローでチェック

### 5.5.1 建設制限（BASEからの距離・資源タイル隣接）

**BASEから半径3hex以内制限：**
- プレイヤー側：プレイヤーBASE（Vector2i(6, 0)）から hex_distance が 3 以下のセルのみ建設可能
- AI側：敵BASE（Vector2i(6, 11)）から hex_distance が 3 以下のセルのみ建設可能
- 距離オーバーの場合、プレイヤー側はログ「BASEから半径3hex以内にのみ建設できます」を表示して建設しない

**各建物の資源タイル隣接条件：**
| 建物 | 隣接条件 |
|------|---------|
| 兵舎（BARRACKS） | 制約なし |
| 要塞（FORTRESS） | 制約なし |
| 工房（WORKSHOP） | 制約なし |
| 農村（VILLAGE） | WHEAT タイルに隣接するセルにのみ建設可能（§5.4 の既存制約を継承） |

- プレイヤーが農村を非隣接セルにクリックした場合：ログに「農村は小麦タイルに隣接して建設してください」を表示し、建設しない
- AI側：VILLAGEを建設する際、計画位置が条件を満たさない場合は敵建設ゾーン（row 9-11）内でBASEから半径3hex以内かつWHEAT隣接のセルを動的探索する。有効位置が見つからない場合はスキップ
- AI側：BARRACKS/FORTRESS/WORKSHOPは資源隣接チェックなし（半径3hex以内チェックのみ）

**チェック順序（EconMain.gd）：**
1. セル有効性（is_valid_cell）
2. 山岳チェック（is_mountain）
3. 建設ゾーンチェック（cell.y <= 2）
4. 占有チェック（ハーベスター・建物）
5. Village数上限チェック（§5.4）
6. **自建物から半径3hex以内チェック**
7. **VILLAGE のみ：WHEAT タイル隣接チェック**

※ 資源コストチェックは配置時には行わない。コストはビルダーが現地完成時に支払われる（§5.6）。

### 5.6 ハーベスター建設仕様（ビルダー廃止・ROLE_BUILD方式）

**ビルダーユニット（EconBuilder）は廃止。ハーベスターが三役（採掘/建設/交易）を兼任する。**

#### ROLE_BUILD ハーベスターの挙動

| 項目 | 仕様 |
|------|------|
| 割り当て方法 | target_count[ROLE_BUILD] に人数を設定 |
| construction_rate | 1.0 pt/秒（固定） |
| 建設対象 | 最近傍の未建設（is_built=false）味方建物 |
| 建設完了後 | 次の未建設建物へ自動移動 |

#### 建物の required_construction

| 建物 | required_construction |
|------|----------------------|
| VILLAGE | 5.0 |
| BARRACKS | 5.0 |
| FORTRESS | 8.0 |
| WORKSHOP | 8.0 |

#### 建設進捗

- `build_progress: float = 0.0` を各建物に追加
- ROLE_BUILD ハーベスターが建物グリッド座標に到着し、かつ `economy.can_afford(cost)` = true のときのみ毎秒 `CONSTRUCTION_RATE` を加算
- 資材不足の場合は build_progress を停止（値は保持）。資材回復後に自動再開
- `build_progress >= required_construction` で `economy.spend(cost)` を実行して `is_built = true`

#### 初期農村配置

- ゲーム開始時、プレイヤー側とAI側それぞれで小麦隣接タイルに農村を1棟自動配置する（is_built=true）
- これにより初期状態からハーベスター補充が可能になる

---

## 6. ユニット仕様

### 6.1 ユニット数値表

| ユニット | HP | ATK | SPD | move_spd | 射程 | min_range |
|---------|-----|-----|-----|----------|------|-----------|
| 突（Attacker） | 80 | 20 | 1.0 | 0.15 | 1 | 0 |
| 守（Tank） | 200 | 25 | 0.5 | 0.10 | 1 | 0 |
| 崩（Breaker） | 70 | 35 | 0.25 | 0.12 | 3 | 2 |

- **HP:** 体力
- **ATK:** 攻撃力
- **SPD:** 攻撃速度（1/秒）。攻撃間隔 = 1/SPD
- **射程:** 攻撃可能な最大距離（ヘックス）
- **min_range:** 攻撃可能な最小距離（ヘックス）。これ未満には攻撃不能
- **move_spd:** 移動速度（秒/タイル換算の係数）。値が大きいほど移動が速い

### 6.2 三すくみ（emergent・特攻倍率なし）

| 関係 | 結果 | 理由 |
|------|------|------|
| 突 > 崩 | 突勝ち | 突が速く接近し、崩のmin_range=2圏内に入って攻撃不能化 |
| 守 > 突 | 守勝ち | 守のHPとDPS総量が突を圧倒 |
| 崩 > 守 | 崩勝ち | 崩の射程3で守の射程1の外から一方的に攻撃 |

**重要:** 特攻倍率は持たない。射程・速度・耐久のパラメータ差から創発する三すくみとする。

### 6.3 デフォルトAI（ターゲット優先度）

```
優先度0: 敵BASE（最優先）
優先度1: 敵生産建物（Barracks/Fortress/Workshop/Village）
優先度2: 敵戦闘ユニット（UnitType 0/1/2）
優先度3: 敵非戦闘員（Harvester/Builder）
```

- 同優先度内では最短距離を優先
- ターゲット死亡時、同優先度ロジックで自動再選択
- EconUnitに `target_priority: int`（0=標準/デフォルト）フィールドを追加
- target_priorityは全体一括ターゲット優先度UIで切り替え可能

#### ターゲット優先度プリセット

| プリセット名 | 優先順序 |
|-----------|---------|
| 標準 | BASE > 建物 > ユニット > 非戦闘（デフォルト） |
| 前線制圧 | ユニット > 建物 > BASE > 非戦闘 |
| 経済破壊 | 建物 > BASE > ユニット > 非戦闘 |

---

## 7. バトル中介入仕様（RimWorldライク）

### 7.1 ユニット指示一覧

| 指示 | 挙動 |
|------|------|
| ユニット狙い | 最近傍敵ユニットを攻撃（デフォルト） |
| ハーベスター狙い | 敵ハーベスターを優先攻撃 |
| 対象を守る | 指定ユニット／建物に追従。接敵時はユニット優先 |

### 7.2 指示の与え方

- **全体一括指示** ＋ **個別振り分け**の両対応
- ターゲットが死亡した場合、同指示の意図に従って次ターゲットを自動選択
- **UI:** クリック選択（RimWorldスタイル）

#### 操作フロー

1. グリッド上の自ユニットをクリック → 選択状態（ハイライト）
2. 画面に指示ボタンが表示される：「ユニット狙い」「ハーベスター狙い」「守る」
3. 「守る」押下 → ハイライトモードに移行（カーソル変化・味方セルのみクリック可能）
4. 守る対象（味方ユニットor建物）をクリック → 指示確定
5. 対象が死亡した場合、「守る」指示は解除されデフォルト（ユニット狙い）に戻る

#### 全体一括指示

- パネルに「全体：ユニット狙い」「全体：ハーベスター狙い」ボタンを配置
- 個別指示が上書きされていないユニット全員に適用される

#### ターゲット優先度（全体切り替え）

- 左パネルに「Target Priority」セクションを追加
- ボタンで以下の3プリセットを切り替え（全プレイヤーユニットに一括適用）：
  - 標準（BASE > 建物 > ユニット > 非戦闘）← デフォルト
  - 前線制圧（ユニット > 建物 > BASE > 非戦闘）
  - 経済破壊（建物 > BASE > ユニット > 非戦闘）
- EconUnit.target_priority（int 0-3）を書き換えることで優先度が変わる
- EconBattle.spawn_player_unit 経由でスポーンされた新規ユニットにも現在のプリセットを適用

### 7.3 ハーベスター（特殊ユニット）

| 項目 | 仕様 |
|------|------|
| 役割 | 非戦闘員。資源エリアへ移動して採掘 |
| 攻撃可能 | 不可（攻撃手段を持たない） |
| 被攻撃 | 攻撃対象になる（敵ユニットに狙われる） |
| 採掘対象 | 自動決定（配分比率と優先度に従う） |
| 補充 | 農村が20秒ごとに+1 |
| 役割上の意義 | 経済の逆転機構（負けていても農村があれば再起可能） |

---

## 8. 小麦システム

### 8.1 数値仕様

| 項目 | 値 |
|------|-----|
| 消費 | ユニット総数 × 0.5 / 5秒 |
| 生産 | 農村1棟につき +2 / 5秒 |
| 初期小麦 | 10 |
| 不足時 | 戦闘ユニットがランダムで脱落（養えない分の戦闘ユニット数） |

### 8.2 設計意図

- ユニットを増やしすぎると小麦が枯渇し戦闘ユニットが脱落する
- 軍備拡張と経済維持のトレードオフを生む

---

## 9. UI仕様

### 9.1 経済UI（バーグラフ方式・直接人数指定）

```
[Wood ][Stone][Sulfur][Wheat][Build][Trade]
  2      1      1       0      1      0    ← 各役割の人数（直接 +/- ボタンで増減）
```

- **バーグラフ形式（Civ風）:** 各役割・資源を横並びの棒グラフで表示
- **直接人数指定:** +/-ボタンで各役割のハーベスター数を直接増減
- **合計人数チェック:** 全役割の合計が在籍ハーベスター総数に一致するよう制約
- 小麦（WHEAT）・建設（ROLE_BUILD）・交易（ROLE_TRADE）も同一UIで管理
- バトル中もリアルタイムで変更可能

### 9.2 建設UI

- 建物タイプ選択ボタン → マップクリックで設置場所指定
- 資源不足時は建設キューに登録され、資源が溜まり次第自動建設

### 9.3 ユニット指示UI

- クリック選択（RimWorldスタイル）
- 全体一括指示／個別指示の両対応

### 9.4 マップ表示

- 12行（row 0-11） × 偶数行13列/奇数行12列のヘックスグリッド（オフセット座標）
- 霧戦争なし（全マップ常時可視）
- 地形タイル（PLAIN/MOUNTAIN/DESERT）を視覚的に区別表示
- 資源タイルは地形PLAIN上に資源アイコンを重ねて表示

### 9.5 デバッグUI：地形比率コントロール

EconMain.gd に以下のデバッグUIを配置する。中央戦闘ゾーン（row 4-7）の地形比率を動的調整可能。

| コントロール | 型 | 範囲 | 初期値 | 説明 |
|------------|-----|------|--------|------|
| mountain_ratio | HSlider + Label | 0-100 | 35 | 山岳比率（%） |
| desert_ratio | HSlider + Label | 0-100 | 25 | 砂漠比率（%） |
| plain_ratio | Label のみ | 0-100 | 40 | 残り（自動計算 = 100 - mountain - desert） |
| [マップ再生成] | Button | - | - | クリックで現在の比率で地形を再生成 |

#### 制約

- `mountain_ratio + desert_ratio <= 100`
- 超えた場合は `desert_ratio` をクランプ（`100 - mountain_ratio` に制限）
- 再生成時は資源配置（§3.3）も同時に再シャッフル可能（実装者判断）
- BASEは固定位置（row 0/row 11 中央）から再配置されない

実装ファイル：`scripts/econ_mvp/EconMain.gd`

### 配分プリセットボタン

- 線分配分バーの上部に4つのプリセットボタンを横並びで表示
- ボタンを押すと線分バーのハンドル位置が即座に切り替わる（アニメーションなし）
- EconEconomy の alloc_wood/stone/sulfur/wheat に即時反映

| ボタン名 | WOOD | STONE | SULFUR | WHEAT | 戦略意図 |
|---------|------|-------|--------|-------|---------|
| 🌾 初心者 | 30 | 20 | 10 | 40 | 小麦優先→農村建設→安定収入 |
| ⚔️ 突特化 | 55 | 15 | 20 | 10 | 兵舎連打→突ユニット量産 |
| 🛡️ 守特化 | 20 | 50 | 10 | 20 | 要塞優先→守ユニットで前線維持 |
| 🔨 崩特化 | 25 | 10 | 55 | 10 | 工房→崩ユニットで敵設備破壊 |

- 実装ファイル: `scripts/econ_mvp/EconMain.gd`
- alloc合計が100になるよう正規化してから EconEconomy に反映

---

## 10. 勝敗条件

| 条件 | 結果 |
|------|------|
| 相手の拠点を破壊 | 勝利 |
| 自分の拠点を破壊される | 敗北 |

- 拠点HP: 500

---

## 11. MVP外（将来実装）

| 項目 | 概要 |
|------|------|
| ネットワーク同期 | 同期PvP対応 |
| 鉄鉱石・装備システム | 第4資源と装備によるユニット強化 |
| 飛行ユニット・属性システム | 縦方向の戦術軸・属性相性 |
| マップ拡張 | サイズ・地形種類の追加 |
| AI相手の高度化 | フェーズ2でAIを段階的に強化 |

---

## 12. 検証論点（PoC後に確認）

| # | 論点 | 確認方法 |
|---|------|---------|
| 1 | 三すくみ実証（混成編成でも機能するか） | 突／守／崩を混成した編成同士で対戦し、極端な一強が発生しないかを確認 |
| 6 | 5分ゲームのフェーズ配分（実際の体感） | 0-1分土台／1-3分接敵／3分〜決着の配分が体感的に成立するか観察 |

---

## 13. 制約・注意事項

### 13.1 設計文書との整合性

- 本要件は `docs/GAME_DESIGN.md` および `docs/game_philosophy.md` の核となる体験「盤面を設計して、介入を仕込んで、答え合わせを観戦する」を前提とする
- 既存の廃止済み設計（盤面召喚・時間経過マナ回復・アクティブスキル等）を復活させない

### 13.2 用語統一

- `spd`（速度）= 1/秒 として扱う（`interval` 等の逆数概念を混在させない）
- 新フィールド追加時は本要件定義書および `GAME_DESIGN.md` 双方を更新する

### 13.3 数値の取り扱い

- 本書記載の数値（採掘レート・建設コスト・生産レート・HP/ATK/SPD等）はPoC前の仮置きである
- PoC後にバランス調整を行い、確定値は本書を直接更新（新ファイルは作らない）

---

## 14. 参照

- `docs/GAME_DESIGN.md`（設計・最優先）
- `docs/game_philosophy.md`（ゲーム哲学・判断基準）
- `docs/design/design_principles.md`（設計判断基準）
- `docs/design/glossary.md`（用語定義）
- `CLAUDE.md`（開発ルール）

---

## 15. ミラーAI仕様

### 15.1 概要
- 敵側が自律的に経済を運営する（採掘→建設→ユニット生産）
- プレイヤーと同じ経済ロジックを使い、固定ビルドオーダーで動作する
- 再現性を確保するため完全決定的（ランダムなし）

### 15.2 初期状態
- 敵ハーベスター: 2体（敵資源ゾーン内、row 10 付近に配置。具体座標は実装者判断）
- 敵拠点: row 11 の中央列（index=6）に自動配置（§3.4）
- 敵の初期資源: Wood=0, Stone=0, Sulfur=0, Wheat=10（プレイヤーと同じ初期小麦）

### 15.3 ビルドオーダー（固定・順番に建設）
12行マップ用に更新。敵建設ゾーンは row 9-11。

| 順番 | 建物 | 位置 |
|------|------|------|
| 1 | Barracks | (3, 10) |
| 2 | Village | (7, 10) |
| 3 | Barracks | (3, 9) |
| 4 | Fortress | (7, 9) |
| 5 | Workshop | (5, 10) |

- 資源が溜まり次第、順番に自動建設
- 5番完了後はループしない

### 15.4 AI経済設定（target_count）

```gdscript
economy.target_count = {
    ResourceType.WOOD: 1,
    ResourceType.STONE: 1,
    ResourceType.SULFUR: 0,
    ResourceType.WHEAT: 0,
    ROLE_BUILD: 1,  # 3体目以降のハーベスターが建設担当
}
```

- 初期2体：WOOD採掘 + STONE採掘
- 3体目以降：ROLE_BUILD（建設担当）→ ビルドオーダーのブループリントへ向かう
- SULFUR/WHEAT は後続ハーベスターが追加されたとき動的に調整することを想定（将来）
- ※プレイヤーデフォルト（§4.4）とは異なる設定

### 15.5 実装方針
- `scripts/econ_mvp/EconAI.gd` を新規作成
- `EconBattle.gd` にAI更新を組み込む
- `EconMain.gd` でAIの初期セットアップを行う

---

## 将来実装機能（スコープ外・Sprint 2以降）

### F-01: 配分プリセット（Sprint 2）
- プリセットボタン4種：初心者（小麦優先）、突特化、守特化、崩特化
- ボタン1クリックで全スライダーを一括変更
- 初心者プリセット例：WHEAT=40, WOOD=30, STONE=20, SULFUR=10
- 突特化例：SULFUR=50, WOOD=30, STONE=15, WHEAT=5
- 守特化例：STONE=40, WOOD=30, WHEAT=20, SULFUR=10
- 崩特化例：WOOD=40, SULFUR=30, STONE=20, WHEAT=10

### F-02: プレイヤー独自配分の保存（Sprint 3以降）
- プレイヤーが設定した配分比率をローカルに保存
- 次ゲーム開始時に復元


### F-04: 綿花・鉄鉱石リソース（Sprint 3以降）
- 綿花（Cotton）：生産ユニット種類を拡張
- 鉄鉱石（Iron Ore）：重装ユニット・要塞系建設に必要

### F-05: 鉄鉱石×建物派生選択システム（Sprint 3）

企画Agent評価：「核となる体験と整合性が最も高い拡張」

#### 基本コンセプト
- 鉄鉱石（Iron Ore）を消費して建物を1段階「派生」させる
- 派生はプレイヤーが能動的に選択（バトル準備フェーズ）
- ランダム解放は採用しない（設計行為を薄めるため）

#### 建物派生例（案）
| 元建物 | 派生A | 派生B |
|--------|-------|-------|
| 兵舎 | 突特化兵舎（生産速度+、コスト+） | 突崩複合兵舎（崩ユニットも生産） |
| 要塞 | 重要塞（HP2倍、生産コスト-） | 突守複合要塞（突ユニットも生産） |
| 工房 | 崩特化工房（攻城力+） | 崩守複合工房（守ユニットも生産） |

#### 3秒ルール適合方針
- 派生後は建物の色・アイコンが変化（見た目で判別可能）
- 数値強化のみ（見えない）は採用しない

#### 綿花との関係
- 綿花（Cotton）は「バフ建物の素材」として不採用（3秒ルール違反）
- 代替案：鉄鉱石の派生コストの一部として綿花を組み込む、または新ユニット種別の素材とする
- 詳細は Sprint 3 設計時に企画Agentと再協議

#### 前提条件
- EconGrid に ResourceType.IRON 追加
- 鉄鉱石タイル：各サイド2枚（WHEATと同様）
- ハーベスターが採掘（既存採掘ロジックを流用）

---

## §16. アーキテクチャ規約（疎結合）

**更新日:** 2026-04-29

### spawn メソッドの一元化
EconBattle がユニット・建物の生成と配列管理を完全に担う。
外部クラスは EconBattle のメソッドを呼び出すのみ。直接配列操作は禁止。

| メソッド | 責務 |
|---------|------|
| `spawn_enemy_unit(utype, pos)` | 敵ユニット生成＋enemy_units管理 |
| `spawn_enemy_harvester(pos, economy)` | 敵ハーベスター生成＋enemy_harvesters管理 |
| `register_enemy_building(b)` | 敵建物をenemy_buildingsに登録＋_gridに追加 |
| `spawn_player_harvester(pos, economy)` | プレイヤーハーベスター生成＋player_harvesters管理 |
| `register_player_building(b)` | プレイヤー建物をplayer_buildingsに登録＋_gridに追加 |

### 呼び出し元の変更
- EconAI.on_unit_produced → EconBattle.spawn_enemy_unit / spawn_enemy_harvester を呼ぶ
- EconAI.update（建設キュー） → EconBattle.register_enemy_building を呼ぶ
- EconMain._spawn_harvester_at → EconBattle.spawn_player_harvester を呼ぶ
- EconMain._place_building → EconBattle.register_player_building を呼ぶ
- EconMain._setup_initial_entities → 同上


---

## §17. 合意済み拡張仕様（2026-04-29追加）

### §17.1 建設可能エリアの可視化（Civ風常時境界線 + 建設時塗りつぶし）

#### 境界線グロー（常時表示）
- PlaceMode に関わらず常時、プレイヤー建物から hex_distance <= 3 のセル群の外縁に境界線グローを描画
- 外側グロー：幅5px、Color(0.4, 0.8, 1.0, 0.45)
- コア線：幅2px、Color(0.6, 0.9, 1.0, 0.9)
- EconMain._update_build_highlight() は毎フレーム呼び出し、PlaceMode.NONE でも highlight_cells（境界線用）を更新する
- セル塗りつぶし（alpha=0.20）は **建設モード時のみ**（PlaceMode != NONE のとき）

#### 資源タイル強調表示（建設モード時のみ）
建設ボタン選択中、選択中の建物種に対応する資源タイルを枠線で強調表示する。
EconGrid に `resource_highlight_type: int`（ResourceType値）を追加し、EconMain がセットする。

| 建物 | 強調する資源タイル | 枠線色 |
|------|----------------|-------|
| 兵舎（BARRACKS） | 木材（WOOD） | Color(1.0, 0.5, 0.0, 0.9)（オレンジ） |
| 要塞（FORTRESS） | 石材（STONE） | Color(0.7, 0.7, 0.7, 0.9)（灰色） |
| 工房（WORKSHOP） | 硫黄（SULFUR） | Color(1.0, 0.9, 0.0, 0.9)（黄色） |
| 農村（VILLAGE） | 小麦（WHEAT） | Color(0.2, 0.9, 0.2, 0.9)（緑） |

- 枠線幅: 3px
- PlaceMode が NONE のとき resource_highlight_type = ResourceType.NONE（強調なし）
- EconGrid._draw() 内でプレイヤー資源ゾーン（row 0-3）の対応資源タイルに枠線を追加

#### 建設可能条件（セル塗りつぶし対象）
1. 既存プレイヤー建物のいずれかから hex_distance <= 3
2. 山岳(MOUNTAIN)不可・占有不可
3. VILLAGEのみ WHEAT タイル隣接が必要

- 実装ファイル：EconGrid.gd（_draw 内の境界線 ＋ 資源枠線描画）＋ EconMain.gd（highlight_cells と resource_highlight_type を EconGrid に渡す）

### §17.2 建設制限「自建物から半径3」

- 旧仕様：プレイヤーBASE固定位置（Vector2i(6,0)）から hex_distance <= 3
- 新仕様：プレイヤーの既存建物（player_buildings）のいずれかから hex_distance <= 3 であればOK
- 変更対象：EconMain.gd の _place_building
- AI側：EconAI.gd の建設キュー処理で敵建物のいずれかから hex_distance <= 3 に変更

### §17.3 初期ハーベスターを2体に

- プレイヤー側：ゲーム開始時にハーベスター2体を初期配置（EconMain._setup_initial_entities）
- AI側：既に2体配置済み（変更なし）
- プレイヤー初期ハーベスター位置：実装者判断（BASE付近の有効セル）

### §17.4 空腹システム（EconUnit）

#### EconUnit.gd への追加フィールド
- hunger: float = 10.0
- hunger_max: float = 10.0
- HUNGER_CONSUME_INTERVAL: float = 5.0（5秒ごと小麦1消費）
- HP_DECREASE_RATE: float = 2.0（hunger=0時のHP減少量/秒）

#### ロジック（EconUnit.update 内）
- 5秒ごと：economy.wheat >= 1 なら economy.spend({"wheat":1}) して hunger = hunger_max
- economy.wheat == 0 なら hunger を 1 減らす
- hunger <= 0 なら hp -= HP_DECREASE_RATE * delta

#### EconUnit._draw への追加
- hunger <= 5 かつ > 0：ユニット上部に黄色の円（radius=5）表示
- hunger <= 0：ユニット上部に赤色の円（radius=5）表示

#### EconBuilding.gd の変更
- _update_barracks / _update_fortress / _update_workshop から economy.wheat > 0 チェックを削除
- 小麦チェックはユニット側（空腹システム）に一元化

#### hunger が機能するために必要な変更
- EconUnit.update のシグネチャに economy: EconEconomy を追加
- EconBattle.gd でユニット update 呼び出し時に economy を渡す（player: _economy, enemy: ai.economy）

---

## §18. 非戦闘ユニット逃走行動（2026-04-29追加）

### 対象
- ハーベスター（EconHarvester.gd）のみ（**EconBuilder.gdは廃止済み**）

### 逃走条件
- 敵の戦闘ユニット（EconUnit）が半径 FLEE_RADIUS = 3 hex 以内に存在する場合

### 逃走行動
- 通常行動（採掘・建設・交易待機）を中断
- 最も近い敵戦闘ユニットから最も遠ざかる隣接セルに移動する
- 敵が半径3hex外に出たら通常行動に戻る

### 実装仕様

#### EconHarvester.gd
- `_is_fleeing: bool` フラグ
- `update(delta, grid, all_units, enemy_units, buildings, total_harvesters)` シグネチャ
- `update()` 冒頭で逃走チェック → `_is_fleeing` セット
- 逃走中は採掘・建設ロジックをスキップし `_flee_move()` を呼ぶ

#### EconBattle.gd の呼び出し
- プレイヤー: `h.update(delta, grid, all_movable, enemy_units, player_buildings, alive_count)`
- 敵: `h.update(delta, grid, all_movable, player_units, enemy_buildings, alive_count)`

---

## 領土境界線表示改善

**更新日:** 2026-04-29
**対象:** EconGrid.gd, EconMain.gd

### 概要
個別建物半径の境界線描画から、全建物の和集合外周描画に変更する。内側の辺は描画せず外周辺のみ表示する。

### 実装対象

1. `scripts/econ_mvp/EconGrid.gd`
   - `var enemy_territory_cells: Dictionary = {}`（新規追加、highlight_cells の直後）
   - `_draw_highlight_borders()` を `_draw_territory_border(cells: Dictionary, color: Color)` に置き換え
   - `_draw()` 内の呼び出しを2回（プレイヤー水色・敵赤）に変更

2. `scripts/econ_mvp/EconMain.gd`
   - `_update_build_highlight()` の highlight_cells 計算: row 0-2 フィルタを除去し、player_buildings 全体から半径3の和集合に変更
   - 敵領土計算を追加: enemy_buildings から半径3の和集合 → `_grid.enemy_territory_cells`
   - fill_cells（塗りつぶし）はrow 0-2フィルタ維持・変更なし

### 実装詳細

#### EconGrid.gd 変更1: フィールド追加

highlight_cells 宣言の直後に追加:
```gdscript
var enemy_territory_cells: Dictionary = {}  # Vector2i -> true
```

#### EconGrid.gd 変更2: _draw_highlight_borders を置き換え

既存の `_draw_highlight_borders()` を削除し、以下の汎用関数に置き換える:
```gdscript
func _draw_territory_border(cells: Dictionary, color: Color) -> void:
	if cells.is_empty():
		return
	var edge_pairs := [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0]]
	var dirs_even := [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(-1, -1), Vector2i(0, -1),
		Vector2i(-1, 1), Vector2i(0, 1)
	]
	var dirs_odd := [
		Vector2i(-1, 0), Vector2i(1, 0),
		Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(0, 1), Vector2i(1, 1)
	]
	for pos in cells:
		var col: int = pos.x
		var row: int = pos.y
		var center := hex_to_pixel(col, row)
		var corners := _get_hex_corners(center)
		var dirs := dirs_even if row % 2 == 0 else dirs_odd
		for i in range(6):
			var nb_pos: Vector2i = pos + dirs[i]
			if not cells.has(nb_pos):
				var ep: Array = edge_pairs[i]
				var p0: Vector2 = corners[ep[0]]
				var p1: Vector2 = corners[ep[1]]
				draw_line(p0, p1, Color(color.r, color.g, color.b, 0.4), 6.0)
				draw_line(p0, p1, Color(color.r, color.g, color.b, 0.9), 2.0)
```

#### EconGrid.gd 変更3: _draw() 内の呼び出し変更

```gdscript
# 変更前
_draw_highlight_borders()

# 変更後
_draw_territory_border(highlight_cells, Color(0.4, 0.8, 1.0))
_draw_territory_border(enemy_territory_cells, Color(1.0, 0.3, 0.3))
```

#### EconMain.gd 変更: _update_build_highlight() の highlight_cells 計算部分

既存の highlight_cells 計算（row 0-2フィルタ付き）を以下に置き換える:

```gdscript
# highlight_cells: player_buildings全体から半径3の和集合（row制限なし）
for pb in _battle.player_buildings:
    if not pb.is_alive:
        continue
    for row in range(EconGrid.ROWS):
        for col in range(_grid.get_col_count(row)):
            var cell := Vector2i(col, row)
            if _grid.is_mountain(cell):
                continue
            if _grid.hex_distance(cell, pb.grid_pos) <= 3:
                _grid.highlight_cells[cell] = true

# enemy_territory_cells: enemy_buildings全体から半径3の和集合（row制限なし）
_grid.enemy_territory_cells.clear()
for eb in _battle.enemy_buildings:
    if not eb.is_alive:
        continue
    for row in range(EconGrid.ROWS):
        for col in range(_grid.get_col_count(row)):
            var cell := Vector2i(col, row)
            if _grid.is_mountain(cell):
                continue
            if _grid.hex_distance(cell, eb.grid_pos) <= 3:
                _grid.enemy_territory_cells[cell] = true
```

fill_cells（建設モード時塗りつぶし）はrow 0-2フィルタを維持し変更なし。

### 制約
- fill_cells（塗りつぶし）は建設モード時のみ・row 0-2フィルタ維持
- KISS原則: 指示外のロジック追加禁止
