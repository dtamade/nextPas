package main

import (
	"fmt"
	"math"
	"math/rand"
	"sort"
	"time"
)

// BenchmarkResult holds benchmark results
type BenchmarkResult struct {
	Name     string
	N        int
	TotalNs  int64
	MeanNs   float64
	MinNs    int64
	MaxNs    int64
	MedianNs float64
	StdDevNs float64
	OpsPerSec float64
}

// RunBenchmark runs a benchmark function
func RunBenchmark(name string, n int, fn func()) BenchmarkResult {
	times := make([]int64, n)

	for i := 0; i < n; i++ {
		start := time.Now().Nanosecond()
		fn()
		end := time.Now().Nanosecond()
		times[i] = int64(end - start)
		if times[i] < 0 {
			times[i] += 1e9
		}
	}

	sort.Slice(times, func(i, j int) bool { return times[i] < times[j] })

	var total int64
	for _, t := range times {
		total += t
	}
	mean := float64(total) / float64(n)

	variance := 0.0
	for _, t := range times {
		diff := float64(t) - mean
		variance += diff * diff
	}
	variance /= float64(n)
	stddev := math.Sqrt(variance)

	median := float64(times[n/2])
	if n%2 == 0 {
		median = (float64(times[n/2-1]) + float64(times[n/2])) / 2.0
	}

	opsPerSec := 0.0
	if mean > 0 {
		opsPerSec = 1e9 / mean
	}

	return BenchmarkResult{
		Name:      name,
		N:         n,
		TotalNs:   total,
		MeanNs:    mean,
		MinNs:     times[0],
		MaxNs:     times[n-1],
		MedianNs:  median,
		StdDevNs:  stddev,
		OpsPerSec: opsPerSec,
	}
}

// fib calculates Fibonacci number
func fib(x int) int {
	if x <= 1 {
		return x
	}
	return fib(x-1) + fib(x-2)
}

// BenchmarkFibonacci benchmarks Fibonacci calculation
func BenchmarkFibonacci(n int) BenchmarkResult {
	return RunBenchmark("Fibonacci(20)", n, func() {
		fib(20)
	})
}

// BenchmarkSorting benchmarks slice sorting
func BenchmarkSorting(n int) BenchmarkResult {
	return RunBenchmark("Sorting(1000)", n, func() {
		data := make([]int, 1000)
		for i := range data {
			data[i] = rand.Intn(10000)
		}
		sort.Ints(data)
	})
}

// BenchmarkStringConcat benchmarks string concatenation
func BenchmarkStringConcat(n int) BenchmarkResult {
	return RunBenchmark("StringConcat(100)", n, func() {
		s := ""
		for i := 0; i < 100; i++ {
			s += "a"
		}
	})
}

// BenchmarkMapOperations benchmarks map operations
func BenchmarkMapOperations(n int) BenchmarkResult {
	return RunBenchmark("MapOps(1000)", n, func() {
		m := make(map[string]int)
		for i := 0; i < 1000; i++ {
			m[fmt.Sprintf("key%d", i)] = i
		}
		for i := 0; i < 1000; i++ {
			_ = m[fmt.Sprintf("key%d", i)]
		}
	})
}

// BenchmarkMemoryAlloc benchmarks memory allocation
func BenchmarkMemoryAlloc(n int) BenchmarkResult {
	return RunBenchmark("MemoryAlloc(100)", n, func() {
		data := make([]byte, 100)
		for i := range data {
			data[i] = byte(i % 256)
		}
	})
}

func main() {
	n := 1000

	fmt.Println("=== Go Benchmark Results ===")
	fmt.Println()

	results := []BenchmarkResult{
		BenchmarkFibonacci(n),
		BenchmarkSorting(n),
		BenchmarkStringConcat(n),
		BenchmarkMapOperations(n),
		BenchmarkMemoryAlloc(n),
	}

	for _, r := range results {
		fmt.Printf("%-20s: N=%d, Mean=%.0f ns, Min=%d ns, Max=%d ns, Median=%.0f ns, StdDev=%.0f ns, Ops/sec=%.0f\n",
			r.Name, r.N, r.MeanNs, r.MinNs, r.MaxNs, r.MedianNs, r.StdDevNs, r.OpsPerSec)
	}

	fmt.Println()
	fmt.Println("=== End of Go Benchmarks ===")
}
