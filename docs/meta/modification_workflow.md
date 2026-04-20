# 修正ワークフロー定義

## 原則
**全ての修正依頼は要件定義書を経由する。直接実装は禁止。**

## フロー

```
1. ユーザー修正依頼
   ↓
2. CEO → Architect（要件定義書更新）
   ↓
3. Architect → 更新箇所サマリー返却
   ↓
4. CEO → Implementer（更新部分だけを参照して実装）
   ↓
5. Implementer → Checker（直接呼び出し、更新部分を確認）
```

## 各ステップの詳細

### ステップ1: ユーザー修正依頼
ユーザーからバグ修正・機能追加・UI変更等の依頼を受ける。

### ステップ2: Architect呼び出し
CEOは修正内容を要件定義書に反映するよう、Architectに依頼する。

**Architectへの指示例**：
```
ユーザー要求「XXをYYに変更」を
`docs/design/ZZ_requirements.md`の§N.N（該当箇所のみ）に反映せよ。

**制約**:
- 該当セクションのみ修正（他セクションは読むな）
- 必ずWrite/Editツールを使用
- 更新箇所サマリーを返せ
```

**重要**：
- **該当箇所だけを修正**（ファイル全体を読み直さない）
- どの要件定義書のどのセクションを更新するか明示
- 更新箇所サマリーを必ず返させる
- Write/Editツール使用を明記

### ステップ3: Architect応答確認（必須）
Architectが返した更新箇所サマリーを確認する。

**必須確認手順**：
```bash
# 新規作成の場合
ls -lh docs/design/XX_requirements.md

# 修正の場合
git diff docs/design/XX_requirements.md
```

**確認事項**：
- ✅ ファイルが実際に存在するか（新規作成時）
- ✅ ファイルが実際に更新されているか（修正時）
- ✅ Architectが「Write使用」「Edit使用」を報告しているか
- ✅ 更新内容がユーザー要求と一致しているか

**NGパターン**：
- ❌ Architectが「作成しました」と報告したが、ファイルが存在しない
- ❌ Architectが内容だけ報告して、Write/Editツールを使用していない
- ❌ CEOが確認せずに次のステップに進む

**ファイルが存在しない場合の対応**：
1. Architectに再度明確に指示（「必ずWriteツールを使ってファイルを作成せよ」）
2. それでも作成しない場合、CEOが問題を報告してユーザーに判断を仰ぐ

### ステップ4: Implementer呼び出し
CEOは更新された要件定義書の該当箇所のみをImplementerに伝える。

**Implementerへの指示例**：
```
`docs/design/ZZ_requirements.md`の§N.N（Architectが更新した箇所）
に従って実装せよ。

実装後は必ずCheckerを呼び出し、要件定義書との整合性を確認させよ。
```

**禁止事項**：
- CEOが実装の詳細（「line 40をPanelに変更」等）を指示する
- 要件定義書の参照箇所のみを伝える

### ステップ5: Implementer → Checker
Implementerは実装完了後、**自分でCheckerを呼び出す**。

**CheckerへのImplementerからの指示例**：
```
`docs/design/ZZ_requirements.md`の§N.Nと
実装ファイル`scripts/XX.gd`が一致するか確認せよ。
```

**CEOを経由しない**。Implementerが直接Checkerを呼ぶ。

## 適用範囲
以下の全てに適用：
- バグ修正
- 機能追加
- UI変更
- リファクタリング
- パフォーマンス改善

**例外なし**。緊急時も同じフローを踏む。

## 悪い例（禁止）

### 例1: CEOが直接実装指示
```
CEO → Implementer: 
"RestScreenManager.gd line 40をPanelに変更、
line 109をPanel.new()に変更"
```
→ **禁止**。要件定義書が更新されず、再発する。

### 例2: Architectをスキップ
```
CEO → Implementer: 
"要件定義書は後で更新するので、先に実装して"
```
→ **禁止**。要件定義書と実装が乖離する。

### 例3: CEOがCheckerを呼ぶ
```
CEO → Implementer → 実装完了
CEO → Checker
```
→ **非効率**。ImplementerがCheckerを直接呼べば1ステップ減る。

## 良い例

### 例: 左サイドバーをPanelに変更
```
1. ユーザー: 「左サイドバーの背景が表示されない」
   ↓
2. CEO → Architect:
   「RestScreen左サイドバーをPanelContainerからPanelに変更する仕様を
   `docs/design/rest_screen_requirements.md`の§5.2に追記せよ」
   ↓
3. Architect → 要件定義書更新 + サマリー返却
   ↓
4. CEO → Implementer:
   「`docs/design/rest_screen_requirements.md`の§5.2（Architect更新箇所）
   に従って実装せよ。完了後はCheckerを呼び出せ」
   ↓
5. Implementer → 実装 → Checker呼び出し
   Implementer → Checker:
   「`docs/design/rest_screen_requirements.md`の§5.2と
   RestScreenManager.gdが一致するか確認せよ」
```

## 理由（Why）
ユーザーフィードバック：
- 「お前みたいなゴミに直接指示してても一生直らない」
- 「要件定義書を修正してからインプリして、チェッカーが要件定義書と比較するようにして」

**問題**：
- 直接実装指示では同じミスが繰り返される
- 要件定義書が最新化されないと整合性が取れない
- 後から見たとき何が正しい仕様か分からない

**解決**：
- 要件定義書を Single Source of Truth にする
- 全ての変更を要件定義書に記録する
- Checkerが要件定義書と実装を比較できる

## 要件定義書の管理

### 対象ファイル
- `docs/design/*_requirements.md` - 機能別要件定義書
- `docs/design/*_ux_plan.md` - UI/UX企画書

### 更新時の注意
- セクション番号を明示（§3.2等）
- 更新日とコミットハッシュを記録
- 廃止した仕様も削除せず「廃止」マークを付ける

### 要件定義書がない場合
新機能追加時、要件定義書がまだ存在しない場合：
1. Architectに要件定義書の新規作成を依頼
2. テンプレートは既存の`*_requirements.md`を参考
3. 作成後、通常フローで実装

## CLAUDE.mdへの追記
このワークフローは`CLAUDE.md`の「Agent起動ルール」セクションにも反映すること。
