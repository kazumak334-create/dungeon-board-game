#!/bin/bash
# Implementer SubagentStop hook
# Phase 2 Step 5 段階1 (warn mode)
# 作成日: 2026-04-23
#
# 目的: Implementer 完了時に構文チェックと禁止用語/廃止設計の検知を行う
# モード: warn（失敗でも exit 0、標準エラーに警告のみ。1-2週間運用後に block モードへ）
#
# 切替え方法（段階2=block モード化）:
#   最終行の "exit 0" を "exit $EXIT_CODE" に変更

set +e

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
LOG_FILE="$PROJECT_DIR/.claude/hooks/implementer-post-check.log"
EXIT_CODE=0

# ログローテーション（100KB超で削除）
if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE")" -gt 100000 ]; then
    rm -f "$LOG_FILE"
fi

echo "=== Implementer Post-Check [$(date '+%Y-%m-%d %H:%M:%S')] ===" >> "$LOG_FILE"

# -----------------------------------------------------------------------------
# 1. 構文チェック（check_syntax.sh）
# -----------------------------------------------------------------------------
echo "--- [1/2] Syntax Check ---" >> "$LOG_FILE"
if [ -f "$PROJECT_DIR/check_syntax.sh" ]; then
    bash "$PROJECT_DIR/check_syntax.sh" >> "$LOG_FILE" 2>&1
    SYNTAX_EXIT=$?
    if [ $SYNTAX_EXIT -ne 0 ]; then
        echo "⚠️  WARN: 構文チェック失敗 (exit $SYNTAX_EXIT)" >&2
        echo "⚠️  詳細: $LOG_FILE" >&2
        EXIT_CODE=2
    fi
else
    echo "SKIP: check_syntax.sh が見つからない" >> "$LOG_FILE"
fi

# -----------------------------------------------------------------------------
# 2. 禁止用語・廃止設計 grep 検査（差分対象のみ）
# -----------------------------------------------------------------------------
echo "--- [2/2] Forbidden Terms Check ---" >> "$LOG_FILE"

FORBIDDEN_FILE="$PROJECT_DIR/docs/meta/ssot_forbidden_patterns.txt"
CHANGED_FILES=$(cd "$PROJECT_DIR" && git diff --name-only HEAD 2>/dev/null | grep -E '\.(gd|json|md)$')

if [ -z "$CHANGED_FILES" ]; then
    echo "SKIP: 変更ファイルなし" >> "$LOG_FILE"
elif [ ! -f "$FORBIDDEN_FILE" ]; then
    echo "SKIP: $FORBIDDEN_FILE が見つからない" >> "$LOG_FILE"
else
    # 禁止用語リストを抽出（コメント・空行除外、'|' 区切り1列目）
    TERMS=$(grep -vE '^\s*#|^\s*$' "$FORBIDDEN_FILE" | awk -F'|' '{gsub(/^ +| +$/, "", $1); if ($1 != "") print $1}')

    FORBIDDEN_HITS=""
    for term in $TERMS; do
        # 正規表現メタ文字を素朴にエスケープ
        [ -z "$term" ] && continue
        for file in $CHANGED_FILES; do
            fullpath="$PROJECT_DIR/$file"
            [ ! -f "$fullpath" ] && continue
            matches=$(grep -nE "\\b${term}\\b" "$fullpath" 2>/dev/null | head -3)
            if [ -n "$matches" ]; then
                FORBIDDEN_HITS="${FORBIDDEN_HITS}[${term}] ${file}:\n${matches}\n"
            fi
        done
    done

    if [ -n "$FORBIDDEN_HITS" ]; then
        echo "⚠️  WARN: 禁止用語を検出（docs/meta/ssot_forbidden_patterns.txt 参照）" >&2
        echo -e "$FORBIDDEN_HITS" >&2
        EXIT_CODE=2
    fi
fi

echo "--- Done (exit_code=$EXIT_CODE, mode=warn) ---" >> "$LOG_FILE"

# 段階1 warn mode: 常に exit 0（警告のみ、ブロックしない）
# 段階2 block mode に移行する際は下記を "exit $EXIT_CODE" に変更
exit 0
