#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
session_check.py
セッション開始時に設計・ファイル腐敗の問題を自動検出する
"""

import os
import re
from pathlib import Path
from datetime import datetime, timedelta

# リポジトリルート
REPO_ROOT = Path(__file__).resolve().parent.parent

def check_required_files():
    """必須ファイルの存在確認"""
    required_files = [
        "docs/GAME_DESIGN.md",
        "docs/game_philosophy.md",
        "docs/meta/agents.md",
        "docs/meta/sprint.md",
        "docs/meta/rejection_patterns.md",
        "CLAUDE.md",
        ".claude/projects/C--Users-kazum-dungeon-board-game/memory/MEMORY_SHARED.md",
    ]

    missing = []
    for file_path in required_files:
        full_path = REPO_ROOT / file_path if not file_path.startswith(".claude") else Path.home() / file_path
        if not full_path.exists():
            missing.append(file_path)

    return missing

def check_memory_shared_references():
    """MEMORY_SHAREDの参照先確認"""
    memory_shared_path = Path.home() / ".claude/projects/C--Users-kazum-dungeon-board-game/memory/MEMORY_SHARED.md"

    if not memory_shared_path.exists():
        return ["MEMORY_SHARED.md が存在しません"]

    issues = []

    try:
        with open(memory_shared_path, 'r', encoding='utf-8') as f:
            content = f.read()

            # ファイルパスの参照を抽出（docs/から始まるパス）
            references = re.findall(r'docs/[^\s\)]+\.md', content)

            for ref in references:
                ref_path = REPO_ROOT / ref
                if not ref_path.exists():
                    issues.append(f"{ref} が存在しません")

    except Exception as e:
        issues.append(f"MEMORY_SHARED.md 読み込みエラー: {e}")

    return issues

def check_deprecated_in_code():
    """廃止済み設計のコード混入確認"""
    game_design_path = REPO_ROOT / "docs/GAME_DESIGN.md"

    if not game_design_path.exists():
        return ["GAME_DESIGN.md が存在しません"]

    # GAME_DESIGN.mdから廃止リストを読み込む
    deprecated_keywords = []
    try:
        with open(game_design_path, 'r', encoding='utf-8') as f:
            content = f.read()

            # 廃止リストのセクションを抽出
            deprecated_section = re.search(
                r'## 廃止済み設計.*?\n(.*?)(?=\n## |$)',
                content,
                re.DOTALL
            )

            if deprecated_section:
                # キーワードを抽出（簡易的に）
                deprecated_keywords = [
                    'spawn_unit',
                    'summon_unit',
                    'mana_regen_timer',
                    'active_skill',
                    'passive_skill',
                    'row_range',
                    'direct_damage_to_base',
                ]
    except Exception as e:
        return [f"GAME_DESIGN.md 読み込みエラー: {e}"]

    # scripts/以下の.gdファイルをチェック
    scripts_dir = REPO_ROOT / "scripts"
    if not scripts_dir.exists():
        return []

    issues = []
    gd_files = list(scripts_dir.glob("*.gd"))

    for gd_file in gd_files:
        try:
            with open(gd_file, 'r', encoding='utf-8') as f:
                content = f.read()
                for keyword in deprecated_keywords:
                    if keyword in content:
                        issues.append(f"{gd_file.name}: {keyword} が使用されています")
        except Exception as e:
            issues.append(f"{gd_file.name} 読み込みエラー: {e}")

    return issues

def check_game_design_update():
    """GAME_DESIGN.mdの最終更新日確認"""
    game_design_path = REPO_ROOT / "docs/GAME_DESIGN.md"

    if not game_design_path.exists():
        return "GAME_DESIGN.md が存在しません"

    try:
        # ファイルの最終更新日を取得
        mtime = datetime.fromtimestamp(game_design_path.stat().st_mtime)
        now = datetime.now()
        days_ago = (now - mtime).days

        if days_ago > 7:
            return f"最終更新から{days_ago}日経過"

        return None
    except Exception as e:
        return f"更新日確認エラー: {e}"

def main():
    print("🔍 セッション開始チェック結果\n")

    total_issues = 0

    # チェック1: 必須ファイル
    missing_files = check_required_files()
    if missing_files:
        print(f"❌ 必須ファイル：{len(missing_files)}件の問題\n")
        for file in missing_files:
            print(f"  {file} が存在しません")
        print()
        total_issues += len(missing_files)
    else:
        print("✅ 必須ファイル：全て存在")

    # チェック2: MEMORY_SHARED参照先
    ref_issues = check_memory_shared_references()
    if ref_issues:
        print(f"❌ MEMORY_SHARED参照先：{len(ref_issues)}件の問題\n")
        for issue in ref_issues:
            print(f"  {issue}")
        print()
        total_issues += len(ref_issues)
    else:
        print("✅ MEMORY_SHARED参照先：問題なし")

    # チェック3: 廃止済み設計
    deprecated_issues = check_deprecated_in_code()
    if deprecated_issues:
        print(f"❌ 廃止済み設計：{len(deprecated_issues)}件のコード混入\n")
        for issue in deprecated_issues:
            print(f"  {issue}")
        print()
        total_issues += len(deprecated_issues)
    else:
        print("✅ 廃止済み設計：コード混入なし")

    # チェック4: GAME_DESIGN.md最終更新日
    update_warning = check_game_design_update()
    if update_warning:
        print(f"⚠️  GAME_DESIGN.md：{update_warning}")
        total_issues += 1
    else:
        print("✅ GAME_DESIGN.md：最近更新されています")

    # サマリー
    print("\n" + "="*60)
    if total_issues == 0:
        print("✅ 全てグリーン：作業を開始できます")
    else:
        print(f"⚠️  問題が{total_issues}件あります。作業前に修正することを推奨します。")
    print("="*60)

if __name__ == "__main__":
    main()
