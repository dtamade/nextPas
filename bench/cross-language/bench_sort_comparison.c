/* bench_sort_comparison.c — C 跨语言排序基准
 *
 * 与 nextPas Pascal 基准同场景对比。
 * 编译: gcc -O2 -o bench_sort_c bench_sort_comparison.c -lm
 * 运行: ./bench_sort_c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <stdint.h>
#include <math.h>

#define N 1000
#define SEED 42
#define WARMUP 100
#define SAMPLES 30
#define MIN_DURATION_NS 200000000LL  /* 0.2 秒 */

static int g_data[N];

/* LCG PRNG (与 Pascal/Go/Rust 相同种子) */
static uint64_t rng_state = SEED;
static uint64_t rng_next(void) {
    rng_state = rng_state * 6364136223846793005ULL + 1442695040888963407ULL;
    return rng_state;
}

static void init_data(void) {
    rng_state = SEED;
    for (int i = 0; i < N; i++)
        g_data[i] = (int)(rng_next() % 1000000);
}

static int64_t monotonic_ns(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (int64_t)ts.tv_sec * 1000000000LL + ts.tv_nsec;
}

/* Insertion Sort */
static void insertion_sort(int *d, int n) {
    for (int i = 1; i < n; i++) {
        int key = d[i];
        int j = i - 1;
        while (j >= 0 && d[j] > key) {
            d[j + 1] = d[j];
            j--;
        }
        d[j + 1] = key;
    }
}

/* QuickSort (stdlib) */
static int cmp_int(const void *a, const void *b) {
    return *(const int *)a - *(const int *)b;
}

/* Merge Sort */
static int tmp_buf[N];

static void merge_sort(int *d, int n) {
    if (n <= 1) return;
    int mid = n / 2;
    merge_sort(d, mid);
    merge_sort(d + mid, n - mid);
    int i = 0, j = mid, k = 0;
    while (i < mid && j < n) {
        if (d[i] <= d[j]) tmp_buf[k++] = d[i++];
        else tmp_buf[k++] = d[j++];
    }
    while (i < mid) tmp_buf[k++] = d[i++];
    while (j < n) tmp_buf[k++] = d[j++];
    memcpy(d, tmp_buf, n * sizeof(int));
}

typedef void (*sort_func)(int *, int);

static double bench_sort(const char *name, sort_func fn, int use_qsort) {
    /* Warmup */
    for (int w = 0; w < WARMUP; w++) {
        int d[N];
        memcpy(d, g_data, sizeof(g_data));
        if (use_qsort) qsort(d, N, sizeof(int), cmp_int);
        else fn(d, N);
    }

    /* 校准: 找到合适的迭代次数 */
    int64_t iters = 100;
    while (1) {
        int64_t start = monotonic_ns();
        for (int64_t i = 0; i < iters; i++) {
            int d[N];
            memcpy(d, g_data, sizeof(g_data));
            if (use_qsort) qsort(d, N, sizeof(int), cmp_int);
            else fn(d, N);
        }
        int64_t elapsed = monotonic_ns() - start;
        if (elapsed >= MIN_DURATION_NS / 10) break;
        iters *= 2;
    }

    /* 采样 */
    double samples[SAMPLES];
    for (int s = 0; s < SAMPLES; s++) {
        int64_t start = monotonic_ns();
        for (int64_t i = 0; i < iters; i++) {
            int d[N];
            memcpy(d, g_data, sizeof(g_data));
            if (use_qsort) qsort(d, N, sizeof(int), cmp_int);
            else fn(d, N);
        }
        int64_t elapsed = monotonic_ns() - start;
        samples[s] = (double)elapsed / iters;
    }

    /* 计算均值和标准差 */
    double sum = 0, sum_sq = 0;
    for (int s = 0; s < SAMPLES; s++) {
        sum += samples[s];
        sum_sq += samples[s] * samples[s];
    }
    double mean = sum / SAMPLES;
    double variance = (sum_sq - SAMPLES * mean * mean) / (SAMPLES - 1);
    double stddev = variance > 0 ? sqrt(variance) : 0;
    double ops_per_sec = mean > 0 ? 1e9 / mean : 0;

    printf("  %-40s %12ld iters %10.1f ns/op %14.0f ops/s %10.1f stddev\n",
           name, iters, mean, ops_per_sec, stddev);

    return mean;
}

int main(void) {
    init_data();

    printf("=== C Sort Benchmark (N=%d, samples=%d) ===\n\n", N, SAMPLES);
    printf("  %-40s %12s %10s %14s %10s\n",
           "Name", "Iterations", "ns/op", "ops/s", "StdDev");
    printf("  ");
    for (int i = 0; i < 98; i++) putchar('-');
    printf("\n");

    bench_sort("InsertionSort", insertion_sort, 0);
    bench_sort("QuickSort", NULL, 1);
    bench_sort("MergeSort", merge_sort, 0);

    printf("\n=== benchstat format ===\n");
    printf("%-40s %12s %8s %12s %10s\n", "name", "ns/op", "+- %", "B/op", "allocs/op");

    return 0;
}
