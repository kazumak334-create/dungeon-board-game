# スキル説明UI 案A 要件定義書

## 1. 概要

`_show_card_detail()` のスキル表示を「[トリガー] 対象 効果+数値」の構造化1行フォーマットに改修する。
既存の `trigger: display` 形式から、target と params の数値を読んで具体的な説明を生成する。

## 2. 実装対象

- ファイル: `scripts/RestScreenManager.gd`
- 現在の行数: 1144行
- 変更箇所:
  - **676-687行**: `TRIGGER_NAMES` 辞書に不足triggerを追記
  - **688-706行**: スキル整形ループを案Aフォーマットに改修
  - **新規追加（ループの直前に挿入）**: `TARGET_NAMES` 辞書
  - **新規追加（`_show_card_detail` の外・同ファイル内）**: `_format_skill_params()` ヘルパー関数

## 3. データ構造

### 3-1. TRIGGER_NAMES 追記分

既存（676-687行）に以下を追記する：

```gdscript
"on_ally_death": "味方撃破時",
"on_attack": "攻撃時",
"on_battle_start": "バトル開始時",
"on_crit": "クリティカル時",
"on_damaged": "被ダメ時",
"on_front_attack_poisoned_target": "毒敵への前列攻撃時",
"passive": "パッシブ",
```

on_death は既存の "撃破された時" が流用可能。timer も既存の "定期" を使う。

### 3-2. TARGET_NAMES 辞書（新規・TRIGGER_NAMESの直後に追加）

GDScriptコード:

```gdscript
var TARGET_NAMES: Dictionary = {
	"self":                         "自身",
	"hit_target":                   "命中対象",
	"attacker":                     "攻撃者",
	"revived_unit":                 "蘇生ユニット",
	"enemy":                        "敵1体",
	"enemy_single":                 "敵1体",
	"enemy_front":                  "敵前列1体",
	"enemy_front_one":              "敵前列1体",
	"enemy_front_random":           "敵前列ランダム1体",
	"enemy_front_random_one":       "敵前列ランダム1体",
	"enemy_front_random_poisoned":  "敵前列毒ランダム1体",
	"enemy_front_lowest_hp":        "敵前列最低HP1体",
	"enemy_back":                   "敵後列1体",
	"enemy_backrow":                "敵後列全体",
	"enemy_column":                 "敵列全体",
	"enemy_highest_curse":          "敵呪い最多1体",
	"enemy_max_poison":             "敵毒最多1体",
	"enemy_all_burned":             "敵火傷全体",
	"enemy_all_frozen":             "敵凍結全体",
	"enemy_all_poisoned":           "敵毒全体",
	"enemy_all_burned_and_frozen":  "敵火傷凍結全体",
	"enemy_all_with_status":        "敵状態異常全体",
	"enemy_random_two":             "敵ランダム2体",
	"enemy_spell_slot_random":      "敵呪文スロットランダム",
	"enemy_spell_slots":            "敵呪文スロット全体",
	"enemy_player":                 "敵プレイヤー",
	"all_enemies":                  "敵全体",
	"all_cursed_enemies":           "敵呪い全体",
	"cursed_enemies":               "呪い敵",
	"enemies_with_curse":           "呪い持ち敵全体",
	"enemies_with_poison":          "毒持ち敵全体",
	"adjacent_enemies":             "隣接敵",
	"front_enemy":                  "前列敵1体",
	"front_one":                    "前列1体",
	"random_enemy":                 "ランダム敵1体",
	"random_enemies":               "ランダム敵",
	"random_front_enemy":           "前列ランダム敵",
	"random_back_enemy":            "後列ランダム敵",
	"random_enemy_row":             "ランダム敵行",
	"ally_single":                  "味方1体",
	"single_ally":                  "味方1体",
	"ally_board":                   "盤面味方",
	"all_allies":                   "味方全体",
	"all_units":                    "全ユニット",
	"all_units_random":             "全ユニットランダム",
	"all":                          "全体",
	"front_ally":                   "前列味方1体",
	"front_ally_all":               "前列味方全体",
	"front_allies":                 "前列味方",
	"front_lowest_hp_ally":         "前列最低HP味方",
	"center_ally":                  "中列味方1体",
	"ally_highest_curse":           "味方呪い最多1体",
	"ally_max_atk":                 "味方最大ATK1体",
	"ally_beast_all":               "味方獣全体",
	"allies_with_thorn":            "棘持ち味方全体",
	"same_row_allies":              "同行味方全体",
	"same_column_allies":           "同列味方全体",
	"same_row_beast":               "同行獣",
	"front_beast":                  "前列獣1体",
	"front_beasts":                 "前列獣全体",
	"front_random_beast":           "前列ランダム獣",
	"random_ally":                  "ランダム味方1体",
	"random_ally_column":           "ランダム味方列",
	"random_ally_row":              "ランダム味方行",
	"brand_attackers":              "烙印攻撃者",
	"front_tile":                   "前列タイル",
}
```

### 3-3. _format_skill_params() ヘルパー関数

_show_card_detail 関数の外（関数の直後）に追加する。

```gdscript
func _format_skill_params(params: Dictionary, trigger: String) -> String:
	var parts = []
	if params.has("stacks"):
		parts.append("+%s" % str(params["stacks"]))
	if params.has("factor"):
		parts.append("x%s" % str(params["factor"]))
	if params.has("pct"):
		var pct_val = params["pct"]
		if pct_val is float and pct_val <= 1.0:
			parts.append("%d%%" % int(pct_val * 100))
		else:
			parts.append("%s%%" % str(pct_val))
	if trigger == "timer" and params.has("interval"):
		parts.append("%sごと" % str(params["interval"]))
	if params.has("threshold"):
		parts.append("HP閾値%s%%" % str(params["threshold"]))
	if parts.is_empty():
		for key in ["damage", "amount", "count"]:
			if params.has(key):
				parts.append(str(params[key]))
				break
	return " ".join(parts)
```

## 4. 実装詳細

### 4-1. スキル整形ループ改修（688-706行の置き換え）

変更後（同じ行範囲を置き換え）:

```gdscript
for skill in skills:
	if skill is Dictionary:
		var trigger = skill.get("trigger", "")
		var effect_id = skill.get("effect_id", "")
		var target = skill.get("target", "")
		var params = skill.get("params", {})
		var trigger_disp = TRIGGER_NAMES.get(trigger, trigger)
		var target_disp = TARGET_NAMES.get(target, target)
		var edef = _edb.EFFECTS.get(effect_id, {})
		var effect_disp = edef.get("display", effect_id)
		var params_disp = _format_skill_params(params, trigger)
		var text_parts = ["[%s]" % trigger_disp]
		if target_disp != "":
			text_parts.append(target_disp)
		text_parts.append(effect_disp)
		if params_disp != "":
			text_parts.append(params_disp)
		var skill_label = Label.new()
		skill_label.text = "・%s" % " ".join(text_parts)
		skill_label.add_theme_font_size_override("font_size", 10)
		skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_detail_container.add_child(skill_label)
	else:
		var skill_label = Label.new()
		skill_label.text = "・%s" % str(skill)
		skill_label.add_theme_font_size_override("font_size", 10)
		skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		card_detail_container.add_child(skill_label)
```

### 4-2. 挿入位置まとめ

| 変更種別 | 対象行 | 内容 |
|---|---|---|
| 追記 | 676-687行のTRIGGER_NAMES内 | 7件のtriggerを追加 |
| 新規挿入 | TRIGGER_NAMES直後（688行の前） | TARGET_NAMES辞書（約70行） |
| 置き換え | 688-706行 → 約30行に拡張 | スキル整形ループ改修 |
| 新規追加 | _show_card_detail()の閉じ括弧の後 | _format_skill_params()関数（約20行） |

### 4-3. 表示例

バンシー（on_hit, hit_target, burn_apply, stacks=2）:
  ・[命中時] 命中対象 火傷付与 +2

タイマートリガー（timer, enemy_highest_curse, curse_apply, stacks=1, interval=3）:
  ・[定期] 敵呪い最多1体 呪い付与 +1 3ごと

## 5. 制約・注意事項

- 修正範囲厳守: _show_card_detail() 内のスキル整形ループ（688-706行）と、同関数内の辞書定義のみ
- 足し算禁止: planningが指定した5パターン（stacks/factor/pct/interval/threshold）＋汎用フォールバック1件のみ
- 既存TRIGGER_NAMESは変更しない: 追記のみ（上書きしない）
- 行数: 追加後1200行以下を維持（現在1144行、追加行数は約80行）
- EffectDB.gd変更禁止: displayフィールドはそのまま使う
- 構文チェック: 実装後に check_syntax.sh を実行し、エラー0件を確認すること
