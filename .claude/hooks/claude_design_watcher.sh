#!/usr/bin/env bash
# claude_design_watcher.sh
# 役割：docs/design/handoff/ の未処理bundleを検知し、DesignerAgentを起動する
# トリガー：UserPromptSubmit hook / Stop hook（非ブロッキング）

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HANDOFF_DIR="$PROJECT_ROOT/docs/design/handoff"
PROCESSED_DIR="$HANDOFF_DIR/processed"
ERROR_LOG="$HANDOFF_DIR/.errors.log"
ADAPTER="$SCRIPT_DIR/lib/handoff_adapter.sh"

# handoff フォルダが存在しない場合はスキップ
if [[ ! -d "$HANDOFF_DIR" ]]; then
  exit 0
fi

# .bundle.json または .bundle.md を検索
BUNDLES=()
while IFS= read -r -d '' f; do
  BUNDLES+=("$f")
done < <(find "$HANDOFF_DIR" -maxdepth 1 \( -name "*.bundle.json" -o -name "*.bundle.md" \) -print0 2>/dev/null)

if [[ ${#BUNDLES[@]} -eq 0 ]]; then
  exit 0
fi

TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

for BUNDLE in "${BUNDLES[@]}"; do
  BASENAME=$(basename "$BUNDLE")

  # adapter でプロンプト生成
  if PROMPT=$(bash "$ADAPTER" "$BUNDLE" 2>>"$ERROR_LOG"); then
    # DesignerAgent 呼び出し（非インタラクティブ）
    if cd "$PROJECT_ROOT" && claude -p "$PROMPT" --output-format text &>/dev/null; then
      # 成功時：processed/ に移動
      mv "$BUNDLE" "$PROCESSED_DIR/${TIMESTAMP}_${BASENAME}"
    else
      echo "[$(date)] DesignerAgent呼び出し失敗: $BASENAME" >>"$ERROR_LOG"
    fi
  else
    echo "[$(date)] adapter解析失敗: $BASENAME" >>"$ERROR_LOG"
  fi
done
