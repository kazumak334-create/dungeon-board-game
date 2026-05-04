# /review-codex-result

Codex の result ファイルをレビューして受け入れ判断を行う。

## 手順

1. `docs/tasks/codex_result_*.md` の最新ファイルを読む
2. 対応する `docs/tasks/codex_request_*.md` を読む
3. 以下の観点でレビューする：
   - 依頼通りに実装されているか
   - `docs/GAME_DESIGN_V0_2_MVP.md` と矛盾しないか
   - 検証（check_syntax.sh）が実施されているか
   - 核となる体験「盤面を設計して観戦する」と整合しているか（Sakurai観点）
   - 残リスクは許容範囲か
4. 判定を出す：受け入れ可 / 再依頼 / 要確認
5. 受け入れ可の場合は PMO 更新（roadmap.md / CHANGELOG.md）を実施
