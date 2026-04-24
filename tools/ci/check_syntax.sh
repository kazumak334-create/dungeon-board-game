#!/bin/bash
GODOT="/c/Users/kazum/OneDrive/デスクトップ/プライベート/Godot/Godot_v4.6.2-stable_win64.exe"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "=== Godotチェック開始 ==="
cd "$PROJECT_DIR"
ERRORS=$(timeout 30 "$GODOT" --path . --headless --check-only 2>&1 \
    | grep -iE "Parse error|Parser Error|Compile Error|SCRIPT ERROR|Invalid|Cannot|Expected|Unexpected|Type mismatch|Trying to assign" \
    | grep -v "RID allocations\|Unreferenced static string\|Thread object\|PagedAllocator" \
    | head -20)

if [ -n "$ERRORS" ]; then
    echo "❌ エラー検出:"
    echo "$ERRORS"
    echo "FAILED"
    exit 1
fi
echo "✅ Godotチェックパス"

# UI継承チェック実行
echo ""
bash "$(dirname "$0")/check_ui_inheritance.sh"
UI_CHECK_EXIT=$?

if [ $UI_CHECK_EXIT -ne 0 ]; then
    echo "FAILED: UI継承チェックで問題検出"
    exit 1
fi

echo "=== 完了 ==="
exit 0
