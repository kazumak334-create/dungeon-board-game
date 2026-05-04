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

# --- grep補完チェック（Godotが未ロードのスクリプトを補完）---
echo "=== 静的パターンチェック ==="
GREP_ERRORS=0

# 型推論エラー①: var x := ["...", "..."][n] は Variant を返し型推論不可（リテラル配列インデックス）
INFER=$(grep -rn 'var [A-Za-z_][A-Za-z0-9_]* := \["\|var [A-Za-z_][A-Za-z0-9_]* := .*\]\[' scripts/ 2>/dev/null | grep '\]\[' || true)
if [ -n "$INFER" ]; then
    echo "❌ 型推論エラー候補①（リテラル配列インデックス・: 型付けが必要）:"
    echo "$INFER"
    GREP_ERRORS=$((GREP_ERRORS + 1))
fi

# 型推論エラー②: var x := array_var[i] は Array 要素が Variant → 型推論不可（変数配列インデックス）
INFER2=$(grep -rn 'var [A-Za-z_][A-Za-z0-9_]* := [a-z_][A-Za-z0-9_]*\[[a-z_]' scripts/ 2>/dev/null || true)
if [ -n "$INFER2" ]; then
    echo "❌ 型推論エラー候補②（変数配列インデックス・: 型付けが必要）:"
    echo "$INFER2"
    GREP_ERRORS=$((GREP_ERRORS + 1))
fi

if [ "$GREP_ERRORS" -eq 0 ]; then
    echo "✓ 静的パターンチェックパス"
else
    echo "FAILED"
    exit 1
fi

# =============================
# [coupling] EconBattle内部配列の直接操作チェック
# =============================
COUPLING_PATTERNS=(
  "enemy_units\.append"
  "enemy_harvesters\.append"
  "enemy_buildings\.append"
  "player_harvesters\.append"
  "player_buildings\.append"
)
COUPLING_FILES=(
  "scripts/econ_mvp/EconAI.gd"
  "scripts/econ_mvp/EconMain.gd"
)
for pattern in "${COUPLING_PATTERNS[@]}"; do
  for file in "${COUPLING_FILES[@]}"; do
    if [ -f "$file" ] && grep -qn "$pattern" "$file" 2>/dev/null; then
      echo "❌ [coupling] $file に直接配列操作: $pattern"
      echo "   → spawn/register メソッドを使ってください (EconBattle)"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

echo ""
echo "=== Deprecated file reference check ==="

# Codex request ファイルが archive/ フォルダのファイルを参照していないか確認
ARCHIVE_REFS=0
for req_file in docs/tasks/codex_request_sprint*.md; do
  if [ -f "$req_file" ]; then
    # archive フォルダのパスを参照しているか確認
    if grep -q "archive/" "$req_file" 2>/dev/null; then
      echo "❌ FATAL: $req_file に廃止ファイル参照が含まれています:"
      grep -n "archive/" "$req_file"
      ARCHIVE_REFS=$((ARCHIVE_REFS + 1))
    fi

    # 旧 req_econ_* ファイルを直接参照しているか確認
    if grep -qE "req_econ_|req_economy_|req_enemyless_|req_battle_|req_buff_|req_dead_|req_material_|req_mvp_|req_skill_|req_support_" "$req_file" 2>/dev/null; then
      echo "❌ WARNING: $req_file に個別要件ファイル参照の可能性:"
      grep -n -E "req_econ_|req_economy_|req_enemyless_|req_battle_|req_buff_|req_dead_|req_material_|req_mvp_|req_skill_|req_support_" "$req_file"
      ARCHIVE_REFS=$((ARCHIVE_REFS + 1))
    fi
  fi
done

if [ "$ARCHIVE_REFS" -gt 0 ]; then
  echo ""
  echo "❌ FAILED: $ARCHIVE_REFS 件の廃止ファイル参照エラーが見つかりました"
  echo "   REQUIREMENTS_SPRINT_*.md から引用してください"
  exit 1
fi

echo "✓ 廃止ファイル参照チェックパス"

echo ""
echo "=== 完了 ==="
exit 0
