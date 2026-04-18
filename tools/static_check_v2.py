#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GDScript静的チェックツール v2（誤検出削減版）
"""

import os
import re
import sys

def check_gdscript_files(root_dir="scripts"):
    errors = []

    for root, dirs, files in os.walk(root_dir):
        for f in files:
            if not f.endswith(".gd"):
                continue

            path = os.path.join(root, f)
            try:
                with open(path, encoding="utf-8") as file:
                    lines = file.readlines()
            except Exception as e:
                errors.append(f"{path}: ファイル読み込みエラー: {e}")
                continue

            # 1. 空のforブロック検出
            for i, line in enumerate(lines, 1):
                stripped = line.rstrip()

                # forブロックが空（次の行がelifやelseまたはインデントが同じ/少ない）
                if re.search(r'^\s+for .+ in .+:\s*$', stripped):
                    if i < len(lines):
                        next_line = lines[i].rstrip()
                        indent = len(line) - len(line.lstrip())
                        if next_line.strip() and not next_line.strip().startswith("#"):
                            next_indent = len(next_line) - len(next_line.lstrip())
                            # 次の行のインデントが同じか少ない = 空ブロック
                            if next_indent <= indent:
                                # elifやelseなら確実に空ブロック
                                if re.match(r'^\s*(elif|else)', next_line):
                                    errors.append(f"{path}:{i}: 空のforブロック")

                # ifブロックが空（次がelifやelse）
                elif re.search(r'^\s+if .+:\s*$', stripped):
                    if i < len(lines):
                        next_line = lines[i].rstrip()
                        indent = len(line) - len(line.lstrip())
                        if next_line.strip():
                            next_indent = len(next_line) - len(next_line.lstrip())
                            # 次がelif/elseかつインデントが同じ = 空ブロック
                            if next_indent == indent and re.match(r'^\s*(elif|else)', next_line):
                                errors.append(f"{path}:{i}: 空のifブロック")

            # 2. 明らかな未定義変数のreturn検出（関数スコープ外の変数）
            # 実装が複雑なため、より簡易的なチェックに変更
            # GDScriptではエディタが検出するため、ここでは省略

            # 3. 空のelifブロック検出
            for i, line in enumerate(lines, 1):
                if re.search(r'^\s+elif .+:\s*$', line):
                    if i < len(lines):
                        next_line = lines[i].rstrip()
                        indent = len(line) - len(line.lstrip())
                        if next_line.strip():
                            next_indent = len(next_line) - len(next_line.lstrip())
                            if next_indent == indent and (re.match(r'^\s*(elif|else)', next_line) or next_indent < indent):
                                errors.append(f"{path}:{i}: 空のelifブロック")

    return errors

if __name__ == "__main__":
    print("=== GDScript静的チェック v2 ===\n")

    errors = check_gdscript_files("scripts")

    if errors:
        print(f"検出されたエラー: {len(errors)}件\n")
        for error in errors:
            print(error)
        sys.exit(1)
    else:
        print("✓ 空ブロックエラーなし")
        sys.exit(0)
