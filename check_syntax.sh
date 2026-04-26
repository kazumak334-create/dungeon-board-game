#!/bin/bash
GODOT="/c/Users/kazum/OneDrive/デスクトップ/プライベート/Godot/Godot_v4.6.2-stable_win64.exe"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== 構文チェック ==="
cd "$PROJECT_DIR"

# Godot --check-only で全スクリプトをパース
RAW=$(timeout 90 "$GODOT" --path . --headless --check-only 2>&1)

# パーサーエラー・コンパイルエラーを抽出
ERRORS=$(echo "$RAW" \
    | grep -iE "Parse[r]? [Ee]rror|Compile [Ee]rror|SCRIPT ERROR|has the same name|Standalone lambda|Cannot be accessed|Expected|Unexpected identifier|Invalid get|Type mismatch|Identifier .* not declared" \
    | grep -vE "RID allocations|Unreferenced static|Thread object|PagedAllocator|GDScript Warning")

ERROR_COUNT=$(echo "$ERRORS" | grep -c . || true)

if [ -n "$ERRORS" ] && [ "$ERROR_COUNT" -gt 0 ]; then
    echo "❌ パーサーエラー ${ERROR_COUNT}件:"
    echo "$ERRORS"
    echo ""
    echo "FAILED"
    exit 1
fi
echo "✓ 構文チェックパス"

echo "=== 完了 ==="
exit 0
