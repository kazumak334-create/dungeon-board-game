# Codex 実装結果: Sprint 9 報酬・マイルストーン・宝箱システム

作成日: 2026-05-04
対応依頼: docs/tasks/codex_request_sprint9.md

## 変更ファイル

- `scripts/econ_mvp/GameSession.gd`: 1行〜48行
- `scripts/econ_mvp/RewardSystemManager.gd`: 1行〜258行
- `scripts/econ_mvp/MilestoneWindow.gd`: 1行〜139行
- `scripts/econ_mvp/RewardSelectionUI.gd`: 1行〜90行
- `scripts/econ_mvp/EconChest.gd`: 1行〜27行
- `scripts/econ_mvp/LandCardPlacementController.gd`: 1行〜81行
- `scripts/econ_mvp/EconBattle.gd`: 3行〜617行
- `scripts/econ_mvp/EconMain.gd`: 8行〜1749行
- `data/cards_econ.json`: 252行〜306行

## 変更概要

- 初期難易度選択、通貨補正、8系統×3段階マイルストーン生成・進捗更新・達成記録を追加。
- 中難度マイルストーン即時報酬、宝箱3個配置、隣接建設による宝箱取得、特殊マイルストーン追加を追加。
- ドラッグ可能なマイルストーンウィンドウ、バトル後3択報酬UI、SKIP、土地カード配置モードを追加。
- `cards_econ.json` に通常/特殊マイルストーン報酬プールと宝箱即時報酬プールを追加。

## 検証

実行したコマンド:
```bash
python -m json.tool data/cards_econ.json
bash check_syntax.sh
```

結果:

- `cards_econ.json` JSON検証成功
- `bash check_syntax.sh` 成功（構文チェック / 静的パターンチェック通過）

## 未検証項目

- Godot上でのクリック操作を含む通しプレイ確認。
- 報酬カードを実デッキへ永続追加する詳細フロー。
- 報酬UI、マイルストーンウィンドウ、土地配置ハイライトの視認性確認。

## 残リスク

- 既存ワークツリーに多数の変更があるため、同一ファイル内の既存差分との責務切り分けは要確認。
- 政策カード・偉人カードはSprint 9 MVP範囲のフレームワーク扱いで、個別効果は未実装。
- 特殊マイルストーン条件と数値バランスは要件定義書の残課題どおり調整余地あり。

## PMO 更新候補

- docs/roadmap.md: Sprint 9 報酬・マイルストーン・宝箱システムの実装進捗反映
- CHANGELOG.md: Sprint 9 MVP報酬基盤、宝箱、土地カード配置モード追加
