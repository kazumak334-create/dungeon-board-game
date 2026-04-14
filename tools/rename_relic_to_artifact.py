#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
レリック → アーティファクト 用語統一スクリプト
"""
import os
import re
from pathlib import Path

# 置換ルール
REPLACEMENTS = [
    ("レリック", "アーティファクト"),
    ("relic", "artifact"),
    ("Relic", "Artifact"),
    ("RELIC", "ARTIFACT"),
]

# 対象ディレクトリ
TARGET_DIRS = ["scripts", "docs", "data"]
TARGET_EXTS = [".gd", ".md", ".json"]

def process_file(file_path):
    """ファイル内の用語を置換"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()

        original_content = content

        # 置換実行
        for old, new in REPLACEMENTS:
            content = content.replace(old, new)

        # 変更があった場合のみ書き込み
        if content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return False

def main():
    project_root = Path(__file__).parent.parent
    modified_count = 0

    for target_dir in TARGET_DIRS:
        dir_path = project_root / target_dir
        if not dir_path.exists():
            continue

        for file_path in dir_path.rglob("*"):
            if file_path.suffix in TARGET_EXTS and file_path.is_file():
                if process_file(file_path):
                    modified_count += 1
                    print(f"Modified: {file_path.relative_to(project_root)}")

    print(f"\n置換完了: {modified_count}ファイル")

if __name__ == "__main__":
    main()
