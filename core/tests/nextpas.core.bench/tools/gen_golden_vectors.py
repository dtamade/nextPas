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
