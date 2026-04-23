#!/bin/bash
# Godotの全警告・エラーを一律取得してログファイルに出力
# エディタのデバッガと同等の情報（UNUSED_VARIABLE/PARAMETER/SHADOWED_VARIABLE 等を含む）
#
# 使用方法:
#   bash check_all_warnings.sh

GODOT="/c/Users/kazum/OneDrive/デスクトップ/プライベート/Godot/Godot_v4.6.2-stable_win64.exe"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$PROJECT_DIR/godot_warnings.log"

cd "$PROJECT_DIR"

echo "=== $(date '+%Y-%m-%d %H:%M:%S') Godot全警告取得 ==="
echo "Output: $LOG_FILE"
echo ""

# ヘッダ付きでログ新規作成
{
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') Godot全警告取得 ==="
    echo "Project: $PROJECT_DIR"
    echo ""
} > "$LOG_FILE"

# --check-only で全スクリプトを解析して警告を出力
timeout 90 "$GODOT" --path . --headless --check-only 2>&1 | tee -a "$LOG_FILE"

# -----------------------------------------------------------------------------
# 集計サマリー
# -----------------------------------------------------------------------------
echo ""
echo "=== 集計サマリー ==="

declare -a CATEGORIES=(
    "SCRIPT ERROR"
    "Parse Error"
    "UNUSED_VARIABLE"
    "UNUSED_PARAMETER"
    "UNUSED_PRIVATE_CLASS_VARIABLE"
    "UNUSED_LOCAL_CONSTANT"
    "SHADOWED_VARIABLE"
    "SHADOWED_VARIABLE_BASE_CLASS"
    "NARROWING_CONVERSION"
    "INCOMPATIBLE_TERNARY"
    "UNSAFE_PROPERTY_ACCESS"
    "UNSAFE_METHOD_ACCESS"
    "UNSAFE_CAST"
    "UNSAFE_CALL_ARGUMENT"
    "RETURN_VALUE_DISCARDED"
    "STANDALONE_EXPRESSION"
    "REDUNDANT_AWAIT"
    "ASSERT_ALWAYS_TRUE"
    "ASSERT_ALWAYS_FALSE"
    "INTEGER_DIVISION"
    "STATIC_CALLED_ON_INSTANCE"
    "CONFUSABLE_IDENTIFIER"
    "CONFUSABLE_LOCAL_DECLARATION"
)

TOTAL=0
for cat in "${CATEGORIES[@]}"; do
    count=$(grep -c "$cat" "$LOG_FILE")
    if [ "$count" -gt 0 ]; then
        printf "  %-35s %4d件\n" "$cat" "$count"
        TOTAL=$((TOTAL + count))
    fi
done

echo "  -----------------------------------"
printf "  %-35s %4d件\n" "合計（既知カテゴリ）" "$TOTAL"
echo ""
echo "完了: $LOG_FILE"
