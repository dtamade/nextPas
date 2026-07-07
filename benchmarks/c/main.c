#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <math.h>

typedef struct {
    const char* name;
    int n;
    long long total_ns;
    double mean_ns;
    long long min_ns;
    long long max_ns;
    double median_ns;
    double stddev_ns;
    double ops_per_sec;
} BenchmarkResult;

static int compare_long(const void* a, const void* b) {
    long long diff = *(const long long*)a - *(const long long*)b;
    return (diff > 0) - (diff < 0);
}

BenchmarkResult run_benchmark(const char* name, int n, void (*fn)(void)) {
    long long* times = (long long*)malloc(n * sizeof(long long));
    struct timespec start, end;

    for (int i = 0; i < n; i++) {
        clock_gettime(CLOCK_MONOTONIC, &start);
        fn();
        clock_gettime(CLOCK_MONOTONIC, &end);
        times[i] = (end.tv_sec - start.tv_sec) * 1000000000LL + (end.tv_nsec - start.tv_nsec);
    }

    qsort(times, n, sizeof(long long), compare_long);

    long long total = 0;
    for (int i = 0; i < n; i++) {
        total += times[i];
    }
    double mean = (double)total / n;

    double variance = 0.0;
    for (int i = 0; i < n; i++) {
        double diff = times[i] - mean;
        variance += diff * diff;
    }
    variance /= n;
    double stddev = sqrt(variance);

    double median;
    if (n % 2 == 0) {
        median = (times[n/2 - 1] + times[n/2]) / 2.0;
    } else {
        median = times[n/2];
    }

    double ops_per_sec = (mean > 0) ? 1e9 / mean : 0;

    BenchmarkResult result = {
        .name = name,
        .n = n,
        .total_ns = total,
        .mean_ns = mean,
        .min_ns = times[0],
        .max_ns = times[n-1],
        .median_ns = median,
        .stddev_ns = stddev,
        .ops_per_sec = ops_per_sec
    };

    free(times);
    return result;
}

// Fibonacci
int fib(int x) {
    if (x <= 1) return x;
    return fib(x-1) + fib(x-2);
}

void benchmark_fibonacci_inner(void) {
    volatile int result = fib(20);
    (void)result;
}

// Sorting
int compare_int(const void* a, const void* b) {
    return (*(const int*)a - *(const int*)b);
}

void benchmark_sorting_inner(void) {
    int data[1000];
    for (int i = 0; i < 1000; i++) {
        data[i] = rand() % 10000;
    }
    qsort(data, 1000, sizeof(int), compare_int);
}

// String concatenation
void benchmark_string_concat_inner(void) {
    char s[101];
    memset(s, 'a', 100);
    s[100] = '\0';
}

// Memory allocation
void benchmark_memory_alloc_inner(void) {
    unsigned char* data = (unsigned char*)malloc(100);
    for (int i = 0; i < 100; i++) {
        data[i] = (unsigned char)(i % 256);
    }
    free(data);
}

int main() {
    int n = 1000;

    printf("=== C Benchmark Results ===\n\n");

    BenchmarkResult results[] = {
        run_benchmark("Fibonacci(20)", n, benchmark_fibonacci_inner),
        run_benchmark("Sorting(1000)", n, benchmark_sorting_inner),
        run_benchmark("StringConcat(100)", n, benchmark_string_concat_inner),
        run_benchmark("MemoryAlloc(100)", n, benchmark_memory_alloc_inner),
    };

    int num_results = sizeof(results) / sizeof(results[0]);
    for (int i = 0; i < num_results; i++) {
        printf("%-20s: N=%d, Mean=%.0f ns, Min=%lld ns, Max=%lld ns, Median=%.0f ns, StdDev=%.0f ns, Ops/sec=%.0f\n",
               results[i].name, results[i].n, results[i].mean_ns, results[i].min_ns, results[i].max_ns,
               results[i].median_ns, results[i].stddev_ns, results[i].ops_per_sec);
    }

    printf("\n=== End of C Benchmarks ===\n");
    return 0;
}
