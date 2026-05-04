---
description: Phase完了時にSakuraiAgentで体験総評・設計ドリフトを検出する
---

# /phase-review

Phase完了時に実行。実装物全体をSakuraiAgentが評価し、設計ドリフトを検出する。
`/pmo-update` の前に挟む。

## 使い方

```
/phase-review        # roadmap.mdから最新完了Phaseを自動判定
/phase-review 1      # Phase 1 を明示指定
```

## 手順

1. `docs/roadmap.md` から対象Phaseの完了Sprint一覧を取得
2. 対応する `docs/requirements/REQUIREMENTS_SPRINT_*.md` を収集
3. `docs/GAME_DESIGN_V0_2_MVP.md` の核となる体験を確認
4. Sakurai Agent を起動（以下に重点）：
   - コア体験「盤面を設計して観戦する」が維持されているか
   - Phase全体で複雑化が累積していないか
   - 削れる機能・重複した仕様がないか
5. 出力を `docs/reviews/sakurai_phase{N}_review.md` に保存
6. 判定：
   - **問題なし** → `/pmo-update` を実行してよい旨をユーザーに伝える
   - **重大な設計ドリフト検出** → 内容を報告してユーザー判断を仰ぐ（pmo-update保留）

## 出力形式

```
Phase {N} 体験レビュー
- 総評: （1-2行）
- 設計ドリフト: （あり / なし）
- 削るべき要素: （件数と内容）
- 強化すべき面白さ: （内容）
- 判定: pmo-update 可 / 要確認
```
