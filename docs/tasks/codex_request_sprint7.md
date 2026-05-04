# Codex 実装依頼：Sprint 7 — 初期デッキ・建築基盤

**依頼日：2026-05-04**  
**対応要件定義書：** `docs/requirements/REQUIREMENTS_SPRINT_7.md`  
**優先度：** 高（Phase 1 MVP）

---

## ⚠️ 参照禁止ファイル（絶対に参照しないこと）

**以下のファイルは廃止済みです。これらを参照した場合、実装が拒否されます。**

| 禁止ファイル | 理由 | 代替ファイル |
|----------|------|----------|
| `docs/requirements/archive/req_econ_initial_deck_sprint7.md` | 旧版（11枚デッキ） | `docs/requirements/REQUIREMENTS_SPRINT_7.md` |
| `docs/requirements/archive/req_econ_card_placement_flow.md` | 旧版・個別要件 | `docs/requirements/REQUIREMENTS_SPRINT_7.md` |
| `docs/requirements/archive/req_econ_parameter_architecture.md` | 旧版・個別要件 | `docs/requirements/REQUIREMENTS_SPRINT_7.md` |
| その他 `docs/requirements/archive/req_*` | 全て廃止済み | `docs/requirements/REQUIREMENTS_SPRINT_7.md` |

**参照すべき最新ファイル（SSoT）：**
- ✅ `docs/requirements/REQUIREMENTS_SPRINT_7.md`（メインの要件定義書）
- ✅ `docs/design/sprint7_designer_plan.md`（UI/UX企画書）
- ✅ `docs/sprint7_initial_deck_building_base_final.md`（企画書原本）

---

## 実装指示プロンプト

```
以下の要件定義書に基づいて Sprint 7 を実装してください。

依頼元：docs/requirements/REQUIREMENTS_SPRINT_7.md （SSoT）

## 概要

Sprint 7 では初期デッキ13枚と建物カード使用フローを実装し、
「建物カードを使用 → 建設予定地指定 → 建設コスト支払い → 
建設時間に応じて進捗 → 建設完了 → 稼働開始」
までのループを内部実装で成立させる。

核となる体験：盤面設計・介入・観戦

## 実装スコープ（F1-F12・完了条件30項目）

### F1-F4: 初期デッキ・建物カード仕様・建設フロー

1. 初期デッキ13枚定義（data/cards_econ.json の INITIAL_DECK）
   - 住宅×3 / 農村×2 / 森小屋×2 / 採掘所×2 / 食堂×1 / 兵舎×1 / 広場×1 / 交換所×1
   
2. 建物カード仕様フィールド追加（cards_econ.json）
   - build_time / required_work_labor / required_operation_labor
   - 交換所に category: "special" を確認
   
3. 建設予定地システム（EconGrid.gd）
   - construction_sites: Dictionary[Vector2i → ConstructionSite]
   - 各エントリの構造は要件書 § 4.3 参照
   
4. 建築フロー実装（EconMain.gd / EconGrid.gd）
   - 配置可能マス判定：自建物隣接・開示済み・未建設・非建設予定地
   - コスト支払い判定・失敗時「!」アイコン + 赤フラッシュ
   - construction_sites への登録・占有判定

### F5-F6: 建設進捗・完了処理

5. 建設進捗更新（毎フレーム）
   - 作業人手割当判定（§5.2）
   - progress += delta / construction_time
   - 人手不足時停止（リング灰色化）
   
6. 建設完了処理
   - progress >= 1.0 で construction_sites 削除
   - EconBuilding 新規生成（is_built=true）
   - カード回収：通常→discard_pile、特殊→excluded
   - LogManager: BUILDING_COMPLETED イベント

### F7-F9: 人手システム・スライダー UI

7. 人手計算関数（EconEconomy.gd）
   - get_total_labor(): floor(人口 × 20%)
   - get_operation_labor(): floor(total_labor × (1 - alloc_work_ratio))
   - get_work_labor(): total_labor - operation_labor
   
8. 人手スライダー UI（EconMain.gd）
   - LABOR ブロック新設：x=700-860 / 160×180
   - つまみ・±ボタン・OPS/WORK 表示
   - 10% 刻み調整
   - 人手不足時点滅表現
   
9. 人手割当優先順位（§5.2・§5.3）
   - 作業：建設開始が古い順（started_at 昇順）
   - 稼働：食料系→資源系→兵力系→満足度系→その他
   - 部分稼働なし（全て or 止まる）

### F10-F12: UI・視覚表現・交換所

10. 盤面パネル状態表現
    - 建設中：半透明マスク + 金色リング
    - リング灰色化（人手不足時）
    - 稼働ドット：緑（稼働中）/ 灰（停止中）
    - 配置可能マス：COLOR_WOOD 緑枠 + パルス

11. BUILD ブロック圧縮
    - 4種→5枚（手札スロット）
    - 92×140 → 48×140
    - 表示：アイコン + コスト（名称はホバー）

12. 交換所の稼働判定
    - is_operating フラグで進捗カウント制御
    - 累計10資源で +1 ドロー（既存実装踏襲）

## 完了条件チェックリスト（30項目）

要件書 § 7 の全30項目をチェック：

**初期デッキ・カード仕様**
- [ ] ゲーム開始時に初期デッキ13枚で構成
- [ ] 同一カード重複許可
- [ ] 8種に cost / build_time / required_work_labor / required_operation_labor
- [ ] 交換所に category: "special"

**建物カード使用**
- [ ] 手札クリック → 配置モード入る
- [ ] 配置可能マス → COLOR_WOOD 緑枠ハイライト
- [ ] クリック → 建設コスト支払い
- [ ] 資源不足 → 「!」+ 赤フラッシュ（資源減らない）
- [ ] 建設開始 → construction_sites 登録・is_under_construction=true
- [ ] 建設予定地 → 他カード配置不可（占有）

**建設進捗・完了**
- [ ] 作業人手足りる → リング進む（線形）
- [ ] 人手不足 → 進捗停止・リング灰色化
- [ ] 進捗100% → construction_sites 削除・EconBuilding 生成
- [ ] 通常建物→discard、特殊→excluded

**人手システム**
- [ ] 人手総量 = floor(人口 × 20%)
- [ ] スライダー初期値：OPS 70% / WORK 30%
- [ ] スライダー操作 → 10% 刻みで変更
- [ ] 稼働人手不足 → 完成済み建物タイマー停止
- [ ] 作業人手不足 → 建設進捗停止
- [ ] 人手不足解消 → 自動再開
- [ ] 稼働優先順位：食料→資源→兵力→満足度→その他
- [ ] 作業優先順位：started_at 昇順

**UI・視覚表現**
- [ ] フッターに LABOR ブロック（160×180）新設
- [ ] BUILD ブロック 260px に圧縮・5枚表示
- [ ] 建設中パネル → 半透明 + 金色リング
- [ ] 稼働中 → 緑ドット、停止中 → 灰ドット
- [ ] 人手不足 → OPS/WORK 数値 COLOR_RED 点滅
- [ ] 新規色定義0個（既存のみ）

**品質**
- [ ] check_syntax.sh エラー0件
- [ ] LogManager BUILDING_PLACED / BUILDING_COMPLETED イベント

## 実装対象ファイル・変更範囲

| ファイル | 変更内容 | 想定行数 |
|---------|---------|--------|
| data/cards_econ.json | カード8種に build_time/required_*_labor 追加、交換所に category確認 | +30 |
| scripts/econ_mvp/EconDeckManager.gd | INITIAL_DECK_SPEC + exclude_card/discard_card | +30 |
| scripts/econ_mvp/EconEconomy.gd | get_total_labor / get_operation_labor / get_work_labor | +20 |
| scripts/econ_mvp/EconGrid.gd | construction_sites + start/update/spawn_building + get_buildable_cells | +120 |
| scripts/econ_mvp/EconBattle.gd | _allocate_operation_labor + is_operating ガード | +60 |
| scripts/econ_mvp/EconBuilding.gd | is_operating + _process ガード + 建設リング・稼働ドット描画 | +50 |
| scripts/econ_mvp/EconMain.gd | LABOR UI + BUILD 圧縮 + 建設予定地モード | +180 |
| scripts/econ_mvp/EconUI.gd | 配置可能マスハイライト + 人手不足点滅 | +40 |

**重要：EconMain.gd が 800行超になる場合は LaborSliderUI.gd への分割を要件に追加済み**

## 禁止事項・ルール

- **禁止：** 指示されていない機能追加（建設キャンセル・予定地変更・予約キューは Sprint 7 非対象）
- **疎結合：** EconGrid→EconDeckManager/EconEconomy は直接代入禁止・メソッド経由のみ
- **用語統一：** 設計用語と実装用語を一致させる（construction_time = build_time）
- **色定義：** 新規色定義なし（既存 COLOR_* のみ使用）

## 検証方法

1. bash check_syntax.sh → エラー0件
2. python -m json.tool data/cards_econ.json → JSON 解析成功
3. 要件書 § 7 チェックリスト30項目を手動確認（画面目視）

## 実装後の報告

変更ファイル一覧・行番号・check_syntax.sh 結果・未検証項目を 
docs/tasks/codex_result_sprint7.md に記録してください。
```

---

## Codex CLI 投げコマンド（参考）

```bash
python .claude/hooks/dispatch_codex.py docs/tasks/codex_request_sprint7_manual.md
```

---

## 注意事項

- **REQUIREMENTS_SPRINT_7.md が SSoT**（他の req_* ファイルを参照しないこと）
- **旧 codex_request_sprint7.md は参考のみ**（古い実装依頼の指示を使わないこと）
- **30項目チェックリストをすべて満たすこと**（部分実装は不可）
- **ランドカード配置は Sprint 7 非対象**（前 Sprint で実装済み）
