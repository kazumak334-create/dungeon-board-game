STATUS: 廃止（→ docs/GAME_DESIGN_V0_2_MVP.md）
最終更新: 2026-05-04

# デバッグUI拡張 企画書

## 1. 画面の目的

- バランス調整スプリント（A-I）実施中に、ゲーム再起動なしでパラメータをリアルタイム変更する
- チート機能でゲーム状態を即座に操作し、特定条件の再現を容易にする
- 開発者がF12で即座にアクセスし、調整→確認→再調整のイテレーションを高速化する

## 2. 設計方針：既存DevUI.gdとの関係

**既存DevUI.gd（バトル画面専用）はそのまま維持する。**

理由：
- 既存DevUI.gdはバトル中のカード操作・デッキ編集・盤面効果設置に特化しており、RefCountedベースで密結合している
- 新デバッグUIは「パラメータ調整・チート・システム制御」という全く異なる責務
- 両者は共存可能（バトル中は両方表示可能）

新規作成するのは `scripts/DebugPanel.gd`（CanvasLayer + Panel構成）。F12トグルで開閉する独立したオーバーレイUI。

## 3. レイアウト構成

```
画面解像度: 1280x720

┌──────────────────────────────────────────────────────┐
│                   ゲーム画面                          │
│                                                      │
│                              ┌──────────────────────┐│
│                              │ [x] Debug Panel      ││
│                              │ ┌──┬──┬──┐           ││
│                              │ │ﾊﾟﾗ│ﾁｰﾄ│ｼｽ│ ← タブ  ││
│                              │ ├──┴──┴──┤           ││
│                              │ │              │     ││
│                              │ │  タブ内容     │     ││
│                              │ │              │     ││
│                              │ │              │     ││
│                              │ └──────────────┘     ││
│                              └──────────────────────┘│
└──────────────────────────────────────────────────────┘
```

### パネル配置

| 要素 | 位置 | サイズ | 備考 |
|------|------|--------|------|
| DebugPanel背景 | x=880, y=20 | w=380, h=680 | 右寄せ、上下マージン20px |
| タイトルバー | パネル内上部 | w=380, h=30 | 「Debug Panel」+ 閉じるボタン |
| タブバー | タイトル下 | w=380, h=28 | 3タブ横並び |
| タブ内容スクロール | タブバー下 | w=380, h=622 | ScrollContainer |

## 4. UIコンポーネント一覧

### タブ1: パラメータ

```
── マナ経済 ──
[初期マナ    ] [===|====] 3    (1-10, step 1)
[マナ上限    ] [===|====] 3    (1-20, step 1)
[マナ回復倍率] [===|====] 1.0  (0.1-5.0, step 0.1)

── 時間制限 ──
[制限時間(秒)] [===|====] 60   (30-180, step 5)

── 敵倍率 ──
[敵HP倍率    ] [===|====] 1.0  (0.5-3.0, step 0.1)
[敵ATK倍率   ] [===|====] 1.0  (0.5-3.0, step 0.1)

── ドロップテーブル ──
[段階: Early ▼] ← OptionButton (Early/Mid/Late)
[common  ] [===|====] 65   (0-100, step 5)
[uncommon] [===|====] 30   (0-100, step 5)
[rare    ] [===|====]  5   (0-100, step 1)
[epic    ] [===|====]  0   (0-100, step 1)
[legend  ] [===|====]  0   (0-100, step 1)

── 警戒システム ──
[アーマー配置数] [===|====] 3  (0-9, step 1)
[棘配置数      ] [===|====] 3  (0-9, step 1)
[アーマー軽減量] [===|====] 2  (0-10, step 1)
[棘ダメージ    ] [===|====] 2  (0-10, step 1)

[リセット（全デフォルト）]
```

### タブ2: チート（RimWorld Dev Mode参考）

```
── Godモード ──
[☐ 無敵モード] [☐ マナ無限] [☐ 時間無限]
[☐ 必ず勝利]

── リソース操作 ──
[HP+10] [HP+50] [HP MAX] [現在: 25/30]
[Gold +100] [+500] [+1000] [現在: 350G]
[SP +5] [+20] [+50] [現在: 12SP]

── 警戒レベル ──
[-1] [+1] [=0] [=5] [現在: Lv.3]

── カード・アーティファクト追加 ──
[カード名/アーティファクト名_______]
[カードを追加] [アーティファクトを追加]
[検索結果: 一致候補表示]

── ユニット操作（バトル中のみ） ──
[選択ユニット: なし]
[HP編集___] [ATK編集___] [適用]
[位置変更モード] ← クリックで移動先選択
[削除] [複製]

── 盤面操作 ──
[盤面効果追加▼] ← アーマー/棘/呪い/ヒビ等
[配置マス選択モード]
[全クリア]

── ゲーム状態 ──
[run_depth -1] [+1] [現在: 5]
[Act -1] [+1] [現在: 1]
[次バトルスキップ]
[ボス戦強制開始]

── 敵操作 ──
[敵全削除]
[敵HP半減]
[敵凍結（動作停止）]

── デッキ操作 ──
[手札に追加▼] ← カード選択
[デッキに追加▼]
[山札シャッフル]
```

### タブ3: システム

```
── 速度制御 ──
[x0.5] [x1] [x2] [x4] [x8]

── 表示切替 ──
[☐ ログ表示]
[☐ FPS表示]
[☐ 攻撃範囲可視化]
[☐ マナフロー可視化]
[☐ パス表示（ユニット移動経路）]

── 状態ダンプ ──
[GameSession出力]
[CardDB出力]
[balance.json保存]

── ConfigLoader ──
[balance.json再読込]
[最終読込: 12:34:56]

── シーン操作 ──
[バトル再開始]
[タイトルに戻る]
[マップに戻る]
```

## 5. 技術設計

### ファイル構成

| ファイル | 責務 |
|----------|------|
| `scripts/DebugPanel.gd` | CanvasLayer + Panel構築、F12トグル、タブ管理 |
| `scripts/DebugParamTab.gd` | パラメータタブのスライダー群構築・ConfigLoader連携 |
| `scripts/DebugCheatTab.gd` | チートタブのボタン群構築・GameSession操作 |
| `scripts/DebugSystemTab.gd` | システムタブの速度制御・ダンプ・リロード |

### ConfigLoader拡張

既存のConfigLoader.gdに以下を追加：

```gdscript
# ランタイム値上書き（ゲーム起動中の一時変更）
var _runtime_overrides: Dictionary = {}

func set_runtime_value(section: String, key: String, value) -> void:
    if not _runtime_overrides.has(section):
        _runtime_overrides[section] = {}
    _runtime_overrides[section][key] = value

func get_value(section: String, key: String, default = null):
    # ランタイム上書きを優先
    if _runtime_overrides.has(section) and _runtime_overrides[section].has(key):
        return _runtime_overrides[section][key]
    # balance.json の値
    if _config.has(section) and _config[section].has(key):
        return _config[section][key]
    # デフォルト値
    if DEFAULT_CONFIG.has(section) and DEFAULT_CONFIG[section].has(key):
        return DEFAULT_CONFIG[section][key]
    return default

func save_runtime_to_file() -> void:
    # _runtime_overridesをbalance.jsonに書き出し
    pass
```

### Godモード実装

GameSession.gdにGodモードフラグを追加：

```gdscript
var god_mode_invincible: bool = false
var god_mode_infinite_mana: bool = false
var god_mode_infinite_time: bool = false
var god_mode_auto_win: bool = false
```

Main.gd等でHP減少処理・マナ消費・時間減少時にこれらをチェック。

### AutoLoad登録

```ini
[autoload]
DebugPanel="*res://scripts/DebugPanel.gd"
```

## 6. 実装手順

| 順序 | 作業 | 依存 |
|------|------|------|
| 1 | ConfigLoaderに `set_runtime_value()` 追加 | 既存ConfigLoader.gd |
| 2 | GameSession.gdにGodモードフラグ追加 | なし |
| 3 | DebugPanel.gd 作成（F12トグル・タブ切替の骨格） | なし |
| 4 | DebugParamTab.gd 作成（スライダー群） | Step 1 |
| 5 | DebugCheatTab.gd 作成（チートボタン群） | Step 2 |
| 6 | DebugSystemTab.gd 作成（速度・ダンプ・リロード） | Step 1 |
| 7 | project.godot に AutoLoad 登録 | Step 3 |
| 8 | 構文チェック・動作確認 | Step 1-7 |

## 7. RimWorld参考機能対応表

| RimWorld機能 | このゲームでの対応 |
|--------------|-------------------|
| 無敵モード | Godモード: 無敵 |
| リソース追加 | Gold/SP/カード/アーティファクト追加 |
| ステータス編集 | ユニットHP/ATK編集 |
| 環境操作 | 警戒レベル/盤面効果操作 |
| 時間加速 | x0.5-x8速度制御 |
| 強制イベント | ボス戦強制開始/バトルスキップ |
| デバッグドロー | 攻撃範囲/パス/マナフロー可視化 |
| キャラ生成 | ユニット追加（複製機能） |

---

以上、リムワールドのDev Modeを参考にした拡張デバッグUI企画書です。
