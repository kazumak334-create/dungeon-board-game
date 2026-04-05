# Godot 4 画面遷移 + .tscn生成 リファレンス

## 画面遷移の基本

```gdscript
# 基本
get_tree().change_scene_to_packed(preload("res://scenes/Battle.tscn"))

# deferred版（シグナルコールバック内で推奨）
get_tree().change_scene_to_packed.call_deferred(scene)
```

## Autoload設定（project.godot）

```ini
[autoload]
GameSession="*res://scripts/GameSession.gd"
SceneTransition="*res://scripts/SceneTransition.gd"
```

## フェードトランジション

```gdscript
# SceneTransition.gd（Autoload）
extends CanvasLayer

func goto(path: String):
    var tween = create_tween()
    tween.tween_property($Overlay, "color", Color(0,0,0,1), 0.3)
    tween.tween_callback(func(): 
        get_tree().change_scene_to_packed(load(path))
        var t2 = create_tween()
        t2.tween_property($Overlay, "color", Color(0,0,0,0), 0.3))
```

## .tscnテキスト生成の注意点
- uid は仮値でOK（Godotエディタが初回起動時に正規化）
- ext_resource でスクリプトをアタッチ
- sub_resource でStyleBoxFlat等を定義
- connection でシグナル接続
- binds で引数付き接続可能

## クラス選択・バトル結果の.tscnテンプレートあり
→ 別途テンプレートファイル参照
