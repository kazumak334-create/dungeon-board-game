#!/usr/bin/env bash
# handoff_adapter.sh
# 役割：bundle形式の違いを吸収し、DesignerAgent向けテキストを標準出力する
# 使い方：bash .claude/hooks/lib/handoff_adapter.sh <bundle_path>
# 終了コード：0=成功, 1=解析失敗
#
# API webhook 対応時の差し替えポイント：
#   引数が http:// または https:// で始まる場合 → curl で取得（未実装・将来用）

set -euo pipefail

BUNDLE_PATH="${1:-}"

if [[ -z "$BUNDLE_PATH" ]]; then
  echo "ERROR: bundle path required" >&2
  exit 1
fi

if [[ ! -f "$BUNDLE_PATH" ]]; then
  echo "ERROR: file not found: $BUNDLE_PATH" >&2
  exit 1
fi

EXT="${BUNDLE_PATH##*.}"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')

case "$EXT" in
  json)
    # JSON形式：jq で主要フィールドを抽出（jq未導入の場合はfallbackでファイル全体転記）
    if command -v jq &>/dev/null; then
      PROMPT=$(jq -r '.prompt // "（元プロンプト不明）"' "$BUNDLE_PATH" 2>/dev/null || echo "（解析失敗）")
      SCREEN=$(jq -r '.artifacts.screen_name // "（画面名不明）"' "$BUNDLE_PATH" 2>/dev/null || echo "（不明）")
      DESC=$(jq -r '.artifacts.description // ""' "$BUNDLE_PATH" 2>/dev/null || echo "")
      GENERATED=$(jq -r '.generated_at // "不明"' "$BUNDLE_PATH" 2>/dev/null || echo "不明")
      BUNDLE_BODY="画面名: $SCREEN
説明: $DESC
元プロンプト: $PROMPT
生成日時: $GENERATED
---
$(cat "$BUNDLE_PATH")"
    else
      BUNDLE_BODY=$(cat "$BUNDLE_PATH")
    fi
    ;;
  md)
    # Markdown形式：フロントマターを除去して本文のみ転記
    BUNDLE_BODY=$(awk '/^---/{found++; next} found==1{next} {print}' "$BUNDLE_PATH")
    GENERATED=$(date '+%Y-%m-%dT%H:%M:%SZ')
    ;;
  *)
    echo "ERROR: unsupported extension: $EXT" >&2
    exit 1
    ;;
esac

OUTPUT_FILE="docs/design/${TIMESTAMP}_from_claude_design.md"

cat <<EOF
You are acting as the designer agent as defined in .claude/agents/designer.md.

【Claude Design からの handoff】
処理日時: ${TIMESTAMP}
出力先: ${OUTPUT_FILE}

以下のUI/UX案を、designer.mdに定義された企画書フォーマット（6セクション）に変換してください。
UI基準6項目（3秒ルール・視線の一本化・状態の可視化・操作の最小化・配信映え・世界観の匂わせ）を必ず評価すること。

${BUNDLE_BODY}

出力先ファイル: ${OUTPUT_FILE}
EOF
