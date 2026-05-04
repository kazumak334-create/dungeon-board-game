#!/bin/bash

GODOT="/c/Users/kazum/OneDrive/デスクトップ/プライベート/Godot/Godot_v4.6.2-stable_win64.exe"
PROJECT_PATH="/c/Users/kazum/dungeon-board-game"

echo "=== 全GDScriptファイルの構文チェック ==="
echo ""

errors_found=0

# すべての.gdファイルをチェック
find scripts -name "*.gd" 2>/dev/null | while read -r file; do
    result=$("$GODOT" --path "$PROJECT_PATH" --headless --check-only "$file" 2>&1)

    # Parser ErrorまたはERRORを含む行を抽出
    if echo "$result" | grep -q "Parser Error\|^ERROR:"; then
        echo "❌ $file"
        echo "$result" | grep -A 3 "Parser Error\|^ERROR:"
        echo ""
        errors_found=$((errors_found + 1))
    fi
done

if [ $errors_found -eq 0 ]; then
    echo "✅ エラーなし"
else
    echo "❌ $errors_found 件のエラー検出"
fi
