#!/usr/bin/env python3
"""
CSV → cards.json 変換ツール（将来用）

使い方:
  1. スプレッドシートからCSVエクスポート
  2. python tools/csv_to_json.py units.csv --section units
  3. 出力をdata/cards.jsonの該当セクションにマージ

現状はスケルトン。大量編集が必要になった時に実装する。
"""

import csv
import json
import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: python csv_to_json.py <input.csv> [--section units|spells|...]")
        sys.exit(1)

    csv_path = sys.argv[1]
    section = "units"
    if "--section" in sys.argv:
        idx = sys.argv.index("--section")
        if idx + 1 < len(sys.argv):
            section = sys.argv[idx + 1]

    print(f"TODO: {csv_path} → cards.json [{section}] 変換")
    print("このツールは大量編集が必要になった時に実装します")

if __name__ == "__main__":
    main()
