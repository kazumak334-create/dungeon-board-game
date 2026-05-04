#!/bin/bash

echo "=== UI継承チェック開始 ==="

ERRORS=0
CHECKED=0

# RefCounted または Node を継承しているファイルを検索
REFCOUNTED_FILES=$(grep -rl "^extends RefCounted" scripts/ --include="*.gd" 2>/dev/null || true)
NODE_FILES=$(grep -rl "^extends Node$" scripts/ --include="*.gd" 2>/dev/null || true)

ALL_FILES="$REFCOUNTED_FILES
$NODE_FILES"

# UI操作パターン（Control必須の操作）
UI_PATTERNS=(
    "\.position\s*="
    "set_position\("
    "\.size\s*="
    "set_size\("
    "set_anchors_and_offsets_preset\("
)

for file in $ALL_FILES; do
    [ -z "$file" ] && continue
    [ ! -f "$file" ] && continue

    CHECKED=$((CHECKED + 1))

    # 継承元を確認
    EXTENDS=$(grep -E "^extends (RefCounted|Node)$" "$file" | head -1)

    # UI操作をしているか確認
    HAS_UI_OPS=false
    for pattern in "${UI_PATTERNS[@]}"; do
        if grep -qE "$pattern" "$file" 2>/dev/null; then
            HAS_UI_OPS=true
            break
        fi
    done

    if [ "$HAS_UI_OPS" = true ]; then
        echo "❌ $file"
        echo "   継承: $EXTENDS"
        echo "   問題: UI操作をしているがControlを継承していない"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "チェック完了: $CHECKED ファイル"

if [ $ERRORS -gt 0 ]; then
    echo "❌ 問題検出: $ERRORS ファイル"
    echo ""
    echo "修正方法:"
    echo "  extends RefCounted → extends Control"
    echo "  extends Node → extends Control"
    exit 1
fi

echo "✅ 問題なし"
exit 0
