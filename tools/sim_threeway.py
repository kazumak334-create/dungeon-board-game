#!/usr/bin/env python3
"""
三すくみ検証シミュレーター（パラメータスイープ版）
崩のmin_range (2/3) × 守のmove_spd (0.10/0.08/0.06) の6パターンをテスト。
"""

import sys
from dataclasses import dataclass, field

sys.stdout.reconfigure(encoding='utf-8')

BASE_STATS = {
    'A': {'hp': 80.0,  'atk': 20.0, 'spd': 1.0,  'range': 1, 'min_range': 0, 'move_spd': 0.15},
    'T': {'hp': 200.0, 'atk': 25.0, 'spd': 0.5,  'range': 1, 'min_range': 0, 'move_spd': 0.10},
    'B': {'hp': 70.0,  'atk': 35.0, 'spd': 0.25, 'range': 3, 'min_range': 2, 'move_spd': 0.12},
}

NAMES = {'A': '突', 'T': '守', 'B': '崩'}

EXPECTED = {
    ('A', 'T'): 'T',
    ('T', 'A'): 'T',
    ('T', 'B'): 'B',
    ('B', 'T'): 'B',
    ('B', 'A'): 'A',
    ('A', 'B'): 'A',
    ('A', 'A'): None,
    ('T', 'T'): None,
    ('B', 'B'): None,
}

DT = 0.05
MAX_TIME = 600.0
INITIAL_GAP = 10

# 守move_spd=0.08 × 崩min_range=3 を固定し、崩ATKをスイープ
PARAM_SETS = [
    {'breaker_atk': 35, 'label': '崩ATK=35(現状)'},
    {'breaker_atk': 30, 'label': '崩ATK=30'},
    {'breaker_atk': 25, 'label': '崩ATK=25'},
    {'breaker_atk': 20, 'label': '崩ATK=20'},
    {'breaker_atk': 15, 'label': '崩ATK=15'},
]


def make_stats(params: dict) -> dict:
    import copy
    stats = copy.deepcopy(BASE_STATS)
    stats['T']['move_spd'] = 0.08   # 固定
    stats['B']['min_range'] = 3     # 固定
    stats['B']['atk'] = params['breaker_atk']
    return stats


@dataclass
class Unit:
    utype: str
    team: int
    pos: float
    stats: dict
    hp: float = field(init=False)
    atk: float = field(init=False)
    spd: float = field(init=False)
    rng: int = field(init=False)
    min_rng: int = field(init=False)
    move_spd: float = field(init=False)
    attack_timer: float = 0.0
    move_timer: float = 0.0

    def __post_init__(self):
        s = self.stats[self.utype]
        self.hp = s['hp']
        self.atk = s['atk']
        self.spd = s['spd']
        self.rng = s['range']
        self.min_rng = s['min_range']
        self.move_spd = s['move_spd']

    @property
    def alive(self):
        return self.hp > 0


def simulate(team0_types, team1_types, stats) -> dict:
    units0 = [Unit(t, 0, float(i), stats) for i, t in enumerate(team0_types)]
    units1 = [Unit(t, 1, float(INITIAL_GAP + i), stats) for i, t in enumerate(team1_types)]

    move_iv = {k: 1.0 / v['move_spd'] for k, v in stats.items()}
    atk_iv  = {k: 1.0 / v['spd']      for k, v in stats.items()}

    t = 0.0
    while t <= MAX_TIME:
        alive0 = [u for u in units0 if u.alive]
        alive1 = [u for u in units1 if u.alive]
        if not alive0 and not alive1:
            return _result('draw', t, units0, units1)
        if not alive0:
            return _result('team1', t, units0, units1)
        if not alive1:
            return _result('team0', t, units0, units1)

        for u in alive0 + alive1:
            enemies = alive1 if u.team == 0 else alive0
            if not enemies:
                continue
            target = min(enemies, key=lambda e: abs(e.pos - u.pos))
            d = abs(target.pos - u.pos)
            direction = 1.0 if target.pos > u.pos else -1.0

            if d < u.min_rng:
                u.move_timer += DT
                if u.move_timer >= move_iv[u.utype]:
                    u.move_timer = 0.0
                    u.pos -= direction
            elif d > u.rng:
                u.move_timer += DT
                if u.move_timer >= move_iv[u.utype]:
                    u.move_timer = 0.0
                    u.pos += direction
            else:
                u.attack_timer += DT
                if u.attack_timer >= atk_iv[u.utype]:
                    u.attack_timer = 0.0
                    target.hp -= u.atk
        t += DT

    return _result('timeout', t, units0, units1)


def _result(winner, t, units0, units1):
    hp0 = sum(u.hp for u in units0 if u.alive)
    hp1 = sum(u.hp for u in units1 if u.alive)
    return {'winner': winner, 'time': t, 'hp0': hp0, 'hp1': hp1}


def run_param(params: dict) -> tuple[bool, list[str]]:
    stats = make_stats(params)
    types = ['A', 'T', 'B']
    lines = []
    all_pass = True

    for count in [1, 3, 5]:
        lines.append(f"  [{count}v{count}]")
        group_pass = True
        for t0 in types:
            for t1 in types:
                if t0 >= t1:
                    continue
                res = simulate([t0]*count, [t1]*count, stats)
                w = res['winner']
                exp = EXPECTED.get((t0, t1))
                if exp is None:
                    ok = True
                elif exp == t0:
                    ok = w == 'team0'
                else:
                    ok = w == 'team1'
                if not ok:
                    group_pass = False
                    all_pass = False
                mark = '✓' if ok else '✗'
                winner_label = (NAMES[t0] if w == 'team0'
                                else NAMES[t1] if w == 'team1'
                                else '引分/TO')
                hp0_pct = res['hp0'] / (stats[t0]['hp'] * count) * 100
                hp1_pct = res['hp1'] / (stats[t1]['hp'] * count) * 100
                lines.append(f"    {mark} {NAMES[t0]}vs{NAMES[t1]}: {winner_label} "
                             f"(t={res['time']:.0f}s HP:{hp0_pct:.0f}%/{hp1_pct:.0f}%)")
        verdict = "✓OK" if group_pass else "✗NG"
        lines[-1] += f"  → {verdict}"

    return all_pass, lines


def main():
    print("=" * 70)
    print("三すくみ検証 — 守move_spd=0.08 × 崩min_range=3 固定 / 崩ATKスイープ")
    print("=" * 70)

    results = []
    for params in PARAM_SETS:
        label = params['label']
        ok, lines = run_param(params)
        results.append((label, ok, lines))

    # サマリー表示
    print("\n▼ サマリー")
    print(f"{'パラメータ':<36} {'1v1':>6} {'3v3':>6} {'5v5':>6} {'総合':>6}")
    print("-" * 64)
    for label, ok, lines in results:
        # 各スケールのOK/NG抽出
        scale_results = []
        for line in lines:
            if '→' in line:
                scale_results.append('✓' if '✓OK' in line else '✗')
        overall = '✓' if ok else '✗'
        cols = [s.center(6) for s in (scale_results + [''] * 3)[:3]]
        print(f"{label:<36} {cols[0]} {cols[1]} {cols[2]} {overall.center(6)}")

    # 詳細表示
    print("\n▼ 詳細")
    for label, ok, lines in results:
        print(f"\n{'─'*50}")
        print(f"【{label}】  総合: {'✓三すくみ成立' if ok else '✗NG'}")
        for line in lines:
            print(line)

    print("\n" + "=" * 70)
    passing = [l for l, ok, _ in results if ok]
    if passing:
        print("三すくみ成立パラメータ:")
        for l in passing:
            print(f"  → {l}")
    else:
        print("全パターン三すくみ未成立 — 追加調整が必要")
    print("=" * 70)
    return 0 if passing else 1


if __name__ == '__main__':
    sys.exit(main())
