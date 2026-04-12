#!/bin/bash
GODOT="/c/Users/kazum/OneDrive/デスクトップ/プライベート/Godot/Godot_v4.6.2-stable_win64.exe"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== 構文チェック開始 ==="
cd "$PROJECT_DIR"
SYNTAX_ERRORS=$(timeout 30 "$GODOT" --path . --headless --check-only 2>&1 | grep -i "Parser Error\|Compile Error\|SCRIPT ERROR" | head -10)

if [ -n "$SYNTAX_ERRORS" ]; then
    echo "=== 構文エラー検出 ==="
    echo "$SYNTAX_ERRORS"
    echo "FAILED: 構文エラーあり"
    exit 1
fi
echo "✓ 構文チェックパス"
echo "=== 完了 ==="
exit 0
