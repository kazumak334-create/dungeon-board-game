#!/usr/bin/env python3
"""
5分フェーズ配分検証シミュレーター
「0-1分:土台 / 1-3分:接敵 / 3分〜:決着」が成立するか確認する。

EconBuilding.gd / EconEconomy.gd / EconUnit.gd の定数を Python で再現。
完全なゲームシミュレーション（経済→建設→ユニット生産→進軍→戦闘）。
"""

import sys
from dataclasses import dataclass, field

sys.stdout.reconfigure(encoding='utf-8')

# ===== EconBuilding.gd の定数 =====
HARVEST_INTERVAL = 5.0          # 1資源/5秒
BARRACKS_PRODUCE_INTERVAL = 8.0
BARRACKS_PRODUCE_COST_WOOD = 3
FORTRESS_PRODUCE_INTERVAL = 10.0
FORTRESS_PRODUCE_COST_STONE = 3
WORKSHOP_PRODUCE_INTERVAL = 12.0
VILLAGE_WHEAT_INTERVAL = 5.0
VILLAGE_WHEAT_AMOUNT = 2
VILLAGE_HARVESTER_INTERVAL = 20.0

REQUIRED_CONSTRUCTION = {'BARRACKS': 5.0, 'FORTRESS': 8.0, 'WORKSHOP': 8.0, 'VILLAGE': 5.0}
BUILD_COSTS = {
    'BARRACKS': {'wood': 8},
    'FORTRESS': {'stone': 6},
    'WORKSHOP': {'sulfur': 6},
    'VILLAGE':  {'wood': 4, 'stone': 3, 'wheat': 2},
}

# ===== EconUnit.gd の定数 =====
UNIT_STATS = {
    'A': {'hp': 80.0,  'atk': 20.0, 'spd': 1.0,  'range': 1, 'move_spd': 0.15},
    'T': {'hp': 200.0, 'atk': 25.0, 'spd': 0.5,  'range': 1, 'move_spd': 0.10},
    'B': {'hp': 70.0,  'atk': 35.0, 'spd': 0.25, 'range': 3, 'move_spd': 0.12},
}

# ===== マップ定数 =====
MAP_ROWS = 12
PLAYER_BASE_ROW = 0
ENEMY_BASE_ROW = 11
COMBAT_START_ROW = 3   # プレイヤーユニットの進軍開始行
COMBAT_FRONT_ROW = 6   # 中央（接敵ライン）

DT = 0.1
MAX_TIME = 600.0  # 10分

# 初期ハーベスター数（player & AI 共通）
INITIAL_HARVESTERS = 2

# 接敵の定義: ユニットが中央 row6 に到達した瞬間
# 決着の定義: どちらかの BASE HP が 0 になった瞬間（または 80% ユニットが全滅した瞬間）
BASE_HP = 500.0


@dataclass
class Economy:
    wood: int = 0
    stone: int = 0
    sulfur: int = 0
    wheat: int = 10

    def can_afford(self, costs: dict) -> bool:
        return (self.wood >= costs.get('wood', 0) and
                self.stone >= costs.get('stone', 0) and
                self.sulfur >= costs.get('sulfur', 0) and
                self.wheat >= costs.get('wheat', 0))

    def spend(self, costs: dict):
        self.wood  -= costs.get('wood', 0)
        self.stone -= costs.get('stone', 0)
        self.sulfur -= costs.get('sulfur', 0)
        self.wheat -= costs.get('wheat', 0)

    def add(self, rtype: str, amount: int = 1):
        setattr(self, rtype, getattr(self, rtype) + amount)


@dataclass
class Building:
    btype: str
    is_built: bool = False
    build_progress: float = 0.0
    produce_timer: float = 0.0
    harvester_timer: float = 0.0
    wheat_timer: float = 0.0


@dataclass
class SimUnit:
    utype: str
    row: float       # 現在行（実数で進軍を表現）
    team: int        # 0=player, 1=enemy
    hp: float = field(init=False)
    atk: float = field(init=False)
    spd: float = field(init=False)
    rng: int = field(init=False)
    move_spd: float = field(init=False)
    attack_timer: float = 0.0
    move_timer: float = 0.0

    def __post_init__(self):
        s = UNIT_STATS[self.utype]
        self.hp = s['hp']
        self.atk = s['atk']
        self.spd = s['spd']
        self.rng = s['range']
        self.move_spd = s['move_spd']

    @property
    def alive(self):
        return self.hp > 0


def simulate_game(
    player_build_order: list[str],
    player_alloc: dict,           # {'wood': N, 'stone': N, ...}
    enemy_build_order: list[str],
    enemy_alloc: dict,
    verbose: bool = False,
) -> dict:
    """
    1ゲームをシミュレートする。
    Returns: {
        't_first_unit': float,      # プレイヤー最初のユニット生産時刻
        't_engagement': float,      # 最初の接敵時刻（中央row6付近で敵味方が出会う）
        't_decisive': float,        # 決着フェーズ開始（BASEが攻撃を受け始める時刻）
        't_end': float,             # ゲーム終了時刻
        'winner': str,              # 'player' / 'enemy' / 'timeout'
        'events': list,             # イベントログ
    }
    """

    # 経済
    p_eco = Economy()
    e_eco = Economy(wheat=10)

    # ハーベスター（採掘）
    p_harvesters = INITIAL_HARVESTERS
    e_harvesters = INITIAL_HARVESTERS
    p_harvest_timers = [0.0] * p_harvesters
    e_harvest_timers = [0.0] * e_harvesters

    # 建設キュー
    p_build_queue = [Building(b) for b in player_build_order]
    e_build_queue = [Building(b) for b in enemy_build_order]

    # 完成建物
    p_buildings: list[Building] = []
    e_buildings: list[Building] = []

    # ユニット（行で進軍を管理）
    p_units: list[SimUnit] = []
    e_units: list[SimUnit] = []

    # BASE HP
    p_base_hp = BASE_HP
    e_base_hp = BASE_HP

    # ハーベスター追加タイマー用
    p_harvester_timer = 0.0
    e_harvester_timer = 0.0

    # 結果
    t_first_unit = None
    t_engagement = None
    t_decisive = None
    t_end = None
    winner = 'timeout'
    events = []

    def log(t, msg):
        events.append(f"t={t:.1f}s: {msg}")
        if verbose:
            print(f"  t={t:.1f}s: {msg}")

    def harvest_resources(eco, harv_count, timers, alloc):
        """ハーベスターが資源を採掘する"""
        keys = [k for k, v in alloc.items() if v > 0]
        if not keys:
            keys = ['wood']
        for i in range(len(timers)):
            timers[i] += DT
            if timers[i] >= HARVEST_INTERVAL:
                timers[i] = 0.0
                rtype = keys[i % len(keys)]
                eco.add(rtype, 1)

    def process_build_queue(eco, queue, built, t):
        """建設キューを処理（最初の未建設建物に資材が揃ったら建設）"""
        if not queue:
            return
        b = queue[0]
        if b.is_built:
            built.append(queue.pop(0))
            return
        cost = BUILD_COSTS[b.btype]
        if eco.can_afford(cost):
            b.build_progress += 1.0 * DT  # CONSTRUCTION_RATE=1.0
            if b.build_progress >= REQUIRED_CONSTRUCTION[b.btype]:
                eco.spend(cost)
                b.is_built = True
                log(t, f"建設完了: {b.btype}")
                built.append(queue.pop(0))

    def update_buildings(eco, buildings, units, team, t):
        """建設済み建物の生産"""
        new_harvesters = 0
        for b in buildings:
            if not b.is_built:
                continue
            if b.btype == 'BARRACKS':
                b.produce_timer += DT
                if b.produce_timer >= BARRACKS_PRODUCE_INTERVAL:
                    if eco.can_afford({'wood': BARRACKS_PRODUCE_COST_WOOD}):
                        eco.spend({'wood': BARRACKS_PRODUCE_COST_WOOD})
                        b.produce_timer = 0.0
                        start_row = 0.0 if team == 0 else float(MAP_ROWS - 1)
                        units.append(SimUnit('A', start_row, team))
                        log(t, f"{'Player' if team == 0 else 'Enemy'} 突ユニット生産")
            elif b.btype == 'FORTRESS':
                b.produce_timer += DT
                if b.produce_timer >= FORTRESS_PRODUCE_INTERVAL:
                    if eco.can_afford({'stone': FORTRESS_PRODUCE_COST_STONE}):
                        eco.spend({'stone': FORTRESS_PRODUCE_COST_STONE})
                        b.produce_timer = 0.0
                        start_row = 0.0 if team == 0 else float(MAP_ROWS - 1)
                        units.append(SimUnit('T', start_row, team))
                        log(t, f"{'Player' if team == 0 else 'Enemy'} 守ユニット生産")
            elif b.btype == 'VILLAGE':
                b.wheat_timer += DT
                if b.wheat_timer >= VILLAGE_WHEAT_INTERVAL:
                    b.wheat_timer = 0.0
                    eco.add('wheat', VILLAGE_WHEAT_AMOUNT)
                b.harvester_timer += DT
                if b.harvester_timer >= VILLAGE_HARVESTER_INTERVAL:
                    b.harvester_timer = 0.0
                    new_harvesters += 1
                    log(t, f"{'Player' if team == 0 else 'Enemy'} ハーベスター+1")
        return new_harvesters

    def move_units(p_units, e_units, t):
        """ユニット進軍と戦闘"""
        nonlocal p_base_hp, e_base_hp, t_engagement, t_decisive

        # Player units: 正方向（row 0→11）
        for u in p_units:
            if not u.alive:
                continue
            alive_enemies = [e for e in e_units if e.alive]
            # 接近できる敵または拠点を目指す
            if alive_enemies:
                nearest = min(alive_enemies, key=lambda e: abs(e.row - u.row))
                d = abs(nearest.row - u.row)
                if d <= u.rng:
                    u.attack_timer += DT
                    if u.attack_timer >= 1.0 / u.spd:
                        u.attack_timer = 0.0
                        nearest.hp -= u.atk
                else:
                    u.move_timer += DT
                    if u.move_timer >= 1.0 / u.move_spd:
                        u.move_timer = 0.0
                        u.row = min(u.row + 1.0, float(MAP_ROWS - 1))
            else:
                # 敵ユニットなし → 敵BASEを攻撃
                u.move_timer += DT
                if u.move_timer >= 1.0 / u.move_spd:
                    u.move_timer = 0.0
                    u.row = min(u.row + 1.0, float(MAP_ROWS - 1))
                if u.row >= MAP_ROWS - 1:
                    # BASE攻撃
                    u.attack_timer += DT
                    if u.attack_timer >= 1.0 / u.spd:
                        u.attack_timer = 0.0
                        e_base_hp -= u.atk
                        if t_decisive is None:
                            t_decisive = t
                            log(t, f"決着フェーズ開始（プレイヤーがBASEを攻撃）")

        # Enemy units: 負方向（row 11→0）
        for u in e_units:
            if not u.alive:
                continue
            alive_enemies = [p for p in p_units if p.alive]
            if alive_enemies:
                nearest = min(alive_enemies, key=lambda p: abs(p.row - u.row))
                d = abs(nearest.row - u.row)
                if d <= u.rng:
                    u.attack_timer += DT
                    if u.attack_timer >= 1.0 / u.spd:
                        u.attack_timer = 0.0
                        nearest.hp -= u.atk
                else:
                    u.move_timer += DT
                    if u.move_timer >= 1.0 / u.move_spd:
                        u.move_timer = 0.0
                        u.row = max(u.row - 1.0, 0.0)
            else:
                u.move_timer += DT
                if u.move_timer >= 1.0 / u.move_spd:
                    u.move_timer = 0.0
                    u.row = max(u.row - 1.0, 0.0)
                if u.row <= 0.0:
                    u.attack_timer += DT
                    if u.attack_timer >= 1.0 / u.spd:
                        u.attack_timer = 0.0
                        p_base_hp -= u.atk
                        if t_decisive is None:
                            t_decisive = t
                            log(t, "決着フェーズ開始（敵がBASEを攻撃）")

        # 接敵判定: プレイヤーユニットと敵ユニットが中央付近(row4-8)で出会う
        if t_engagement is None:
            for pu in p_units:
                if not pu.alive:
                    continue
                for eu in e_units:
                    if not eu.alive:
                        continue
                    if abs(pu.row - eu.row) <= max(pu.rng, eu.rng):
                        t_engagement = t
                        log(t, f"接敵！ row≈{pu.row:.0f}")
                        return

    # ===== メインループ =====
    t = 0.0
    while t <= MAX_TIME:
        # 経済更新
        harvest_resources(p_eco, p_harvesters, p_harvest_timers, player_alloc)
        harvest_resources(e_eco, e_harvesters, e_harvest_timers, enemy_alloc)

        # 建設
        process_build_queue(p_eco, p_build_queue, p_buildings, t)
        process_build_queue(e_eco, e_build_queue, e_buildings, t)

        # 建設済み建物の更新
        new_p = update_buildings(p_eco, p_buildings, p_units, 0, t)
        new_e = update_buildings(e_eco, e_buildings, e_units, 1, t)

        # ハーベスター追加
        if new_p > 0:
            for _ in range(new_p):
                p_harvest_timers.append(0.0)
            p_harvesters += new_p
        if new_e > 0:
            for _ in range(new_e):
                e_harvest_timers.append(0.0)
            e_harvesters += new_e

        # ユニット最初の生産
        if t_first_unit is None and len(p_units) > 0:
            t_first_unit = t
            log(t, "プレイヤー最初のユニット生産")

        # 進軍・戦闘
        move_units(p_units, e_units, t)

        # 死亡ユニット除去
        p_units = [u for u in p_units if u.alive]
        e_units = [u for u in e_units if u.alive]

        # 勝利判定
        if e_base_hp <= 0:
            t_end = t
            winner = 'player'
            log(t, "プレイヤー勝利（敵BASE破壊）")
            break
        if p_base_hp <= 0:
            t_end = t
            winner = 'enemy'
            log(t, "敵勝利（プレイヤーBASE破壊）")
            break

        t += DT

    if t_end is None:
        t_end = t

    return {
        't_first_unit': t_first_unit,
        't_engagement': t_engagement,
        't_decisive': t_decisive,
        't_end': t_end,
        'winner': winner,
        'p_base_hp': max(0, p_base_hp),
        'e_base_hp': max(0, e_base_hp),
        'events': events,
    }


# ===== 標準シナリオ定義 =====
SCENARIOS = {
    '突特化': {
        'player_build': ['BARRACKS', 'BARRACKS', 'VILLAGE'],
        'player_alloc': {'wood': 2},
        'enemy_build': ['BARRACKS', 'VILLAGE', 'BARRACKS', 'FORTRESS'],
        'enemy_alloc': {'wood': 1, 'stone': 1},
    },
    'バランス': {
        'player_build': ['BARRACKS', 'VILLAGE', 'FORTRESS'],
        'player_alloc': {'wood': 1, 'stone': 1},
        'enemy_build': ['BARRACKS', 'VILLAGE', 'BARRACKS', 'FORTRESS'],
        'enemy_alloc': {'wood': 1, 'stone': 1},
    },
    '守特化': {
        'player_build': ['FORTRESS', 'VILLAGE', 'FORTRESS'],
        'player_alloc': {'stone': 2},
        'enemy_build': ['BARRACKS', 'VILLAGE', 'BARRACKS', 'FORTRESS'],
        'enemy_alloc': {'wood': 1, 'stone': 1},
    },
}

# 理想フェーズ配分（秒）
TARGET_FIRST_UNIT = (0, 90)    # 0〜1.5分で最初のユニット
TARGET_ENGAGEMENT = (30, 150)  # 30秒〜2.5分で接敵
TARGET_DECISIVE = (120, 300)   # 2〜5分で決着フェーズ
TARGET_END = (120, 420)        # 2〜7分でゲーム終了


def check_phase(label, value, lo, hi) -> bool:
    if value is None:
        print(f"    {label}: 未発生 ✗")
        return False
    ok = lo <= value <= hi
    mins = value / 60
    status = "✓" if ok else "✗"
    print(f"    {label}: {value:.0f}s ({mins:.1f}分) {status}  [目標: {lo}-{hi}s]")
    return ok


def run_all(verbose=False):
    print("=" * 60)
    print("5分フェーズ配分 検証シミュレーター")
    print("=" * 60)

    all_pass = True
    for scenario_name, cfg in SCENARIOS.items():
        print(f"\n■ シナリオ: {scenario_name}")
        res = simulate_game(
            cfg['player_build'], cfg['player_alloc'],
            cfg['enemy_build'], cfg['enemy_alloc'],
            verbose=verbose,
        )

        ok1 = check_phase("最初のユニット生産", res['t_first_unit'], *TARGET_FIRST_UNIT)
        ok2 = check_phase("最初の接敵", res['t_engagement'], *TARGET_ENGAGEMENT)
        ok3 = check_phase("決着フェーズ開始", res['t_decisive'], *TARGET_DECISIVE)
        ok4 = check_phase("ゲーム終了", res['t_end'], *TARGET_END)

        winner_label = {'player': 'プレイヤー勝利', 'enemy': '敵勝利', 'timeout': 'タイムアウト'}
        print(f"    結果: {winner_label[res['winner']]} "
              f"(Player BASE HP: {res['p_base_hp']:.0f} / Enemy BASE HP: {res['e_base_hp']:.0f})")

        scenario_pass = ok1 and ok2 and ok3 and ok4
        if not scenario_pass:
            all_pass = False
        print(f"    フェーズ判定: {'✓ 成立' if scenario_pass else '✗ 調整要'}")

        if verbose:
            print(f"    イベントログ:")
            for ev in res['events']:
                print(f"      {ev}")

    print("\n" + "=" * 60)
    print("総合判定:", "フェーズ配分成立 ✓" if all_pass else "数値調整が必要 ✗")
    print("=" * 60)
    return 0 if all_pass else 1


if __name__ == '__main__':
    verbose = '--verbose' in sys.argv or '-v' in sys.argv
    sys.exit(run_all(verbose))
