# 廃止済み設計grepパターン集

作成日: 2026-04-23
用途: Implementer / Checker / Planning が廃止設計の復活を自動検知するための参照
元データ: CLAUDE.md「廃止済み設計」節（6項目）

---

## 使用方法

### Planning
提案内容に以下のパターンが含まれていたら**廃止済み**として却下。
理由と代替方針を明記して差し戻す。

### Implementer
実装前の「変更範囲宣言」時に以下のパターンが含まれていたら実装中止。
CEOに確認を取る。

### Checker
差分（git diff / 変更ファイル）に以下のパターンが含まれていたら **❌ 差し戻し**。
rule-id として `DEP-01` 〜 `DEP-06` を使用する。

---

## DEP-01: 盤面召喚システム

### 廃止理由
初期配置式に統一・設計の意図を明確にするため

### grepパターン（英語・関数名候補）
- `summon_unit`
- `summon_on_board`
- `place_during_battle`
- `place_in_battle`
- `spawn_unit_manual`
- `summon_phase`
- `summon_cost`

### grepパターン（日本語・ドキュメント）
- `盤面召喚`
- `召喚フェーズ`
- `手札から盤面`
- `マナを払って召喚`
- `バトル中に配置`
- `バトル中配置`

### 許可される類似語
- `on_summon`（トリガー名、初期配置時に発動する既存トリガーなのでOK）
- `召喚時`（on_summonの日本語名）

---

## DEP-02: 時間経過マナ回復

### 廃止理由
ユニット生成マナに統一・戦線維持と連動させるため

### grepパターン（英語・関数名候補）
- `regen_mana_over_time`
- `mana_regen_per_second`
- `mana_tick`
- `periodic_mana`
- `auto_mana_recovery`
- `time_based_mana`
- `mana_delta_time`
- `regenerate_mana`
- `mana_recovery_interval`

### grepパターン（日本語・ドキュメント）
- `時間経過マナ`
- `マナの自動回復`
- `マナ自動回復`
- `秒ごとにマナ`
- `時間でマナ`
- `定期マナ回復`

### 許可される類似語
- `mana_gen`（ユニット生成マナ、廃止されたものではない）
- `ユニット生成マナ`（現行仕様）

---

## DEP-03: アクティブスキル・固有スキル

### 廃止理由
3秒ルール違反のため（プレイヤーが能動的に使うスキルはバトル画面理解を妨げる）

### grepパターン（英語・関数名候補）
- `active_skill`
- `activate_skill`
- `unique_skill`
- `special_skill`
- `skill_button`
- `use_skill`
- `trigger_active`
- `manual_skill`
- `player_skill_activation`

### grepパターン（日本語・ドキュメント）
- `アクティブスキル`
- `固有スキル`
- `必殺技`
- `スキル発動ボタン`
- `手動スキル`
- `プレイヤー操作スキル`
- `スキル使用`

### 許可される類似語
- `前列能力` / `サポート効果` / `特性`（現行のスキル種別、自動発動なのでOK）
- `skill`（呪文カードの内部実装で使われる可能性あり、文脈で判断）

---

## DEP-04: 行範囲攻撃

### 廃止理由
行はシナジーの集め方に専念させるため（攻撃範囲としては使わない）

### grepパターン（英語・関数名候補）
- `row_attack`
- `row_range_attack`
- `horizontal_attack`
- `attack_entire_row`
- `row_aoe`
- `attack_row`
- `hit_row`

### grepパターン（日本語・ドキュメント）
- `行範囲攻撃`
- `同行に攻撃`
- `行全体攻撃`
- `横一列に攻撃`（「列」表記でも廃止）
- `行にダメージ`

### 許可される類似語
- `range: "1行"` / `"2行"` / `"3行"`（cards.jsonの現行フィールド、列方向の範囲指定なのでOK）
- `同行` / `自上行` / `敵上行`（対象指定の枕詞、シナジー集めの用途）

---

## DEP-05: 本体HPシステム

### 廃止理由
視線の置き場を一本化するため（HPバーはユニットに集中）

### grepパターン（英語・関数名候補）
- `player_hp`
- `base_hp`
- `main_hp`
- `core_hp`
- `nexus_hp`
- `player_health`
- `base_health`
- `damage_to_player`
- `player_takes_damage`
- `core_destroyed`

### grepパターン（日本語・ドキュメント）
- `本体HP`
- `本体ヘルス`
- `プレイヤーHP`
- `本体ダメージ`
- `本体が破壊`
- `拠点HP`
- `コアHP`

### 許可される類似語
- ユニットの `hp`（各ユニットのHPは現行仕様）
- `撃破`（ユニットHP=0の意味、本体ではない）

---

## DEP-06: リアルタイム対人（PvP）

### 廃止理由
PvEが本質のため

### grepパターン（英語・関数名候補）
- `pvp`
- `player_vs_player`
- `matchmaking`
- `opponent_player`
- `remote_player`
- `online_battle`
- `realtime_battle`
- `versus_mode`
- `multiplayer_battle`
- `peer_to_peer`

### grepパターン（日本語・ドキュメント）
- `PvP`
- `対人戦`
- `対人対戦`
- `リアルタイム対戦`
- `オンライン対戦`
- `マッチング`
- `マッチメイキング`
- `他プレイヤーと対戦`
- `マルチプレイヤー対戦`

### 許可される類似語
- `PvE` / `敵AI` / `CPU戦`（現行仕様）
- `EnemyAI.gd`（既存ファイル名）

---

## 運用ルール

### Checker差し戻しテンプレート（rule-id付き）

```
❌ 乖離検出: DEP-XX 廃止済み設計の復活

対象: <ファイル名>:<行番号>
検出パターン: <マッチした文字列>
廃止項目: <DEP-01〜06 のいずれか>
廃止理由: <上記の理由を転記>

→ Implementer 差し戻し：該当コードの削除 or 代替方針への変更
```

### 例外申請

廃止済み設計の復活が本当に必要な場合は：
1. CLAUDE.md「廃止済み設計」節の更新提案をPlanning/CEOに上げる
2. 承認後にCLAUDE.md本体の廃止リストを修正
3. 本ファイル（deprecated_design_patterns.md）の該当パターンを削除

**原則**: 個別実装で廃止リストを回避しない。必ず中央文書から更新する。

---

## 更新履歴

- 2026-04-23: 初版作成（CLAUDE.md 廃止リスト6項目に対応）
