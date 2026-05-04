---
description: SakuraiAgentで企画書・要件定義書・designer_planを7軸レビューする
---

# /sakurai-review

任意のファイルをSakuraiAgentに7軸レビューさせる。

## 使い方

```
/sakurai-review                          # 最新のsprint企画書を自動選択
/sakurai-review docs/design/sprint8_designer_plan.md
/sakurai-review docs/requirements/REQUIREMENTS_SPRINT_8.md
```

## 手順

1. 引数でファイルパスが指定されていれば、そのファイルを対象にする
   - 指定がない場合は `docs/sprint*_final.md` の最新ファイルを自動選択
2. Sakurai Agent を起動（7軸チェックリスト）
3. 出力を `docs/reviews/sakurai_{YYYYMMDD}_{basename}.md` に保存
4. 以下をチャットに要約出力：
   - 良い点（箇条書き）
   - 削るべき要素（箇条書き・件数を先頭に）
   - 強化すべき面白さ（箇条書き）
   - 総合判定：通過 / 要修正

## 注意

- SakuraiAgentは企画修正・実装を行わない（レビューと指摘のみ）
- 「削るべき要素が2件以上 = 要修正」を判定基準とする
- 要修正の場合はユーザーが次のアクションを判断する
