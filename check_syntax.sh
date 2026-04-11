#!/bin/bash
GODOT="/c/Users/kazum/OneDrive/デスクトップ/プライベート/Godot/Godot_v4.6.2-stable_win64.exe"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== 構文チェック開始 ==="
ERROR_COUNT=0
while IFS= read -r f; do
    result=$("$GODOT" --headless --check-only --script "$f" 2>&1)
    if [ $? -ne 0 ]; then
        echo "ERROR: $f"
        echo "$result"
        ERROR_COUNT=$((ERROR_COUNT + 1))
    fi
done < <(find "$PROJECT_DIR/scripts" -name "*.gd")

if [ $ERROR_COUNT -eq 0 ]; then
    echo "OK: 構文エラーなし"
else
    echo "FAILED: $ERROR_COUNT ファイルにエラーあり"
fi
echo "=== 完了 ==="
