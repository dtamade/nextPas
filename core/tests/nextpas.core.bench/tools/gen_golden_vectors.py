#!/usr/bin/env python3
"""bench 统计金标向量生成器 (F-25)。

生成 4 个冻结 golden `.inc` 文件，供 bench 统计测试套件 `{$I ...}` 引用：

  test_bench_mannwhitney/golden_mwu.inc
  test_bench_ks/golden_ks.inc
  test_bench_stats_advanced/golden_descriptive.inc
  test_bench_stats/golden_analyzer.inc

金标来源（外部参考实现）：
  scipy.stats.mannwhitneyu(use_continuity=False, alternative='two-sided',
                           method='asymptotic')
  scipy.stats.kstwobign.sf / scipy.stats.ks_2samp(statistic)
  scipy.stats.norm.cdf/ppf, scipy.stats.skew/kurtosis(bias=False), gmean
  numpy.percentile(method='linear'), numpy.std(ddof=1)

容差依据（Pascal 侧为近似实现，生成时逐例验证近似误差 < tol/2）：
  - ZToPValue: Hastings/Zelen-Severo 26.2.17，|Φ 误差| < 7.5e-8
  - KolmogorovCDF: 20 项级数，x>2 截断（用例约束 x <= 2）
  - NormalCDF: Abramowitz-Stegun 7.1.26，|误差| < 1.5e-7
  - NormalQuantile: Acklam 算法，相对误差 < 1.15e-9
  - 描述统计: Welford/线性插值为精确算法，仅浮点噪声

再生成:
  python3 -m venv /tmp/goldenv && /tmp/goldenv/bin/pip install scipy numpy
  cd core/tests/nextpas.core.bench && /tmp/goldenv/bin/python tools/gen_golden_vectors.py

数据集为手写字面量（无 RNG），Pascal/Python 解析同一十进制字面量得到
同一 IEEE double，因此数据侧无漂移；期望值以 repr（17 位有效数字）冻结。
"""

import math
import os
import sys

import numpy as np
import scipy
from scipy import stats
from scipy.stats import kstwobign, norm

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # core/tests/nextpas.core.bench

PROVENANCE = (
    f"scipy {scipy.__version__} / numpy {np.__version__}"
)

# ---------------------------------------------------------------------------
# Pascal 侧近似实现的 Python 复刻（仅用于生成期自检，不作为金标）
# ---------------------------------------------------------------------------

def hastings_two_sided_p(z):
    """nextpas.core.bench.base ZToPValue 的逐行复刻（含钳位）。"""
    az = abs(z)
    if az > 6.0:
        return 1e-6
    if az < 0.01:  # BENCH_SIGNIFICANCE_ALPHA_HIGH
        return 1.0
    t = 1.0 / (1.0 + 0.2316419 * az)
    k = 0.3989422804014327 * math.exp(-0.5 * az * az)
    p = k * (t * (0.319381530 + t * (-0.356563782 + t * (1.781477937 +
        t * (-1.821255978 + t * 1.330274429)))))
    p *= 2.0
    return min(1.0, max(1e-6, p))


def kolmogorov_cdf_20(x):
    """nextpas.core.bench.stats KolmogorovCDF 的复刻（20 项，x>2 截断）。"""
    if x <= 0:
        return 0.0
    if x > 2.0:
        return 1.0
    s = 0.0
    sq = -2.0 * x * x
    sign = 1.0
    for k in range(1, 21):
        s += sign * math.exp(k * k * sq)
        sign = -sign
    return min(1.0, max(0.0, 1.0 - 2.0 * s))


def as_normal_cdf(x):
    """nextpas.core.bench.base NormalCDF (A&S 7.1.26) 的复刻。"""
    a1, a2, a3, a4, a5 = (0.254829592, -0.284496736, 1.421413741,
                          -1.453152027, 1.061405429)
    p = 0.3275911
    ax = abs(x) * 0.7071067811865475244
    t = 1.0 / (1.0 + p * ax)
    r = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * \
        math.exp(-ax * ax)
    return 0.5 * (1.0 + r) if x >= 0 else 0.5 * (1.0 - r)


def mwu_pascal_z(a, b):
    """ComputeMannWhitneyPValue 的统计量复刻：midrank + tie 修正 sigma，U=min。"""
    n1, n2 = len(a), len(b)
    comb = sorted([(v, 0) for v in a] + [(v, 1) for v in b])
    n = n1 + n2
    r1 = 0.0
    tie_corr = 0.0
    i = 0
    while i < n:
        j = i
        while j + 1 < n and comb[j + 1][0] == comb[i][0]:
            j += 1
        run = j - i + 1
        if run > 1:
            tie_corr += run ** 3 - run
        avg_rank = (i + j + 2) / 2.0  # 1-based midrank
        cnt_a = sum(1 for t in range(i, j + 1) if comb[t][1] == 0)
        r1 += cnt_a * avg_rank
        i = j + 1
    u1 = n1 * n2 + n1 * (n1 + 1) / 2.0 - r1
    u2 = n1 * n2 - u1
    u = min(u1, u2)
    mu = n1 * n2 / 2.0
    sigma = math.sqrt(n1 * n2 / 12.0 * ((n + 1) - tie_corr / (n * (n - 1))))
    return (u - mu) / sigma, tie_corr


def ks1_pascal_d(data, mean, std, cdf):
    """KolmogorovSmirnovNormalTest 的 D 统计量复刻（双向 ECDF 比较）。"""
    s = sorted(data)
    n = len(s)
    maxd = 0.0
    for i, x in enumerate(s):
        f0 = cdf((x - mean) / std)
        maxd = max(maxd, abs((i + 1) / n - f0), abs(i / n - f0))
    return maxd


def acklam_ppf(p):
    """nextpas.core.bench.base NormalQuantile (Acklam) 的复刻。"""
    A = (-3.969683028665376e+01, 2.209460984245205e+02, -2.759285104469687e+02,
         1.383577518672690e+02, -3.066479806614716e+01, 2.506628277459239e+00)
    B = (-5.447609879822406e+01, 1.615858368580409e+02, -1.556989798598866e+02,
         6.680131188771972e+01, -1.328068155288572e+01)
    C = (-7.784894002430293e-03, -3.223964580411365e-01, -2.400758277161838e+00,
         -2.549732539343734e+00, 4.374664141464968e+00, 2.938163982698783e+00)
    D = (7.784695709041462e-03, 3.224671290700398e-01, 2.445134137142996e+00,
         3.754408661907416e+00)
    p_low = 0.02425
    if p <= 0.0:
        return -1e30
    if p >= 1.0:
        return 1e30
    if p == 0.5:
        return 0.0
    if p < p_low:
        q = math.sqrt(-2.0 * math.log(p))
        return (((((C[0] * q + C[1]) * q + C[2]) * q + C[3]) * q + C[4]) * q + C[5]) / \
               ((((D[0] * q + D[1]) * q + D[2]) * q + D[3]) * q + 1.0)
    if p <= 1.0 - p_low:
        q = p - 0.5
        r = q * q
        return (((((A[0] * r + A[1]) * r + A[2]) * r + A[3]) * r + A[4]) * r + A[5]) * q / \
               (((((B[0] * r + B[1]) * r + B[2]) * r + B[3]) * r + B[4]) * r + 1.0)
    q = math.sqrt(-2.0 * math.log(1.0 - p))
    return -(((((C[0] * q + C[1]) * q + C[2]) * q + C[3]) * q + C[4]) * q + C[5]) / \
            ((((D[0] * q + D[1]) * q + D[2]) * q + D[3]) * q + 1.0)


# ---------------------------------------------------------------------------
# 冻结数据集（手写字面量；勿改动——改动即需同步重生成全部 .inc）
# ---------------------------------------------------------------------------

MWU_CASES = [
    # (name, A, B, 说明)
    ("NOTIES",
     [12.1, 12.4, 11.8, 12.9, 13.2, 12.6, 11.9, 12.3, 13.0, 12.7, 12.2, 12.8],
     [12.85, 13.1, 12.5, 13.6, 13.8, 13.3, 12.75, 13.05, 13.9, 13.45, 12.95, 13.55],
     "无 tie，中等偏移"),
    ("TIES",
     [100, 101, 101, 102, 100, 103, 101, 102, 100, 101],
     [101, 102, 103, 102, 104, 103, 102, 101, 103, 104, 102, 103, 101, 102],
     "重 tie（取整计时值），tie 修正生效"),
    ("STRONG",
     [50.2, 49.8, 50.5, 51.0, 49.5, 50.8, 50.1, 49.9, 50.6, 50.3,
      49.7, 50.9, 50.4, 50.0, 49.6],
     [52.1, 51.8, 52.5, 50.45, 52.8, 52.2, 51.9, 52.6, 50.65, 52.3,
      50.7, 52.0, 51.7, 52.4, 51.35],
     "强分离带少量重叠，小 p 区"),
    ("SMALL",
     [200.5, 201.2, 199.8, 200.9, 201.5, 200.2, 199.5, 201.0,
      200.7, 199.9, 200.4, 201.3],
     [200.6, 201.4, 200.0, 201.1, 201.6, 200.35, 199.65, 201.05,
      200.85, 200.1, 200.55, 201.35],
     "微小偏移，高 p 区"),
]

KS2_CASES = [
    ("TIES",
     [1, 2, 3, 3, 5, 7, 8, 9],
     [2, 3, 4, 4, 5, 6, 8, 10, 11, 12],
     "小样本 + 跨样本 tie"),
    ("SHIFT",
     [9.4, 10.1, 9.8, 10.5, 9.2, 10.8, 9.9, 10.2, 9.6, 10.4,
      9.1, 10.6, 9.7, 10.0, 9.5, 10.3, 9.3, 10.7, 9.85, 10.15,
      9.45, 10.35, 9.65, 10.25, 9.55],
     [10.65, 11.0, 10.3, 11.2, 10.05, 10.8, 10.5, 11.35, 10.2, 10.9,
      10.4, 11.1, 10.1, 10.7, 10.55, 11.25, 10.35, 10.0, 10.85, 10.6],
     "中等平移带重叠，n=25/20"),
]

KS2_IDENTICAL = [3.1, 4.2, 5.3, 6.4, 7.5, 8.6, 9.7, 10.8, 11.9, 13.0, 14.1, 15.2]

# n=32（>=30 才走连续 p 公式分支），近似 N(50,10) 的手写样本
KS1_DATA = [
    43.2, 55.1, 48.7, 61.3, 39.8, 52.4, 46.9, 58.2, 44.5, 50.7,
    36.1, 63.8, 49.3, 53.6, 41.7, 57.4, 47.2, 51.8, 45.6, 59.1,
    38.4, 54.3, 48.1, 62.5, 42.9, 56.7, 46.3, 50.2, 40.5, 60.4,
    44.1, 52.9,
]
KS1_MEAN = 50.0
KS1_STD = 10.0

DESC_DATA = [
    10.2, 11.5, 10.8, 12.1, 10.5, 11.0, 10.2, 13.4, 10.9, 11.7,
    10.4, 12.8, 11.2, 10.6, 15.3, 10.7, 11.9, 10.3, 12.4, 11.1,
]

AN_DATA = [
    3.7, 5.2, 4.1, 6.8, 3.9, 5.5, 4.6, 7.3, 4.2, 5.9,
    3.8, 6.1, 4.4, 5.0, 4.8, 6.5, 4.0, 5.7, 4.3, 8.1,
]
AN_RATIOS = [1.25, 0.8, 1.1, 0.95, 1.4, 0.7, 1.05, 0.9]

NQ_POINTS = [0.001, 0.025, 0.16, 0.84, 0.975, 0.999]

# --- tranche 2 (F-25 扩展): CI / 离群点 / TrimmedMean / CohenD / Bayesian / Welch ---

CI_LEVELS = [0.95, 0.99]

# 离群点数据集：偏差集设计为排名无并列，且各含一个
# 「正确 MAD 判为离群、旧 off-by-one MAD (F-31) 判为正常」的边界点。
OUT_ODD = [49.85, 50.45, 45.5, 49.2, 50.95, 49.45, 50.0, 51.45,
           48.7, 50.25, 72.4, 49.65, 51.15, 48.1, 50.65]  # n=15 (奇数 MAD 路径)
OUT_EVEN = [19.55, 20.6, 15.5, 19.8, 20.85, 18.95, 20.35, 29.6,
            19.3, 21.25, 20.1, 18.4]  # n=12 (偶数 MAD 路径)
TUKEY_FACTOR = 1.5
ZSCORE_THR = 2.5
MODZ_THR = 3.5

TRIM_PCTS = [20.0, 12.5]  # 12.5% 覆盖 Trunc(n*pct/100) 非整乘积路径

CD_A = [15.2, 16.1, 14.8, 15.9, 15.5, 16.4, 14.9, 15.7, 15.3, 16.0, 15.1, 15.8]
CD_B = [16.8, 17.5, 16.2, 17.9, 17.1, 16.5, 17.3, 16.9, 17.6, 16.4, 17.0, 17.8]
# 与 CD_A 几乎同分布的对照组（Welch 布尔 False 例）
WN_B = [15.25, 16.0, 14.95, 15.85, 15.6, 16.3, 15.0, 15.65, 15.4, 16.05, 15.05, 15.9]

BAYES_DATA = [5.2, 4.8, 5.5, 5.1, 4.9, 5.3, 5.0, 5.4, 4.7, 5.6]
BAYES_PRIOR_MEAN, BAYES_PRIOR_STD, BAYES_SIGMA = 4.0, 1.0, 0.5
BAYES2_PRIOR_MEAN, BAYES2_PRIOR_STD = 6.0, 0.8  # 第二例 ASigma=0 → σ=样本 ddof=1 标准差

# --- tranche 3: OLS 回归 + 变异系数 ---
# x = 迭代次数量级；y = slope*x + intercept + 手写噪声（全整数, double 精确）。
# TIGHT: 3.7x+250 ± <=60  → R² 贴近但严格小于 1（走 LDenY 正常路径）；
# LOOSE: 5x+800 ± <=1500 → R² 中段，公式/口径错误无法躲进「反正都接近 1」。
OLS_X = [10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0]
OLS_Y_TIGHT = [299.0, 316.0, 460.0, 590.0, 1008.0, 2055.0, 4010.0, 7628.0]
OLS_Y_LOOSE = [1750.0, 200.0, 2150.0, 350.0, 3100.0, 2100.0, 7300.0, 10400.0]


def t_ppf_2sided(level, df):
    return float(stats.t.ppf(0.5 + level / 2.0, df))


def pascal_tinv(level, df):
    """Pascal TINV9x_DATA 复刻：3 位小数标准 t 表 (df 1..30)，超出回退 z。"""
    if 1 <= df <= 30:
        return round(t_ppf_2sided(level, df), 3)
    return {0.90: 1.645, 0.95: 1.96, 0.99: 2.576}[level]


def old_buggy_mad(data):
    """F-31 修复前的 MAD 复刻（奇偶双 off-by-one），仅用于取证边界点。"""
    s = sorted(data)
    n = len(s)
    mid = n // 2
    med = s[mid] if n % 2 else (s[mid - 1] + s[mid]) / 2.0
    devs = sorted([med - x for x in s[:mid]] + [x - med for x in s[mid + 1:]])
    t = n // 2
    return devs[t] if n % 2 else (devs[t - 1] + devs[t]) / 2.0


# ---------------------------------------------------------------------------
# .inc 生成辅助
# ---------------------------------------------------------------------------

def fmt(v):
    """repr → Pascal Double 字面量（17 位有效数字，round-trip 无损）。"""
    r = repr(float(v))
    if "e" in r or "." in r or "inf" in r or "nan" in r:
        return r
    return r + ".0"


def pas_array(name, values, indent="  "):
    lines = [f"{indent}{name}: array[0..{len(values) - 1}] of Double = ("]
    row = []
    for i, v in enumerate(values):
        row.append(fmt(v))
        if len(row) == 4 or i == len(values) - 1:
            sep = "," if i != len(values) - 1 else ");"
            lines.append(indent + "  " + ", ".join(row) + sep)
            row = []
    return "\n".join(lines)


def pas_int_array(name, values, indent="  "):
    require(len(values) > 0, f"{name}: 离群点金标集不应为空")
    body = ", ".join(str(int(v)) for v in values)
    return f"{indent}{name}: array[0..{len(values) - 1}] of Integer = ({body});"


def header(purpose):
    return (
        "{ AUTO-GENERATED by tools/gen_golden_vectors.py -- DO NOT EDIT.\n"
        f"  {purpose}\n"
        f"  Reference: {PROVENANCE}\n"
        "  Regen: /tmp/goldenv/bin/python tools/gen_golden_vectors.py\n"
        "  (venv: python3 -m venv /tmp/goldenv && pip install scipy numpy) }\n"
    )


REPORT = []


def note(line):
    REPORT.append(line)
    print(line)


def require(cond, msg):
    if not cond:
        print(f"FATAL: {msg}", file=sys.stderr)
        sys.exit(1)


# ---------------------------------------------------------------------------
# 1. Mann-Whitney U golden
# ---------------------------------------------------------------------------

def gen_mwu():
    out = [header("Mann-Whitney U 双侧渐近 p 值金标 (无连续性修正, tie 修正 sigma)"),
           "const"]
    tol = 1e-5
    for idx, (name, a, b, desc) in enumerate(MWU_CASES, 1):
        z, tie = mwu_pascal_z(a, b)
        golden = float(stats.mannwhitneyu(
            a, b, use_continuity=False, alternative="two-sided",
            method="asymptotic").pvalue)
        sim = hastings_two_sided_p(z)
        delta = abs(sim - golden)
        require(0.05 < abs(z) < 4.5,
                f"MWU {name}: z={z:.4f} 落在钳位/截断风险区，调整数据集")
        require(golden > 2e-6, f"MWU {name}: golden p={golden:.3g} 贴近 1e-6 钳位")
        require(delta < tol / 2,
                f"MWU {name}: Hastings 近似偏差 {delta:.3g} >= tol/2")
        if name == "NOTIES":
            require(tie == 0.0, "MWU NOTIES: 数据集意外含 tie")
        if name == "TIES":
            require(tie > 0.0, "MWU TIES: 数据集应含 tie")
        note(f"MWU {name:7s} z={z:+.5f} tieC={tie:8.1f} "
             f"scipy_p={golden:.10g} pascal_sim={sim:.10g} |d|={delta:.2e}")
        out.append(f"  {{ case {idx}: {desc}; z={z:+.5f}, tie 修正项={tie:.0f} }}")
        out.append(pas_array(f"GOLDEN_MWU_A{idx}", a))
        out.append(pas_array(f"GOLDEN_MWU_B{idx}", b))
        out.append(f"  GOLDEN_MWU_P{idx} = {fmt(golden)};")
        out.append("")
    out.append(f"  GOLDEN_MWU_P_TOL = {fmt(tol)};")
    out.append("")
    return "\n".join(out)


# ---------------------------------------------------------------------------
# 2. Kolmogorov-Smirnov golden
# ---------------------------------------------------------------------------

def gen_ks():
    out = [header("K-S 检验金标: 双样本精确 D + 渐近 p (kstwobign), "
                  "单样本 D + Lilliefors 修正 p, NormalQuantile"),
           "const"]
    d_tol, p_tol = 1e-12, 1e-6
    for idx, (name, a, b, desc) in enumerate(KS2_CASES, 1):
        d = float(stats.ks_2samp(a, b).statistic)
        neff = len(a) * len(b) / (len(a) + len(b))
        x = math.sqrt(neff) * d
        golden_p = float(kstwobign.sf(x))
        sim_p = 1.0 - kolmogorov_cdf_20(x)
        delta = abs(sim_p - golden_p)
        require(0.3 < x <= 2.0,
                f"KS2 {name}: x={x:.4f} 超出 20 项级数安全区 (0.3, 2]")
        require(delta < p_tol / 2,
                f"KS2 {name}: 级数近似偏差 {delta:.3g} >= tol/2")
        note(f"KS2 {name:6s} D={d:.10g} x={x:.5f} "
             f"scipy_p={golden_p:.10g} pascal_sim={sim_p:.10g} |d|={delta:.2e}")
        out.append(f"  {{ case {idx}: {desc}; x=sqrt(n1*n2/(n1+n2))*D={x:.5f} }}")
        out.append(pas_array(f"GOLDEN_KS2_A{idx}", a))
        out.append(pas_array(f"GOLDEN_KS2_B{idx}", b))
        out.append(f"  GOLDEN_KS2_D{idx} = {fmt(d)};")
        out.append(f"  GOLDEN_KS2_P{idx} = {fmt(golden_p)};")
        out.append("")
    out.append("  { case 3: 两侧同一数组 -> D=0, p=1（精确边界） }")
    out.append(pas_array("GOLDEN_KS2_IDENT", KS2_IDENTICAL))
    out.append("")

    # 单样本 (n>=30 连续 p 分支)
    n = len(KS1_DATA)
    require(n >= 30, "KS1: n 必须 >= 30 才走连续 p 公式分支")
    d_exact = ks1_pascal_d(KS1_DATA, KS1_MEAN, KS1_STD, norm.cdf)
    d_sim = ks1_pascal_d(KS1_DATA, KS1_MEAN, KS1_STD, as_normal_cdf)
    corr = 1.0 + 0.12 / math.sqrt(n) + 0.11 / n
    x_exact = math.sqrt(n) * d_exact * corr
    x_sim = math.sqrt(n) * d_sim * corr
    golden_p1 = float(kstwobign.sf(x_exact))
    sim_p1 = 1.0 - kolmogorov_cdf_20(x_sim)
    require(0.3 < x_exact <= 2.0, f"KS1: x={x_exact:.4f} 超出安全区")
    require(abs(d_sim - d_exact) < 1e-6 / 2,
            f"KS1: A&S NormalCDF 引入的 D 偏差过大 {abs(d_sim - d_exact):.3g}")
    require(abs(sim_p1 - golden_p1) < 1e-4 / 2,
            f"KS1: p 近似偏差过大 {abs(sim_p1 - golden_p1):.3g}")
    note(f"KS1 n={n} D={d_exact:.10g} (sim d|{abs(d_sim - d_exact):.2e}) "
         f"x={x_exact:.5f} scipy_p={golden_p1:.10g} "
         f"pascal_sim={sim_p1:.10g} |d|={abs(sim_p1 - golden_p1):.2e}")
    out.append(f"  {{ 单样本 vs N({KS1_MEAN:g},{KS1_STD:g}²), n={n} (>=30 连续 p 分支);")
    out.append(f"    p = 1 - K(sqrt(n)*D*(1+0.12/sqrt(n)+0.11/n)), x={x_exact:.5f} }}")
    out.append(pas_array("GOLDEN_KS1_DATA", KS1_DATA))
    out.append(f"  GOLDEN_KS1_MEAN = {fmt(KS1_MEAN)};")
    out.append(f"  GOLDEN_KS1_STD = {fmt(KS1_STD)};")
    out.append(f"  GOLDEN_KS1_D = {fmt(d_exact)};")
    out.append(f"  GOLDEN_KS1_P = {fmt(golden_p1)};")
    out.append("")

    # NormalQuantile (Acklam vs norm.ppf)
    nq_tol = 1e-8
    zs = []
    for p in NQ_POINTS:
        z_ref = float(norm.ppf(p))
        z_sim = acklam_ppf(p)
        require(abs(z_sim - z_ref) < nq_tol / 2,
                f"NQ p={p}: Acklam 偏差 {abs(z_sim - z_ref):.3g}")
        zs.append(z_ref)
        note(f"NQ  p={p:<6g} ppf={z_ref:+.12g} acklam|d|={abs(z_sim - z_ref):.2e}")
    out.append("  { NormalQuantile (Acklam) vs scipy norm.ppf }")
    out.append(pas_array("GOLDEN_NQ_P", NQ_POINTS))
    out.append(pas_array("GOLDEN_NQ_Z", zs))
    out.append("")
    out.append(f"  GOLDEN_KS_D_TOL = {fmt(d_tol)};")
    out.append(f"  GOLDEN_KS_P_TOL = {fmt(p_tol)};")
    out.append(f"  GOLDEN_KS1_D_TOL = {fmt(1e-6)};")
    out.append(f"  GOLDEN_KS1_P_TOL = {fmt(1e-4)};")
    out.append(f"  GOLDEN_NQ_TOL = {fmt(nq_tol)};")
    out.append("")
    return "\n".join(out)


# ---------------------------------------------------------------------------
# 3. TAdvancedStats 描述统计 golden
# ---------------------------------------------------------------------------

def gen_descriptive():
    d = np.asarray(DESC_DATA)
    tol = 1e-9
    vals = {
        "MEAN": float(np.mean(d)),
        "MEDIAN": float(np.median(d)),
        "STDDEV": float(np.std(d, ddof=1)),
        "SKEW": float(stats.skew(d, bias=False)),
        "KURT": float(stats.kurtosis(d, fisher=True, bias=False)),
        "P5": float(np.percentile(d, 5)),
        "P25": float(np.percentile(d, 25)),
        "P50": float(np.percentile(d, 50)),
        "P75": float(np.percentile(d, 75)),
        "P95": float(np.percentile(d, 95)),
        "P99": float(np.percentile(d, 99)),
    }
    vals["IQR"] = vals["P75"] - vals["P25"]
    for k, v in vals.items():
        note(f"DESC {k:6s} = {v:.15g}")
    out = [header("TAdvancedStats 描述统计金标: 样本方差(ddof=1)/无偏 G1/G2/"
                  "线性插值分位数"),
           "const",
           f"  {{ n={len(DESC_DATA)}，右偏计时样本，含重复值 }}",
           pas_array("GOLDEN_DESC_DATA", DESC_DATA)]
    for k, v in vals.items():
        out.append(f"  GOLDEN_DESC_{k} = {fmt(v)};")
    out.append(f"  GOLDEN_DESC_TOL = {fmt(tol)};")
    out.append("")

    # --- tranche 2: ConfidenceInterval (t 表) ---
    n = len(DESC_DATA)
    mean = vals["MEAN"]
    sem = vals["STDDEV"] / math.sqrt(n)
    ci_tol = 1e-3
    out.append("  { ConfidenceInterval: t 分布双侧临界值 (df=n-1)；Pascal 用 3 位小数")
    out.append("    t 表，容差覆盖表舍入 (|dt|<=5e-4 -> |d 界|<=dt*sem) }")
    for level in CI_LEVELS:
        t_exact = t_ppf_2sided(level, n - 1)
        t_table = pascal_tinv(level, n - 1)
        lo, hi = mean - t_exact * sem, mean + t_exact * sem
        sim_lo, sim_hi = mean - t_table * sem, mean + t_table * sem
        delta = max(abs(sim_lo - lo), abs(sim_hi - hi))
        require(delta < ci_tol / 2,
                f"CI {level}: t 表舍入偏差 {delta:.3g} >= tol/2")
        tag = str(int(level * 100))
        note(f"CI{tag} t_exact={t_exact:.6f} t_table={t_table} "
             f"[{lo:.10g}, {hi:.10g}] |d|={delta:.2e}")
        out.append(f"  GOLDEN_CI{tag}_LO = {fmt(lo)};")
        out.append(f"  GOLDEN_CI{tag}_HI = {fmt(hi)};")
    out.append(f"  GOLDEN_CI_TOL = {fmt(ci_tol)};")
    out.append("")

    # --- tranche 2: 离群点检测 (Tukey / ZScore / ModifiedZScore) ---
    out.append("  { 离群点金标: 下标数组按原始数据顺序；ModZ 集含 F-31 边界点")
    out.append("    (正确 MAD 判离群、旧 off-by-one MAD 漏判) }")
    for dname, data in (("ODD", OUT_ODD), ("EVEN", OUT_EVEN)):
        d = np.asarray(data)
        med = float(np.median(d))
        q1, q3 = float(np.percentile(d, 25)), float(np.percentile(d, 75))
        iqr = q3 - q1
        lo_f, hi_f = q1 - TUKEY_FACTOR * iqr, q3 + TUKEY_FACTOR * iqr
        tukey_idx = [i for i, x in enumerate(data) if x < lo_f or x > hi_f]
        for x in data:  # 边界决定性: 每点距最近围栏至少 0.5
            require(min(abs(x - lo_f), abs(x - hi_f)) > 0.5,
                    f"OUT_{dname} Tukey: 点 {x} 距围栏过近")
        mean_, std_ = float(np.mean(d)), float(np.std(d, ddof=1))
        zs = [abs(x - mean_) / std_ for x in data]
        z_idx = [i for i, z in enumerate(zs) if z > ZSCORE_THR]
        require(all(abs(z - ZSCORE_THR) > 0.2 for z in zs),
                f"OUT_{dname} ZScore: 存在距阈值 <0.2 的临界 z")
        mad = float(np.median(np.abs(d - med)))
        modz = [abs(0.6745 * (x - med) / mad) for x in data]
        modz_idx = [i for i, z in enumerate(modz) if z > MODZ_THR]
        require(all(abs(z - MODZ_THR) > 0.2 for z in modz),
                f"OUT_{dname} ModZ: 存在距阈值 <0.2 的临界 modz")
        # F-31 取证: 旧 MAD 必须更大且改变离群集合
        omad = old_buggy_mad(data)
        old_modz_idx = [i for i, x in enumerate(data)
                        if abs(0.6745 * (x - med) / omad) > MODZ_THR]
        require(omad > mad,
                f"OUT_{dname}: 旧 MAD {omad} 未大于正确 MAD {mad}")
        require(old_modz_idx != modz_idx,
                f"OUT_{dname}: 数据集未能区分 F-31 新旧 MAD 行为")
        note(f"OUT_{dname:4s} MAD={mad:g} (旧 bug MAD={omad:g}) "
             f"tukey={tukey_idx} z={z_idx} modz={modz_idx} (旧 modz={old_modz_idx})")
        out.append(f"  {{ n={len(data)}: MAD={mad:g}, 旧 off-by-one MAD={omad:g} }}")
        out.append(pas_array(f"GOLDEN_OUT_{dname}", data))
        out.append(pas_int_array(f"GOLDEN_OUT_{dname}_TUKEY_IDX", tukey_idx))
        out.append(pas_int_array(f"GOLDEN_OUT_{dname}_Z_IDX", z_idx))
        out.append(pas_int_array(f"GOLDEN_OUT_{dname}_MODZ_IDX", modz_idx))
        out.append("")
    out.append(f"  GOLDEN_OUT_TUKEY_FACTOR = {fmt(TUKEY_FACTOR)};")
    out.append(f"  GOLDEN_OUT_Z_THR = {fmt(ZSCORE_THR)};")
    out.append(f"  GOLDEN_OUT_MODZ_THR = {fmt(MODZ_THR)};")
    out.append("")
    return "\n".join(out)


# ---------------------------------------------------------------------------
# 4. TBenchStatsAnalyzer golden (Mean/Median/StdDev/Percentiles/GeometricMean)
# ---------------------------------------------------------------------------

def gen_analyzer():
    d = np.asarray(AN_DATA)
    tol = 1e-9
    vals = {
        "MEAN": float(np.mean(d)),
        "MEDIAN": float(np.median(d)),
        "STDDEV": float(np.std(d, ddof=1)),
        "P5": float(np.percentile(d, 5)),
        "P25": float(np.percentile(d, 25)),
        "P50": float(np.percentile(d, 50)),
        "P75": float(np.percentile(d, 75)),
        "P95": float(np.percentile(d, 95)),
        "P99": float(np.percentile(d, 99)),
        "GEOMEAN": float(stats.gmean(np.asarray(AN_RATIOS))),
    }
    for k, v in vals.items():
        note(f"AN   {k:7s} = {v:.15g}")
    out = [header("TBenchStatsAnalyzer 金标: Mean/Median/StdDev(ddof=1)/"
                  "ComputePercentiles(线性插值)/GeometricMean"),
           "const",
           pas_array("GOLDEN_AN_DATA", AN_DATA),
           pas_array("GOLDEN_AN_RATIOS", AN_RATIOS)]
    for k, v in vals.items():
        out.append(f"  GOLDEN_AN_{k} = {fmt(v)};")
    out.append(f"  GOLDEN_AN_TOL = {fmt(tol)};")
    out.append("")

    # --- tranche 2: TrimmedMean (scipy.stats.trim_mean, 双侧 floor 截断) ---
    out.append("  { TrimmedMean: scipy trim_mean(data, pct/100)；双侧各截 "
               "Trunc(n*pct/100) }")
    for pct in TRIM_PCTS:
        tv = float(stats.trim_mean(d, pct / 100.0))
        cut_scipy = int(pct / 100.0 * len(AN_DATA))
        cut_pascal = math.trunc(len(AN_DATA) * pct / 100.0)
        require(cut_scipy == cut_pascal,
                f"TRIM {pct}: scipy/Pascal 截断口径不一致 {cut_scipy}/{cut_pascal}")
        tag = {20.0: "20", 12.5: "125"}[pct]
        note(f"TRIM {pct:>5}% cut={cut_scipy} -> {tv:.15g}")
        out.append(f"  GOLDEN_AN_TRIM_PCT_{tag} = {fmt(pct)};")
        out.append(f"  GOLDEN_AN_TRIM_{tag} = {fmt(tv)};")
    out.append("")

    # --- tranche 2: Cohen's d (合并 ddof=1 方差) ---
    a, b = np.asarray(CD_A), np.asarray(CD_B)
    na, nb = len(a), len(b)
    pooled = (((na - 1) * np.var(a, ddof=1) + (nb - 1) * np.var(b, ddof=1))
              / (na + nb - 2))
    cohend = float((np.mean(a) - np.mean(b)) / math.sqrt(pooled))
    note(f"COHEND = {cohend:.15g}")
    out.append("  { Cohen's d: (meanA-meanB)/sqrt(pooled ddof=1 var)，带符号 }")
    out.append(pas_array("GOLDEN_CD_A", CD_A))
    out.append(pas_array("GOLDEN_CD_B", CD_B))
    out.append(f"  GOLDEN_COHEND = {fmt(cohend)};")
    out.append("")

    # --- tranche 2: Welch 启发式布尔 (HasHeuristicDifferenceAt @ alpha=0.05) ---
    def welch_t_df(x, y):
        vx, vy = np.var(x, ddof=1) / len(x), np.var(y, ddof=1) / len(y)
        t = abs(float(np.mean(x) - np.mean(y))) / math.sqrt(vx + vy)
        df = (vx + vy) ** 2 / (vx ** 2 / (len(x) - 1) + vy ** 2 / (len(y) - 1))
        return t, df

    wn = np.asarray(WN_B)
    t_ab, df_ab = welch_t_df(a, b)
    t_an, df_an = welch_t_df(a, wn)
    # 决定性: |t| 相对 t 表临界值（df 下取整与上取整两种取法）都有 >=20% 裕度
    for dfp in (math.floor(df_ab), math.ceil(df_ab)):
        require(t_ab > 1.2 * pascal_tinv(0.95, dfp),
                f"WELCH AB: t={t_ab:.3f} 对 df={dfp} 裕度不足")
    for dfp in (math.floor(df_an), math.ceil(df_an)):
        require(t_an < 0.8 * pascal_tinv(0.95, dfp),
                f"WELCH A-WN: t={t_an:.3f} 对 df={dfp} 裕度不足")
    note(f"WELCH AB t={t_ab:.4f} df={df_ab:.2f} -> True; "
         f"A-WN t={t_an:.4f} df={df_an:.2f} -> False")
    out.append("  { Welch 启发式布尔: alpha=0.05；t 对表临界值双向 >=20% 裕度 }")
    out.append(pas_array("GOLDEN_WN_B", WN_B))
    out.append("  GOLDEN_WELCH_AB_DIFF = True;")
    out.append("  GOLDEN_WELCH_AWN_DIFF = False;")
    out.append("")

    # --- tranche 2: Bayesian 正态-正态共轭 ---
    bd = np.asarray(BAYES_DATA)
    z975 = float(norm.ppf(0.975))

    def conjugate(prior_mean, prior_std, sigma):
        n_ = len(bd)
        post_var = 1.0 / (1.0 / prior_std ** 2 + n_ / sigma ** 2)
        post_mean = post_var * (prior_mean / prior_std ** 2
                                + n_ * float(np.mean(bd)) / sigma ** 2)
        post_std = math.sqrt(post_var)
        return post_mean, post_std, post_mean - z975 * post_std, \
            post_mean + z975 * post_std

    pm1, ps1, cl1, cu1 = conjugate(BAYES_PRIOR_MEAN, BAYES_PRIOR_STD, BAYES_SIGMA)
    sigma2 = math.sqrt(float(np.var(bd, ddof=1)))  # ASigma=0 -> 样本 ddof=1 std
    pm2, ps2, _, _ = conjugate(BAYES2_PRIOR_MEAN, BAYES2_PRIOR_STD, sigma2)
    # Acklam z 与 scipy ppf 的偏差对可信区间的实际影响须 < tol/2
    require(abs(acklam_ppf(0.975) - z975) * ps1 < 1e-8 / 2.0,
            "BAYES: Acklam z 偏差对可信区间影响过大")
    note(f"BAYES1 post=({pm1:.12g}, {ps1:.12g}) cred=[{cl1:.12g}, {cu1:.12g}]")
    note(f"BAYES2 sigma={sigma2:.12g} post=({pm2:.12g}, {ps2:.12g})")
    out.append("  { Bayesian 正态-正态共轭: 例1 显式 sigma；例2 ASigma=0 -> "
               "样本 ddof=1 std }")
    out.append(pas_array("GOLDEN_BAYES_DATA", BAYES_DATA))
    out.append(f"  GOLDEN_BAYES_PRIOR_MEAN = {fmt(BAYES_PRIOR_MEAN)};")
    out.append(f"  GOLDEN_BAYES_PRIOR_STD = {fmt(BAYES_PRIOR_STD)};")
    out.append(f"  GOLDEN_BAYES_SIGMA = {fmt(BAYES_SIGMA)};")
    out.append(f"  GOLDEN_BAYES_POST_MEAN = {fmt(pm1)};")
    out.append(f"  GOLDEN_BAYES_POST_STD = {fmt(ps1)};")
    out.append(f"  GOLDEN_BAYES_CRED_LO = {fmt(cl1)};")
    out.append(f"  GOLDEN_BAYES_CRED_HI = {fmt(cu1)};")
    out.append(f"  GOLDEN_BAYES2_PRIOR_MEAN = {fmt(BAYES2_PRIOR_MEAN)};")
    out.append(f"  GOLDEN_BAYES2_PRIOR_STD = {fmt(BAYES2_PRIOR_STD)};")
    out.append(f"  GOLDEN_BAYES2_POST_MEAN = {fmt(pm2)};")
    out.append(f"  GOLDEN_BAYES2_POST_STD = {fmt(ps2)};")
    # --- tranche 3: OLS 回归 (scipy.stats.linregress; R² = rvalue²) ---
    def ols_replica(xs, ys):
        # Pascal ComputeOLSRegression 单循环公式逐字复刻（同序求和, double 语义）
        n_ = len(xs)
        sx = sy = sxy = sx2 = sy2 = 0.0
        for xi, yi in zip(xs, ys):
            sx += xi
            sy += yi
            sxy += xi * yi
            sx2 += xi * xi
            sy2 += yi * yi
        dd = n_ * sx2 - sx * sx
        slope = (n_ * sxy - sx * sy) / dd
        icept = (sy - slope * sx) / n_
        num = n_ * sxy - sx * sy
        deny = n_ * sy2 - sy * sy
        return slope, icept, (num * num) / (dd * deny)

    ols_tol = 1e-8
    out.append("  { OLS: scipy.stats.linregress 金标; 复刻公式自检 < tol/2 }")
    out.append(pas_array("GOLDEN_OLS_X", OLS_X))
    r2_by_tag = {}
    for tag, ys in (("TIGHT", OLS_Y_TIGHT), ("LOOSE", OLS_Y_LOOSE)):
        lr = stats.linregress(np.asarray(OLS_X), np.asarray(ys))
        r2 = float(lr.rvalue) ** 2
        r2_by_tag[tag] = r2
        ps_, pi_, pr2 = ols_replica(OLS_X, ys)
        require(abs(ps_ - float(lr.slope)) < ols_tol / 2.0,
                f"OLS {tag}: slope 复刻偏差 {abs(ps_ - float(lr.slope)):.3g}")
        require(abs(pi_ - float(lr.intercept)) < ols_tol / 2.0,
                f"OLS {tag}: intercept 复刻偏差 {abs(pi_ - float(lr.intercept)):.3g}")
        require(abs(pr2 - r2) < ols_tol / 2.0,
                f"OLS {tag}: R2 复刻偏差 {abs(pr2 - r2):.3g}")
        note(f"OLS {tag}: slope={float(lr.slope):.12g} "
             f"icept={float(lr.intercept):.12g} R2={r2:.12g}")
        out.append(pas_array(f"GOLDEN_OLS_Y_{tag}", ys))
        out.append(f"  GOLDEN_OLS_{tag}_SLOPE = {fmt(lr.slope)};")
        out.append(f"  GOLDEN_OLS_{tag}_INTERCEPT = {fmt(lr.intercept)};")
        out.append(f"  GOLDEN_OLS_{tag}_R2 = {fmt(r2)};")
    # 数据集设计契约：TIGHT 近乎完美但严格 < 1，LOOSE 落中段，两组真正分档
    require(0.999 < r2_by_tag["TIGHT"] < 1.0,
            f"OLS TIGHT R2 不在 (0.999,1): {r2_by_tag['TIGHT']}")
    require(0.5 < r2_by_tag["LOOSE"] < 0.99,
            f"OLS LOOSE R2 不在 (0.5,0.99): {r2_by_tag['LOOSE']}")

    # --- tranche 3: CoefficientOfVariation = std(ddof=1)/mean（比值非百分比）---
    def welford_cv(xs):
        # Pascal WelfordMeanVariance + Sqrt/mean 复刻
        mean_ = 0.0
        m2 = 0.0
        cnt = 0
        for v in xs:
            cnt += 1
            delta = v - mean_
            mean_ += delta / cnt
            m2 += delta * (v - mean_)
        return math.sqrt(m2 / (cnt - 1)) / mean_

    cv = float(np.std(d, ddof=1) / np.mean(d))
    require(abs(welford_cv(AN_DATA) - cv) < tol / 2.0,
            f"CV: Welford 复刻偏差 {abs(welford_cv(AN_DATA) - cv):.3g}")
    note(f"AN   CV      = {cv:.15g}")
    out.append(f"  GOLDEN_AN_CV = {fmt(cv)};")
    out.append("")
    out.append(f"  GOLDEN_TRIM_TOL = {fmt(1e-9)};")
    out.append(f"  GOLDEN_CD_TOL = {fmt(1e-9)};")
    out.append(f"  GOLDEN_BAYES_TOL = {fmt(1e-8)};")
    out.append(f"  GOLDEN_OLS_TOL = {fmt(ols_tol)};")
    out.append("")
    return "\n".join(out)


def main():
    targets = {
        os.path.join(ROOT, "test_bench_mannwhitney", "golden_mwu.inc"): gen_mwu,
        os.path.join(ROOT, "test_bench_ks", "golden_ks.inc"): gen_ks,
        os.path.join(ROOT, "test_bench_stats_advanced",
                     "golden_descriptive.inc"): gen_descriptive,
        os.path.join(ROOT, "test_bench_stats", "golden_analyzer.inc"): gen_analyzer,
    }
    for path, gen in targets.items():
        content = gen()
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        note(f"WROTE {os.path.relpath(path, ROOT)} ({len(content)} bytes)")
    note("ALL-OK")


if __name__ == "__main__":
    main()
