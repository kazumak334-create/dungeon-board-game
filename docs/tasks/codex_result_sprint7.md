# Codex 実装結果: Sprint 7 初期デッキ・ランドカード配置

作成日: 2026-05-04
対応依頼: docs/tasks/codex_request_sprint7.md

## 変更ファイル

- `scripts/econ_mvp/EconGrid.gd`: 356行、368行〜465行
- `scripts/econ_mvp/EconMain.gd`: 20行〜29行、1509行〜1654行
- `data/cards_econ.json`: 186行〜190行
- `docs/tasks/codex_result_sprint7.md`: 新規作成

## 変更概要

- `EconGrid.gd` から旧仕様の `get_all_overwritable_cells_for_land()` を削除し、既存パネル上書き用 API が残らないように修正。
- 既存実装として、`get_land_card_placement_options()` は自拠点距離 1〜3、開示済み、自建物隣接、建物未占有、ランドカード未配置の最大 3 パネルを返すことを確認。
- 既存実装として、`place_land_card()` は既存 panel を duplicate し、`land_card_*` 追加情報のみを保存して、元の `resources` / `special_tag` / `terrain_type` を上書きしないことを確認。
- 既存実装として、戦闘勝利後の `_show_land_card_reward()`、3択ランドカード候補、キャンセル、配置後 `reveal_panels_around(pos, 3)` 実行を確認。
- 既存実装として、`INITIAL_DECK` と `card_trade_post.category = "special"` を確認。

## 検証

実行したコマンド:
```bash
bash check_syntax.sh
python -m json.tool data/cards_econ.json
```

結果:

- `bash check_syntax.sh`: 構文チェックパス、静的パターンチェックパス、エラー 0 件
- `python -m json.tool data/cards_econ.json`: JSON パース成功

## 未検証項目

- Godot エディタ上での実プレイ操作によるランドカード配置 UI 表示とクリック操作。
- G: ドライブ上の Final 企画書は `NOT_FOUND` で参照不可。

## 残リスク

- `req_econ_initial_deck_sprint7.md` には「初期デッキ 11 枚」と「住居3、農場2、製材所2、採石場2、食堂1、兵舎1、広場1、交換所1」という合計 13 枚の構成が併記されている。現行実装はカード別枚数を優先して 13 枚になるため、枚数は PMO/Designer 要確認。
- request ファイルと要件ファイルはローカル表示で文字化けしているため、冒頭依頼文と ASCII 識別子を主に参照した。

## PMO 更新候補

- docs/roadmap.md: Sprint 7 ランドカード配置の実装済みステータス確認
- CHANGELOG.md: 初期デッキ・ランドカード配置・上書き API 削除の追記候補
