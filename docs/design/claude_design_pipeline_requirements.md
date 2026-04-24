# Claude Design → DesignerAgent 自動パイプライン 要件定義書

## 1. 概要

Claude Design（Anthropic Labs、2026年4月発表）が出力する「handoff bundle」ファイルを、Claude Code hooksで検知し、DesignerAgent（`.claude/agents/designer.md`）へ自動的に引き渡して企画書（`docs/design/*.md`）を生成するパイプラインを構築する。

API統合は「数週間後」と予告段階のため、**現時点ではファイルベースの受け渡し**を前提とし、API webhook方式への差し替え容易性（抽象化レイヤー）を要件に含める。

---

## 2. 実装対象

### 新規作成ファイル
| パス | 種別 | 目的 |
|------|------|------|
| `docs/design/handoff/` | ディレクトリ | 未処理bundleランディングゾーン |
| `docs/design/handoff/processed/` | ディレクトリ | 処理済みbundleアーカイブ |
| `docs/design/handoff/README.md` | ドキュメント | bundle仕様・利用方法の説明 |
| `.claude/hooks/claude_design_watcher.sh` | シェルスクリプト | bundle検知→DesignerAgent起動（bash） |
| `.claude/hooks/claude_design_watcher.ps1` | PowerShellスクリプト | 同上（Windowsネイティブ用、任意） |
| `.claude/hooks/lib/handoff_adapter.sh` | シェルスクリプト | bundle形式の抽象化レイヤー（API切替ポイント） |

### 変更対象ファイル
| パス | 変更内容 |
|------|---------|
| `.claude/settings.local.json` | `hooks` セクションに `UserPromptSubmit` エントリ追加 |

### 干渉しないこと
- `scripts/*.gd`（Godot実装）は一切変更しない
- `.mcp.json`（既存Godot MCP）は変更しない

---

## 3. データ構造

### 3.1 handoff bundle想定仕様（ファイル形式）

公式スキーマ未公開のため、以下を暫定仕様とする。API公開後に `handoff_adapter.sh` で吸収。

**想定ファイル拡張子**：`.bundle.json` または `.bundle.md`

#### JSON形式（想定）
```json
{
  "schema_version": "0.1-provisional",
  "source": "claude-design",
  "generated_at": "2026-04-24T10:00:00Z",
  "prompt": "元のユーザープロンプト",
  "artifacts": {
    "screen_name": "画面名",
    "description": "UI/UXの説明",
    "components": [
      { "type": "Button", "label": "...", "x": 0, "y": 0, "w": 100, "h": 40 }
    ],
    "colors": { "bg": "#0a0a0a", "accent": "#d4af37" },
    "interactions": [ { "event": "click", "target": "...", "effect": "..." } ],
    "assets": [ { "name": "preview.png", "data_url": "data:image/png;base64,..." } ]
  }
}
```

#### Markdown形式（想定）
フロントマター付きMarkdown。`description` セクションに自然言語仕様、`components` セクションに要素一覧。

### 3.2 ファイル命名規則

- 入力：`docs/design/handoff/<任意名>.bundle.{json,md}`
- 出力：`docs/design/<YYYYMMDD_HHMMSS>_from_claude_design.md`
- アーカイブ：`docs/design/handoff/processed/<YYYYMMDD_HHMMSS>_<元ファイル名>`

---

## 4. 実装詳細

### 4.1 ランディングゾーン設計

**配置**：
- `docs/design/handoff/` （gitコミット対象。`.gitkeep` を置く）
- `docs/design/handoff/processed/` （同上）

**README.md 内容（要点）**：
- このフォルダは Claude Design の handoff bundle を受け取る場所
- 新ファイルを置くと DesignerAgent が自動起動する
- 受理拡張子：`.bundle.json`, `.bundle.md`
- 処理後は `processed/` に移動される

### 4.2 Claude Code hook設計

**採用イベント**：`UserPromptSubmit`
- 理由：ユーザーが次のプロンプトを送るタイミングで前回のbundleを回収できる。常駐プロセス不要
- 補助案：`Stop` イベントにも同じスクリプトを紐付け、セッション終了時にも未処理bundleを拾う

**フック動作**：
1. `docs/design/handoff/*.bundle.{json,md}` をglob
2. 見つかったbundleごとに `handoff_adapter.sh` を呼ぶ
3. adapterがbundle内容を標準出力（テキスト）化
4. そのテキストをDesignerAgent呼び出しプロンプトへ注入
5. DesignerAgent起動（非同期・バックグラウンド）
6. 処理済みbundleを `processed/` に移動

**エラー時挙動**：
- bundle解析失敗 → `docs/design/handoff/.errors.log` に追記してスキップ（ユーザーのメインフローを止めない）
- DesignerAgent呼び出し失敗 → bundleは `processed/` に移動せず残置（次回リトライ）

### 4.3 handoff_adapter.sh（抽象化レイヤー）

**責務**：bundle形式の違いを吸収し、DesignerAgent向けの統一テキストを出力する。

**インターフェース**：
```bash
# 入力：bundleファイルパス
# 出力：標準出力に「DesignerAgentへのプロンプト本文」を吐く
# 終了コード：0=成功, 1=解析失敗
bash .claude/hooks/lib/handoff_adapter.sh <bundle_path>
```

**内部分岐**：
- 拡張子 `.bundle.json` → `jq` でフィールド抽出 → テンプレート整形
- 拡張子 `.bundle.md` → 本文をそのまま転記（フロントマターのみ除去）
- 将来の API webhook対応 → 引数が `http://` や `https://` で始まる場合はcurl取得に切り替える分岐を想定（コメントで明記）

**出力テンプレート（例）**：
```
【Claude Design からの handoff】
生成日時: <timestamp>
元プロンプト: <prompt>

以下のUI/UX案をDesignerAgentの企画書フォーマットに変換してください。

<bundle本文>

出力先: docs/design/<YYYYMMDD_HHMMSS>_from_claude_design.md
UI基準6項目を必ず評価すること。
```

### 4.4 DesignerAgent呼び出し方式

**呼び出しコマンド（想定）**：
```bash
claude --agent designer --prompt "<adapter出力テキスト>" --non-interactive
```

Claude Code CLIの正式なAgent起動フラグが未確定の場合は、代替として hookスクリプトが `.claude/agents/designer.md` の内容を読み込み、adapter出力と結合したプロンプトファイルを `docs/design/handoff/.pending/` に作成。ユーザーが次のセッションでそれをトリガーする方式でも良い（フォールバック）。

**出力先**：`docs/design/<YYYYMMDD_HHMMSS>_from_claude_design.md`
- タイムスタンプは bundle の `generated_at` または処理時刻を使用
- 既存の `docs/design/*.md` と同じ階層に並ぶ（DesignerAgent既定の出力先）

### 4.5 処理済みマーク（二重処理防止）

**方式**：処理成功時に `processed/` へ移動する（`.done` 拡張子付与方式は採らない）

理由：
- 既存 `docs/design/handoff/README.md` のglob対象から外れるため、再検知されない
- git管理下でも履歴として追跡しやすい

**移動後ファイル名**：`processed/<YYYYMMDD_HHMMSS>_<元ファイル名>`

### 4.6 settings.local.json 追加案

```json
{
  "permissions": { "...既存... ": "..." },
  "hooks": {
    "UserPromptSubmit": [
      {
        "command": "bash .claude/hooks/claude_design_watcher.sh",
        "timeout_ms": 5000,
        "blocking": false
      }
    ],
    "Stop": [
      {
        "command": "bash .claude/hooks/claude_design_watcher.sh",
        "timeout_ms": 5000,
        "blocking": false
      }
    ]
  }
}
```

**Windows対応**：bashはGit Bash経由で動作。PowerShellを優先したい場合は `.ps1` 版を用意し、`powershell -File .claude/hooks/claude_design_watcher.ps1` に差し替え可能。

---

## 5. API統合後の移行パス

Claude Design API（webhook）が公開された際、以下の2点のみを差し替える：

### 5.1 差し替えポイント1：受信方式
- **現行**：`docs/design/handoff/` のファイルglob
- **移行後**：webhook受信サーバ（ローカルポート、例：`http://localhost:7777/claude-design`）
- **移行作業**：`claude_design_watcher.sh` の検知部分を、常駐HTTPサーバ（例：Python `http.server` + ハンドラ）に置換

### 5.2 差し替えポイント2：bundle取得
- **現行**：ローカルファイル読み込み
- **移行後**：webhookペイロード or API GET
- **移行作業**：`handoff_adapter.sh` 冒頭の分岐にHTTP取得パスを追加（設計上の空き枠として現時点でコメント残置）

### 5.3 移行時に変更不要なもの
- DesignerAgent本体（`.claude/agents/designer.md`）
- 出力先規則（`docs/design/<timestamp>_from_claude_design.md`）
- 企画書フォーマット

これにより、API統合時の作業は2ファイルの修正に局所化される。

---

## 6. 制約・注意事項

### 6.1 設計上の整合性
- 本パイプラインは **UI/UX企画の入口を増やす** ものであり、既存の「CEO → PMO → Designer」フローを置き換えない
- 生成された `<timestamp>_from_claude_design.md` は **CEOの承認を経てから** 実装フェーズに渡す（DesignerAgent完了定義どおり）
- Claude Design出力を盲目的に採用せず、UI基準6項目での評価を必ず通す

### 6.2 技術的制約
- Windows環境では Git Bash が必要（Claude Code標準同梱想定）
- `jq` 未導入の場合は JSON形式bundle処理に失敗する → README.md に導入手順を明記
- hooksスクリプトは非ブロッキング実行（`blocking: false`）で、ユーザーの対話フローを止めない
- bundle処理中にユーザーがメインセッションで作業可能

### 6.3 ゲーム設計との独立性
- 本パイプラインは `scripts/*.gd` `data/*.json` 等のゲーム実装ファイルには一切触れない
- 出力物は `docs/design/` 配下のMarkdownのみ
- 「盤面を設計して、介入を仕込んで、答え合わせを観戦する」という核には影響しない

### 6.4 セキュリティ
- bundle に `data_url` 形式で画像が含まれる場合、`docs/design/handoff/assets/` に展開する
- 外部URLへのfetchは adapter 段階では行わない（将来API対応時に限定的に解禁）

---

## 7. 実装ファイル一覧（サマリ）

| ファイル | 新規/変更 | 概要 |
|---------|----------|------|
| `docs/design/handoff/.gitkeep` | 新規 | 空フォルダのgit保持 |
| `docs/design/handoff/processed/.gitkeep` | 新規 | 同上 |
| `docs/design/handoff/README.md` | 新規 | 利用者向け説明 |
| `.claude/hooks/claude_design_watcher.sh` | 新規 | メイン検知スクリプト（bash） |
| `.claude/hooks/claude_design_watcher.ps1` | 新規（任意） | PowerShell版 |
| `.claude/hooks/lib/handoff_adapter.sh` | 新規 | bundle形式抽象化レイヤー |
| `.claude/settings.local.json` | 変更 | `hooks` セクション追加 |

合計：新規6ファイル（+任意1）／変更1ファイル。Godot実装側への影響なし。

---

## 8. 完了条件

- [ ] `docs/design/handoff/` に bundle を置くと、次のユーザープロンプト送信時に DesignerAgent が自動起動する
- [ ] 生成企画書が `docs/design/<timestamp>_from_claude_design.md` に出力される
- [ ] 処理済みbundleが `processed/` に移動される
- [ ] bundle解析失敗時もユーザーの対話フローが停止しない
- [ ] API webhook化の際、2ファイル修正のみで移行可能な抽象化が維持されている

---

## 9. 参照

- `.claude/agents/designer.md`（DesignerAgent定義）
- `docs/meta/ui_workflow.md`（UI/UX実装ワークフロー）
- `CLAUDE.md`（CEO実装禁止・YESマン禁止・修正ワークフロー）
