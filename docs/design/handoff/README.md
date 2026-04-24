# Claude Design handoff bundle 受取フォルダ

## 使い方
1. Claude Design で生成した handoff bundle ファイルをこのフォルダに置く
2. 次のユーザープロンプト送信または Claude Code セッション終了時に自動処理される
3. 出力：`docs/design/<YYYYMMDD_HHMMSS>_from_claude_design.md`

## 対応拡張子
- `.bundle.json`
- `.bundle.md`

## エラー時
- `.errors.log` にエラーが記録される
- 処理失敗したファイルはこのフォルダに残る（次回リトライ）

## 処理済みファイル
`processed/` フォルダに移動されます

## jq が未導入の場合
JSON形式の bundle を処理するには `jq` が必要です。
インストール方法（Git Bash）:
```bash
# Chocolatey 経由
choco install jq

# Scoop 経由
scoop install jq

# winget 経由
winget install jqlang.jq
```
jq が未導入の場合は bundle ファイル全体がそのままプロンプトに転記されます（フォールバック動作）。
