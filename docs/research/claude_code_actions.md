# GitHub Actions × Claude Code 連携 調査レポート

> 調査日: 2026-04-03  
> 調査対象: `anthropics/claude-code-action` v1 系  
> 参考リポジトリ: https://github.com/anthropics/claude-code-action

---

## 概要

`anthropics/claude-code-action` は Anthropic が公式に提供する GitHub Action。  
PR・Issue に対して **Claude Code ランタイムをまるごと CI 上で動かす**ことができる。  
単純な API 呼び出しラッパーではなく、ファイル読み込み・Git 操作・GitHub CLI など  
ツール群を持ったフル Claude Code セッションが GitHub Actions ランナー上で実行される。

---

## 1. Claude Code を GitHub Actions で自動起動する方法

### 1-1. 前提条件

| 項目 | 内容 |
|------|------|
| API キー | `ANTHROPIC_API_KEY` を Repository Secrets に登録 |
| Action バージョン | `anthropics/claude-code-action@v1` |
| runner | `ubuntu-latest` で動作 |
| 代替認証 | AWS Bedrock / Google Vertex AI / Microsoft Foundry も可 |

### 1-2. 最速セットアップ（Claude Code ターミナルから）

```bash
# Claude Code のターミナルで実行（リポジトリ管理者権限必要）
claude
/install-github-app
```

上記コマンドが GitHub App のインストールと Secret 設定を対話的にガイドしてくれる。  
（Anthropic 直接 API 利用者限定。Bedrock/Vertex は docs/cloud-providers.md 参照）

### 1-3. 動作モードの自動判定

| モード | 条件 | 説明 |
|--------|------|------|
| **Automation モード** | workflow に `prompt:` を定義している | 起動即実行。トラッキングコメントなし |
| **Interactive モード** | `prompt:` なし | PR/Issue への `@claude` メンションで起動 |

### 1-4. 基本的な最小ワークフロー

```yaml
# .github/workflows/claude-review.yml
name: Claude Code Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: "Review this PR for bugs, security issues, and code quality."
```

---

## 2. push / PR トリガーでコードレビューを自動化している事例

### 2-1. 公式リポジトリのユースケース一覧

`anthropics/claude-code-action` の [Solutions Guide](https://github.com/anthropics/claude-code-action/blob/main/docs/solutions.md) より：

- **Automatic PR Code Review** — PR の open/更新ごとに自動レビュー
- **Path-Specific Reviews** — 特定ファイル変更時のみトリガー
- **External Contributor Reviews** — 初回コントリビュータへの厳格レビュー
- **Custom Review Checklists** — チーム独自のチェックリストを強制適用
- **Scheduled Maintenance** — `cron` による定期的なリポジトリ健全性チェック
- **Issue Auto-Triage** — Issue 作成時に自動ラベル付け
- **Documentation Sync** — API 変更時にドキュメント自動更新
- **Security-Focused Reviews** — OWASP Top 10 に沿ったセキュリティレビュー

### 2-2. コミュニティ事例

- **40時間/週の節約** (Reddit r/ClaudeCode): PR レビューと Issue 対応を自動化
- **外部コントリビュータへの自動初回レビュー**: チーム標準を教えながらウェルカムコメント
- **Issue → PR 自動実装**: `@claude` メンションで Claude がブランチ作成・実装・PR 開始
- **セキュリティリポジトリの常時監視**: 認証周りのファイル変更を常に深くレビュー

---

## 3. 設定ファイルサンプル（.github/workflows/）

### Sample 1: 基本的な PR 自動レビュー

```yaml
# .github/workflows/claude-auto-review.yml
name: Claude Auto Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}
            Please review this pull request with a focus on:
            - Code quality and best practices
            - Potential bugs or issues
            - Security implications
            - Performance considerations
            Note: The PR branch is already checked out.
            Use `gh pr comment` for top-level feedback.
            Use `mcp__github_inline_comment__create_inline_comment` (with `confirmed: true`)
            to highlight specific code issues.
          claude_args: |
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"
```

### Sample 2: 進捗トラッキング付き PR レビュー

```yaml
# .github/workflows/claude-review-with-tracking.yml
name: Claude Auto Review with Tracking
on:
  pull_request:
    types: [opened, synchronize, ready_for_review, reopened]

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          track_progress: true  # ✅ 進捗コメントを有効化
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}
            Please review this pull request with a focus on:
            - Code quality and best practices
            - Potential bugs or issues
            - Security implications
            - Performance considerations
            Provide detailed feedback using inline comments for specific issues.
          claude_args: |
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"
```

### Sample 3: 特定パスの変更のみレビュー（セキュリティ強化）

```yaml
# .github/workflows/claude-security-review.yml
name: Review Critical Files
on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - "src/auth/**"
      - "src/api/**"
      - "config/security.yml"

jobs:
  security-review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}
            This PR modifies critical authentication or API files.
            Please provide a security-focused review with emphasis on:
            - Authentication and authorization flows
            - Input validation and sanitization
            - SQL injection or XSS vulnerabilities
            - API security best practices
          claude_args: |
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*)"
```

### Sample 4: @claude メンションで Issue → PR 自動実装

```yaml
# .github/workflows/claude-issue-to-pr.yml
name: Claude Issue to PR
on:
  issue_comment:
    types: [created]

jobs:
  implement:
    if: contains(github.event.comment.body, '@claude')
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      issues: read
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Read the issue description and the comment that triggered this workflow.
            Implement the requested changes.
            Create a new branch, commit your changes, and open a pull request.
            Reference the issue number in the PR description.
            If the request is unclear or too large, post a comment asking for clarification.
```

### Sample 5: 定期スケジュール実行（週次メンテナンス）

```yaml
# .github/workflows/claude-weekly-maintenance.yml
name: Weekly Maintenance
on:
  schedule:
    - cron: "0 0 * * 0"  # 毎週日曜 0:00 UTC
  workflow_dispatch:       # 手動実行も可能

jobs:
  maintenance:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      issues: write
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            REPO: ${{ github.repository }}
            Perform weekly repository maintenance:
            1. Check for outdated dependencies in package.json
            2. Scan for security vulnerabilities using `npm audit`
            3. Review open issues older than 90 days
            4. Check for TODO comments in recent commits
            5. Verify README.md examples still work
            Create a single issue summarizing any findings.
          claude_args: |
            --allowedTools "Read,Bash(npm:*),Bash(gh issue:*),Bash(git:*)"
```

### Sample 6: OWASP セキュリティレビュー（詳細版）

```yaml
# .github/workflows/claude-owasp-review.yml
name: Security Review
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  security:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      security-events: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}
            Perform a comprehensive security review:
            ## OWASP Top 10 Analysis
            - SQL Injection vulnerabilities
            - Cross-Site Scripting (XSS)
            - Broken Authentication
            - Sensitive Data Exposure
            - Broken Access Control
            - Security Misconfiguration
            - Cross-Site Request Forgery (CSRF)
            - Using Components with Known Vulnerabilities
            ## Additional Security Checks
            - Hardcoded secrets or credentials
            - Insecure cryptographic practices
            - Server-Side Request Forgery (SSRF)
            Rate severity as: CRITICAL, HIGH, MEDIUM, LOW, or NONE.
            Post detailed findings with recommendations.
          claude_args: |
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*)"
```

### Sample 7: コスト削減のためのコンカレンシー制御付きレビュー

```yaml
# .github/workflows/claude-review-with-concurrency.yml
name: Claude PR Review (Cost Optimized)
on:
  pull_request:
    types: [opened, synchronize]
    paths-ignore:
      - "*.md"
      - "docs/**"

concurrency:
  group: claude-review-${{ github.event.pull_request.number }}
  cancel-in-progress: true  # 連続 push 時は最後の1回だけ実行

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            Review this pull request thoroughly. Focus on:
            1. Logic errors and potential bugs
            2. Security vulnerabilities
            3. Performance issues
            4. Error handling gaps

            Format your review as:
            ## Summary
            One paragraph overview of the changes.

            ## Issues Found
            List each issue with file path, severity (critical/warning/suggestion), and explanation.

            ## Positive Notes
            Highlight anything done particularly well.

            Do NOT comment on style, formatting, or naming unless it creates a genuine readability problem.
          claude_args: |
            --model claude-sonnet-4-6
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*)"
```

---

## 4. よく使う入力パラメータ一覧

| パラメータ | 説明 | 例 |
|------------|------|-----|
| `anthropic_api_key` | Anthropic API キー (必須) | `${{ secrets.ANTHROPIC_API_KEY }}` |
| `prompt` | 自動実行モードのプロンプト | `"Review this PR for bugs..."` |
| `claude_args` | Claude Code CLI に渡す追加引数 | `--model claude-sonnet-4-6` |
| `track_progress` | 進捗コメントを有効化 | `true` |
| `allowed_tools` | 許可するツール (旧 v0.x 互換) | `"Bash,Read,Write"` |

### claude_args で使える主要フラグ

```
--model claude-sonnet-4-6          # 使用モデル指定（コスト最適化）
--max-turns 15                      # 最大ターン数
--allowedTools "Read,Write,Edit"    # 許可ツールをホワイトリスト指定
--system-prompt "You are a..."      # システムプロンプト上書き
```

---

## 5. 注意事項・ベストプラクティス

### セキュリティ
- API キーは必ず **Repository Secrets** に保存（環境変数やコードに書かない）
- フォーク PR は `pull_request_target` を使う場合のみ secrets にアクセス可能
  → デフォルトの `pull_request` は外部コントリビュータからの悪用を防ぐ
- PR/Issue のユーザー入力をプロンプトに含める場合は **Prompt Injection** に注意

### コスト管理
- `paths-ignore` で Markdown/ドキュメント変更をスキップ
- `concurrency` + `cancel-in-progress: true` で連続 push の無駄実行を防ぐ
- `types: [opened]` のみにして synchronize をスキップするオプションも有効
- 安価なモデル（`claude-sonnet-4-6`）を `--model` で明示的に指定

### CLAUDE.md との連携

リポジトリルートに `CLAUDE.md` を置くと、CI 実行時にも読み込まれる。  
CI 専用の追加指示を書いておくと挙動を統一できる：

```markdown
## CI/CD Context

When running in GitHub Actions:
- Do not modify configuration files unless explicitly asked
- Always create a new branch for changes, never commit directly to main
- Format PR comments using GitHub-flavoured Markdown
- Never include secrets or sensitive values in output
```

---

## 6. Godot プロジェクトへの応用例

```yaml
# .github/workflows/claude-gdscript-review.yml
name: GDScript Code Review
on:
  pull_request:
    types: [opened, synchronize]
    paths:
      - "**/*.gd"
      - "**/*.tscn"

jobs:
  review:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          prompt: |
            REPO: ${{ github.repository }}
            PR NUMBER: ${{ github.event.pull_request.number }}

            このPRのGDScript/Godotシーンファイルをレビューしてください。
            以下の点に注目してください：
            - GDScript 4.x のベストプラクティス
            - パフォーマンス問題（_process での重い処理など）
            - メモリリーク・シグナル未解除の懸念
            - シーン構造の設計問題
            - バグになりそうなロジック
            - 型ヒントの未使用箇所

            コードごとのコメントはインライン形式で投稿してください。
            全体サマリーは `gh pr comment` で投稿してください。
          claude_args: |
            --allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*)"
```

---

## 参考リンク

- [anthropics/claude-code-action (公式)](https://github.com/anthropics/claude-code-action)
- [Solutions Guide (公式ユースケース集)](https://github.com/anthropics/claude-code-action/blob/main/docs/solutions.md)
- [Custom Automations Guide](https://github.com/anthropics/claude-code-action/blob/main/docs/custom-automations.md)
- [Migration Guide (v0.x → v1)](https://github.com/anthropics/claude-code-action/blob/main/docs/migration-guide.md)
- [5 Copy-Paste Workflow Recipes (systemprompt.io)](https://systemprompt.io/guides/claude-code-github-actions)
- [Scaling Claude Code with GitHub Actions (Medium)](https://medium.com/@waprin/scaling-claude-code-with-github-actions-and-pull-requests-1dd8ce46e465)
