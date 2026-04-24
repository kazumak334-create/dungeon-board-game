"""Claude Code向けデバッグ依頼プロンプト生成"""

TEMPLATE = """\
# 自動デバッグ依頼

## 1. 検知ルール
- ルールID: {rule}
- 異常内容: {message}

## 2. 直近ログ（最大50行）
```
{log_tail}
```

## 3. 依頼事項
以下の順で分析・回答してください：

1. **根本原因の特定** - どのファイル・関数で何が起きているか
2. **再現条件** - この異常が起きる最小条件
3. **修正方針** - 修正すべき箇所と方針（ファイル:行番号を明記）
4. **パッチ案** - git diff 形式で修正案を出力（適用可能なもの）
5. **副作用チェック** - 修正による他への影響
6. **テスト案** - 修正確認のための最小テスト手順

## 4. 制約
- 変更はできる限り最小限に
- 設計意図を変えない（CLAUDE.mdの方針を遵守）
- パッチは `git apply --check` で検証してから提示
"""


def build_prompt(anomaly: dict, log_tail: list) -> str:
    return TEMPLATE.format(
        rule=anomaly["rule"],
        message=anomaly["message"],
        log_tail="\n".join(log_tail),
    )
