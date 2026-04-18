#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GDScript静的チェックツール
全エラーを洗い出すため、godot --check-onlyに頼らない
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

            # 1. インデント不整合チェック（タブ/スペース混在）
            has_tabs = False
            has_spaces = False
            for i, line in enumerate(lines, 1):
                if line.startswith('\t'):
                    has_tabs = True
                elif line.startswith(' '):
                    has_spaces = True
                if has_tabs and has_spaces:
                    errors.append(f"{path}:{i}: インデント混在（タブとスペース）")
                    break

            # 2. 空のforブロック・ifブロックチェック
            for i, line in enumerate(lines, 1):
                stripped = line.rstrip()

                # forブロックが空
                if re.search(r'^\s+for .+ in .+:\s*$', stripped):
                    if i < len(lines):
                        next_line = lines[i].rstrip()
                        indent = len(line) - len(line.lstrip())
                        if next_line.strip():
                            next_indent = len(next_line) - len(next_line.lstrip())
                            # 次の行のインデントが同じか少ない = 空ブロック
                            if next_indent <= indent and not next_line.strip().startswith("#"):
                                errors.append(f"{path}:{i}: 空のforブロック")

                # ifブロックが空（elifやelseの前で終わる）
                if re.search(r'^\s+if .+:\s*$', stripped):
                    if i < len(lines):
                        next_line = lines[i].rstrip()
                        indent = len(line) - len(line.lstrip())
                        if next_line.strip():
                            next_indent = len(next_line) - len(next_line.lstrip())
                            # 次がelif/elseまたはインデントが同じ/少ない = 空ブロック
                            if next_indent <= indent and not next_line.strip().startswith("#"):
                                if re.match(r'^\s*(elif|else)', next_line):
                                    errors.append(f"{path}:{i}: 空のifブロック")

            # 3. return文で未宣言変数チェック（簡易版）
            declared_vars = set()
            in_function = False
            for i, line in enumerate(lines, 1):
                stripped = line.strip()

                # 関数開始
                if re.match(r'^func\s+\w+', stripped):
                    declared_vars.clear()
                    in_function = True
                    # 関数引数を宣言済み変数に追加
                    match = re.search(r'func\s+\w+\s*\((.*?)\)', stripped)
                    if match:
                        args = match.group(1)
                        for arg in args.split(','):
                            arg_name = arg.split(':')[0].strip()
                            if arg_name:
                                declared_vars.add(arg_name)

                # 変数宣言
                if in_function:
                    var_match = re.match(r'\s*var\s+(\w+)', stripped)
                    if var_match:
                        declared_vars.add(var_match.group(1))

                # return文チェック
                if in_function and stripped.startswith('return '):
                    return_expr = stripped[7:].strip()
                    # 変数名を抽出（簡易版：単純な変数名のみ）
                    if re.match(r'^[a-zA-Z_]\w*$', return_expr):
                        if return_expr not in declared_vars and return_expr not in ['true', 'false', 'null']:
                            # ビルトインや定数は除外
                            if not return_expr.isupper() and return_expr not in ['self']:
                                errors.append(f"{path}:{i}: return文で未宣言の変数 '{return_expr}'")

            # 4. 文字列フォーマットエラーチェック
            for i, line in enumerate(lines, 1):
                # % 演算子を使った文字列フォーマット
                if ' % ' in line or ' %[' in line or ' %{' in line:
                    # print("デバッグ: %s" % variable) のようなパターン
                    # 配列/辞書を [] で囲んでいないパターンを検出
                    matches = re.findall(r'%\s+([a-zA-Z_]\w*)\s*(?:\)|$)', line)
                    if matches:
                        # 変数名が直接 % の後にある（[]で囲まれていない）
                        errors.append(f"{path}:{i}: 文字列フォーマットエラー: 配列/辞書を[]で囲む必要がある")

    return errors

if __name__ == "__main__":
    print("=== GDScript静的チェック開始 ===\n")

    errors = check_gdscript_files("scripts")

    if errors:
        print(f"検出されたエラー: {len(errors)}件\n")
        for error in errors:
            print(error)
        sys.exit(1)
    else:
        print("✓ エラーなし")
        sys.exit(0)
