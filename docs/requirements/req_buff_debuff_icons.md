# 要件定義書: バフ・デバフアイコン表示

**作成日**: 2026-04-26
**対象ファイル**: `scripts/GameUI.gd`
**対応コミット**: -

---

## 概要

バトル画面のユニットセル内に、バフ・デバフの状態をテキスト絵文字からPNGアイコンで表示するよう置き換える。

---

## 調査結果

### GameUI.gd 現状（385〜407行）

`render_cell()` 内で以下の絵文字テキストをLabelに連結している:

```gdscript
# バフ表示
if unit.power_stacks > 0:       buff_icons.append("💪")
if unit.boots_stacks > 0:       buff_icons.append("👢")
if unit._damage_reduction > 0:  buff_icons.append("🛡")
if unit.regen_stacks > 0:       buff_icons.append("💚")

# デバフ表示
if unit.burn_turns > 0:         debuff_icons.append("🔥")
if unit.frozen_turns > 0:       debuff_icons.append("❄")
if unit.poison_stacks > 0:      debuff_icons.append("☠")
if unit.curse_stacks > 0:       debuff_icons.append("🌀")
if unit.brand_stacks > 0:       debuff_icons.append("🎯")
```

これらを削除し、TextureRect + Label（スタック数）に置き換える。

### セル座標

- セルサイズ: `CELL_W=130 × CELL_H=95`
- セル左上: `x = _cell_x(side, col)`, `cell_y = BOARD_TOP + r * CELL_H`
- HPバー: `cell_y + 36`（高さ7px）
- HP数値: `cell_y + 45`（高さ14px）
- **アイコン帯**: `cell_y + 62` 〜 `cell_y + 78`（高さ16px）
- アイコン開始X: `x + 5`、アイコン間隔: 20px（アイコン16px + 4pxマージン）

### UnitData.gd フィールド確認

| アイコンキー | UnitDataフィールド | 型 |
|---|---|---|
| freeze | `frozen_turns` | int |
| burn | `burn_turns` | int |
| poison | `poison_stacks` | int |
| curse | `curse_stacks` | int |
| brand | `brand_stacks` | int |
| shield | `_damage_reduction` | int |
| regen | `regen_stacks` | int |
| power | `power_stacks` | int |
| boots | `boots_stacks` | int |
| sense | `sense_stacks` | int |
| spring | `spring_stacks` | int |

**対象外**: `thorn_stacks`, `x_stacks`（仕様書の通り除外）

---

## 表示仕様

### 表示順（優先順位高い順）
`freeze > burn > poison > curse > brand > shield > regen > power > boots > sense > spring`

### アイコン
- サイズ: 16×16px
- ファイル: `res://assets/icons/status/{key}.png`
- `texture_filter = NEAREST`

### スタック数表示
- **値が2以上のときのみ**アイコン中央に重ね表示
- フォント: 白文字 10pt
- 背景: 黒半透明（Color(0,0,0,0.6)）のColorRect（9×9px、アイコン右下寄せ）

### 最大表示数
- 4個まで表示
- 5個以上は4個表示後「+N」ラベル（白10pt、残り枠位置）

### ゼロスタックは非表示
値が0のアイコンは表示しない（空枠なし）

---

## 実装方針

### 方式: 毎フレーム再生成

- `render_cell()` 呼び出し時にアイコンノードを**全削除して再生成**
- ノードプールは動作確認後に最適化（初期実装では不要）
- アイコン管理配列: `_cell_status_icons: Array`（[side][r][c] → Array[Node]）

### 変更箇所

**GameUI.gd**

1. **class変数追加**（先頭付近）:
   ```gdscript
   var _cell_status_icons: Array = []  # [side][r][c] -> Array[Node]
   ```

2. **build_ui() のセル生成ループ内**（hp_lbl生成後）に初期化:
   ```gdscript
   _cell_status_icons[side][r].append([])
   ```
   ループ外の初期化も必要:
   ```gdscript
   _cell_status_icons = [[], []]
   for side in range(2):
       for r in range(3):
           _cell_status_icons[side].append([])
   ```

3. **render_cell() 内の既存バフ/デバフ絵文字ロジック削除**（385〜407行の`buff_icons`/`debuff_icons`/`buff_line`/`debuff_line`/`status_line`部分）

4. **render_cell() 内にアイコン描画関数呼び出し追加**（`lbl.text = ...` の後）:
   ```gdscript
   _render_status_icons(side, r, c, unit)
   ```

5. **`_render_status_icons()` 関数を新規追加**:
   - 既存アイコンを全削除
   - アクティブなアイコンリストを優先順で構築
   - 最大4個 + 「+N」ラベルを描画

6. **ユニット不在時のアイコン削除**（`else` ブロック、unit == null の場合）:
   ```gdscript
   _clear_status_icons(side, r, c)
   ```

### `_render_status_icons()` の処理フロー

```
1. _clear_status_icons(side, r, c) で既存ノード全削除
2. unit が null なら return
3. 優先順でアクティブアイコンを (key, stack_value) のペアで配列に収集
4. 最大4個を描画:
   a. TextureRect (16x16) をcell_y+62 の位置に配置
   b. stack_value >= 2 なら ColorRect(9x9 黒半透明) + Label(10pt 白) を重ねる
5. 5個以上なら4個目の次に "+N" Label を追加
6. 生成したノードを _cell_status_icons[side][r][c] に保存
```

### `_clear_status_icons()` の処理フロー

```
1. _cell_status_icons[side][r][c] の各ノードに queue_free()
2. _cell_status_icons[side][r][c] = []
```

---

## 影響範囲

- 変更: `scripts/GameUI.gd`（1ファイルのみ）
- 追加: なし
- 削除: 絵文字テキスト表示ロジック（385〜407行の一部）

---

## 検証方法

1. `bash check_syntax.sh` でエラー0件
2. バトル画面でバフ/デバフ付与ユニットのセルにアイコンが表示される
3. スタック2以上で数字が重なる
4. ユニット死亡後にアイコンが消える

