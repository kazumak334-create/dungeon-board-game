# Godot 4 個人開発ベストプラクティス

> 調査日: 2026-04-03  
> 対象バージョン: Godot 4.x (GDScript)  
> 参考: Godot 公式ドキュメント / Reddit r/godot / Medium / GitHub

---

## 目次

1. [推奨フォルダ構成・命名規則](#1-推奨フォルダ構成命名規則)
2. [GDScript のパフォーマンス注意点](#2-gdscript-のパフォーマンス注意点)
3. [リアルタイム処理の使い分け（_process vs Timer）](#3-リアルタイム処理の使い分け_process-vs-timer)
4. [個人開発者のプロジェクト構成事例](#4-個人開発者のプロジェクト構成事例)

---

## 1. 推奨フォルダ構成・命名規則

### 基本方針：「Packed（詰め込み）アプローチ」

Godot 公式ドキュメントが推奨するのは **packed approach**。  
シーン・スクリプト・リソースを「機能単位でひとつのフォルダにまとめる」方式。

```
res://
├── project.godot
├── autoloads/          # グローバル AutoLoad スクリプト
│   ├── game_manager.gd
│   ├── audio_manager.gd
│   └── save_manager.gd
├── scenes/             # シーン単位でサブフォルダ
│   ├── main/
│   │   ├── main.tscn
│   │   └── main.gd
│   ├── ui/
│   │   ├── hud.tscn
│   │   ├── hud.gd
│   │   └── pause_menu.tscn
│   ├── player/
│   │   ├── player.tscn
│   │   ├── player.gd
│   │   └── player_stats.tres   # Resource
│   ├── enemies/
│   │   ├── goblin/
│   │   │   ├── goblin.tscn
│   │   │   └── goblin.gd
│   │   └── dragon/
│   └── board/          # このプロジェクト固有
│       ├── tile.tscn
│       ├── tile.gd
│       └── board_manager.gd
├── assets/
│   ├── sprites/
│   ├── audio/
│   │   ├── bgm/
│   │   └── sfx/
│   └── fonts/
├── resources/          # 共有 Resource (.tres / .res)
│   ├── items/
│   └── data/
└── addons/             # プラグイン・拡張
```

**なぜ packed か？**
- シーンを別プロジェクトに移植するとき、フォルダごとコピーで完結する
- `scenes/` 配下に数百ファイルが溜まる "分散アプローチ" は後々破綻しやすい

### 命名規則

| 対象 | 規則 | 例 |
|------|------|-----|
| フォルダ名 | `snake_case` | `player/`, `board_manager/` |
| GDScript ファイル | `snake_case.gd` | `tile_manager.gd` |
| シーンファイル | `snake_case.tscn` | `dungeon_board.tscn` |
| C# スクリプト | `PascalCase.cs` | `BoardManager.cs` |
| class_name | `PascalCase` | `class_name TileManager` |
| 変数・関数 | `snake_case` | `var tile_count`, `func get_tile()` |
| 定数 | `UPPER_SNAKE_CASE` | `const MAX_TILES = 64` |
| シグナル | `snake_case` (過去形) | `signal tile_selected` |

### 注意点

- **大文字小文字の一貫性が重要**: Linux ではファイルシステムがケースセンシティブ。Windows で開発→Linux でエクスポート、というパターンでパス破損が起きやすい。全部小文字 snake_case なら安全。
- 無視したいフォルダには `.gdignore` ファイルを置く（Godot がインポートしなくなる）。

---

## 2. GDScript のパフォーマンス注意点

### 大前提：計測してから最適化

> "Measure first. Write the code in whatever way it feels most comfortable for you, then profile." — r/godot

プロファイラを使わない最適化は時間の無駄。  
Godot エディタ内蔵の **Debugger > Profiler** タブから計測が始められる。

### 具体的な注意点

#### 🔴 やってはいけない（高コスト）

| アンチパターン | 問題 | 代替案 |
|--------------|------|--------|
| `get_node("../../Player")` を `_process` 内で毎フレーム | ノードパス解決はコスト高 | `@onready var` でキャッシュ |
| String 比較で状態管理 | `"running" == state` は遅い | `enum State { IDLE, RUNNING }` を使う |
| Getter/Setter の多用 | 関数呼び出しオーバーヘッド | 必要な箇所だけ使う |
| グローバル変数の多用 | 参照コストとバグリスク | AutoLoad の乱用は避ける |
| ループ内で毎回 `find_child()` | 木の探索はO(n) | 初期化時にキャッシュ |

#### 🟢 推奨パターン

```gdscript
# ✅ onready でキャッシュ（毎フレーム検索しない）
@onready var health_bar: ProgressBar = $HUD/HealthBar
@onready var player: CharacterBody2D = $Player

# ✅ 型ヒントで実行時チェックを削減
func take_damage(amount: int) -> void:
    health -= amount

# ✅ static 関数（インスタンス不要な処理）
static func calculate_damage(base: int, multiplier: float) -> int:
    return int(base * multiplier)

# ✅ enum で状態管理（文字列比較を避ける）
enum TurnPhase { DRAW, MAIN, COMBAT, END }
var current_phase: TurnPhase = TurnPhase.DRAW
```

#### オブジェクトプーリング

敵・弾丸など頻繁に生成/削除するオブジェクトはプールを使う。  
`queue_free()` + `instantiate()` の繰り返しはGCとノード木に負荷がかかる。

```gdscript
# シンプルなプール例（概念のみ）
var _pool: Array[Node] = []

func get_from_pool() -> Node:
    if _pool.is_empty():
        return SCENE.instantiate()
    return _pool.pop_back()

func return_to_pool(node: Node) -> void:
    node.hide()
    _pool.append(node)
```

#### レンダリング最適化（ダンジョンボードゲーム向け）

- **TileMap を活用**: 個別の Sprite2D を並べるより TileMap の方がドローコールが少ない
- **MultiMeshInstance2D**: 大量の同一スプライト（コイン、パーティクルなど）に有効
- **VisibilityNotifier2D**: 画面外のノードの処理を止める
- 物理シェイプは **CollisionPolygon より CollisionShape（矩形・円）** の方が軽い

---

## 3. リアルタイム処理の使い分け（_process vs Timer）

### 3種類の処理方式の比較

| 方式 | 実行タイミング | 主な用途 | パフォーマンス |
|------|--------------|---------|--------------|
| `_process(delta)` | 毎フレーム（GPU描画レートに依存） | アニメーション、カメラ追従、入力応答 | 注意が必要 |
| `_physics_process(delta)` | 固定レート（デフォルト60Hz） | 物理演算、移動、衝突判定 | 安定・中程度 |
| `Timer` ノード | 指定間隔でシグナル発火 | クールダウン、敵スポーン、UI更新 | 最も軽量 |

### 使い分けの判断基準

#### `_process(delta)` を使う場面
- 毎フレーム滑らかに変化するもの: カメラ追従、tweenでない手動アニメーション、入力の即時応答
- フレームレートに依存する視覚効果

```gdscript
func _process(delta: float) -> void:
    # カメラをプレイヤーに追従（滑らかに）
    position = position.lerp(target.position, delta * follow_speed)
```

#### `_physics_process(delta)` を使う場面
- 物理ボディの移動（CharacterBody2D, RigidBody2D）
- 衝突判定が絡む処理
- 物理レートと同期させたいロジック

```gdscript
func _physics_process(delta: float) -> void:
    velocity = direction * speed
    move_and_slide()
```

#### `Timer` ノードを使う場面（**これが最もパフォーマンス有利**）
- 一定間隔で「たまに」発生する処理
- 攻撃クールダウン、敵スポーン、ターン経過、UI の定期更新

```gdscript
# Timer ノードをシーンに追加して connect
func _ready() -> void:
    $SpawnTimer.timeout.connect(_on_spawn_timer_timeout)
    $SpawnTimer.start(3.0)  # 3秒ごと

func _on_spawn_timer_timeout() -> void:
    spawn_enemy()
```

またはコードで動的に作成:

```gdscript
func start_cooldown(duration: float) -> void:
    var timer := get_tree().create_timer(duration)
    await timer.timeout
    can_attack = true
```

### 重要な知見

**「Timer は `_process` の代替にならない」**  
Godot フォーラムの議論によると:

> "The performance gain by using Timer or self-made interval is an illusion unless your FPS hits the limit. The issue is not HOW OFTEN the code runs, but HOW MUCH the code does per run."

つまり：
- `_process` の中で軽い処理をする → 問題なし
- `_process` の中で重い処理をする → Timer に移しても根本解決にならない（処理自体を軽くすべき）
- 「たまにしか必要のない処理」を毎フレーム実行している → Timer が明確に有利

### ダンジョンボードゲームでの推奨使い分け

| 処理 | 推奨方式 | 理由 |
|------|---------|------|
| カードドラッグ＆ドロップ | `_process` | 入力への即時応答が必要 |
| ターン終了判定 | Signal / Timer | イベント駆動で十分 |
| 敵AIの行動計算 | Timer（ターン制なら） | 毎フレーム不要 |
| アニメーション | AnimationPlayer / Tween | `_process` で手書き不要 |
| HP表示更新 | Signal 経由 | 変化時のみ更新 |

---

## 4. 個人開発者のプロジェクト構成事例

### 事例 1：10,000行規模プロジェクト（YouTube参照）

個人開発者が実際に10k+行規模になった際のトップレベル構造：

```
res://
├── autoloads/       # GameManager, AudioBus, SaveData
├── common/          # 汎用コンポーネント（再利用部品）
├── levels/          # 各レベル/ステージ（独立したフォルダ）
├── player/          # Player シーン一式
├── ui/              # 全 UI シーン
├── enemies/         # 敵キャラクター
└── assets/          # 画像・音声・フォント
```

**ポイント:**
- `common/` に再利用可能なコンポーネントを集約
- `levels/` はゲームの各ステージをそれぞれ独立フォルダに
- AutoLoad は最小限（GameManager / AudioManager / SaveManager の3本柱が多い）

### 事例 2：Simon Dalvai 式（シーン中心）

```
res://
├── src/
│   ├── player/
│   │   ├── player.tscn
│   │   ├── player.gd
│   │   └── player_skin.tres
│   ├── ui/
│   │   └── hud/
│   │       ├── hud.tscn
│   │       └── hud.gd
│   └── world/
├── assets/
└── addons/
```

**ポイント:**
- `src/` にゲームロジック全体をまとめる
- Scene Unique Nodes（`%NodeName` 記法）でノード参照を明示化
- `.gd` スクリプトと `.tscn` は必ず同じフォルダ

### ダンジョンボードゲーム（このプロジェクト）への推奨構成

```
res://
├── autoloads/
│   ├── game_manager.gd      # ゲーム状態管理（ターン、フェーズ）
│   ├── card_database.gd     # カードデータの一元管理
│   └── audio_manager.gd
├── scenes/
│   ├── main/
│   ├── board/               # ボード・タイル関連
│   │   ├── board.tscn
│   │   ├── board.gd
│   │   ├── tile.tscn
│   │   └── tile.gd
│   ├── cards/               # カードシステム
│   │   ├── card.tscn
│   │   ├── card.gd
│   │   ├── hand.tscn
│   │   └── deck.gd
│   ├── characters/          # プレイヤー・敵
│   │   ├── player/
│   │   └── enemies/
│   └── ui/
│       ├── hud.tscn
│       ├── turn_indicator.tscn
│       └── card_detail_popup.tscn
├── resources/
│   ├── cards/               # CardData Resource (.tres)
│   └── characters/          # CharacterStats Resource
└── assets/
    ├── sprites/
    │   ├── cards/
    │   ├── tiles/
    │   └── ui/
    └── audio/
```

### AutoLoad の使い方ベストプラクティス

| AutoLoad 名 | 役割 |
|------------|------|
| `GameManager` | ターン管理、ゲームフェーズ、勝敗判定 |
| `CardDatabase` | カードデータ一覧、カード生成ファクトリ |
| `AudioManager` | BGM/SE の再生・ボリューム管理 |
| `SaveManager` | セーブ・ロード |

**注意**: AutoLoad は「どこからでもアクセスできる」ため乱用しやすい。  
シーン固有のデータは AutoLoad に入れず、Resource (.tres) か Scene の変数に持つこと。

---

## まとめ：個人開発で最初に決めるべき3つのこと

1. **フォルダ構成**: packed approach + snake_case で最初から統一する（後から直すのは地獄）
2. **AutoLoad の範囲**: GameManager / AudioManager / SaveManager の3本に絞る（最初は）
3. **処理の分類**: 毎フレーム必要かどうかを考えて `_process` / `_physics_process` / `Timer` / Signal を使い分ける

> 「最初はきれいに作ろうとしすぎず、動くものを作りながら整理する」  
> — r/godot のコンセンサス

---

## 参考リンク

- [Godot 4 公式: Project Organization](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)
- [Godot 4 公式: Idle and Physics Processing](https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html)
- [Godot 4 公式: General Optimization](https://docs.godotengine.org/en/stable/tutorials/performance/general_optimization.html)
- [GitHub: godot-architecture-organization-advice](https://github.com/abmarnie/godot-architecture-organization-advice)
- [Medium: 10 GDScript Optimization Tips](https://medium.com/godot-dev-digest/10-proven-gdscript-optimization-tips-for-faster-game-performance-7b9cb74932a5)
