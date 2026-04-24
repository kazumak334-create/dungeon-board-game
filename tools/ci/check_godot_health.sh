#!/bin/bash
# check_godot_health.sh
# Godot Engine内部エラー・リソースリーク検出スクリプト
#
# 用途: Godot Engineの内部状態をチェックし、リソースリークや警告を検出する
# check_syntax.sh（スクリプト構文チェック）とは別に実行する

GODOT="/c/Users/kazum/OneDrive/デスクトップ/プライベート/Godot/Godot_v4.6.2-stable_win64.exe"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Godot Health Check 開始 ==="
cd "$PROJECT_DIR"

# Godot実行してエラー出力を取得
GODOT_OUTPUT=$(timeout 30 "$GODOT" --path . --headless --check-only 2>&1)

# 1. RIDリーク検出
RID_LEAKS=$(echo "$GODOT_OUTPUT" | grep -i "RID allocations.*leaked")
if [ -n "$RID_LEAKS" ]; then
    echo "⚠️  RIDリーク検出:"
    echo "$RID_LEAKS"
fi

# 2. Unreferenced static string 検出
UNREF_STRINGS=$(echo "$GODOT_OUTPUT" | grep -i "Unreferenced static string")
if [ -n "$UNREF_STRINGS" ]; then
    echo "⚠️  Unreferenced static string検出:"
    echo "$UNREF_STRINGS"
fi

# 3. Thread問題検出
THREAD_ISSUES=$(echo "$GODOT_OUTPUT" | grep -i "Thread object is being destroyed")
if [ -n "$THREAD_ISSUES" ]; then
    echo "⚠️  Thread終了問題検出:"
    echo "$THREAD_ISSUES"
fi

# 4. PagedAllocatorリーク検出
PAGED_LEAKS=$(echo "$GODOT_OUTPUT" | grep -i "Pages in use exist at exit")
if [ -n "$PAGED_LEAKS" ]; then
    echo "⚠️  PagedAllocatorリーク検出:"
    echo "$PAGED_LEAKS"
fi

# 5. その他のERROR（スクリプトエラー以外）
OTHER_ERRORS=$(echo "$GODOT_OUTPUT" | grep -i "^ERROR:" | grep -v "RID allocations\|Unreferenced static string\|Pages in use")
if [ -n "$OTHER_ERRORS" ]; then
    echo "⚠️  その他のエラー:"
    echo "$OTHER_ERRORS"
fi

# 総合判定
if [ -z "$RID_LEAKS" ] && [ -z "$UNREF_STRINGS" ] && [ -z "$THREAD_ISSUES" ] && [ -z "$PAGED_LEAKS" ] && [ -z "$OTHER_ERRORS" ]; then
    echo "✓ Godot Engine内部エラーなし"
    echo "=== 完了 ==="
    exit 0
else
    echo ""
    echo "=== 警告 ==="
    echo "Godot Engine内部で問題が検出されました。"
    echo "これらはスクリプトエラーではありませんが、将来的に問題になる可能性があります。"
    echo "=== 完了 ==="
    exit 1
fi
