package main

import (
	"fmt"
	"math/rand"
	"sort"
	"time"
)

const N = 10000

func benchSort(name string, genData func() []int) {
	// warmup
	for i := 0; i < 10; i++ {
		d := genData()
		sort.Ints(d)
	}

	// calibrate
	iters := 100
	for {
		start := time.Now()
		for i := 0; i < iters; i++ {
			d := genData()
			sort.Ints(d)
		}
		elapsed := time.Since(start)
		if elapsed >= 200*time.Millisecond {
			break
		}
		if elapsed < time.Millisecond {
			iters *= 100
		} else {
			iters = int(float64(iters) * float64(200*time.Millisecond) / float64(elapsed))
		}
	}

	// measure (5 samples, take median)
	samples := make([]time.Duration, 5)
	for s := 0; s < 5; s++ {
		start := time.Now()
		for i := 0; i < iters; i++ {
			d := genData()
			sort.Ints(d)
		}
		samples[s] = time.Since(start)
	}
	sort.Slice(samples, func(i, j int) bool { return samples[i] < samples[j] })
	median := samples[2]
	nsPerOp := float64(median.Nanoseconds()) / float64(iters)
	opsPerSec := 1e9 / nsPerOp

	fmt.Printf("  %-40s %12d iters %10.1f ns/op %14.0f ops/s\n", name, iters, nsPerOp, opsPerSec)
}

func main() {
	rng := rand.New(rand.NewSource(42))
	randomData := make([]int, N)
	for i := range randomData {
		randomData[i] = rng.Intn(1000000)
	}

	fmt.Printf("=== Go sort.Ints Benchmark (N=%d) ===\n\n", N)

	benchSort("sort.Ints/random", func() []int {
		d := make([]int, N)
		copy(d, randomData)
		return d
	})
	benchSort("sort.Ints/sorted", func() []int {
		d := make([]int, N)
		for i := range d {
			d[i] = i
		}
		return d
	})
	benchSort("sort.Ints/reversed", func() []int {
		d := make([]int, N)
		for i := range d {
			d[i] = N - 1 - i
		}
		return d
	})
	benchSort("sort.Ints/all-same", func() []int {
		d := make([]int, N)
		for i := range d {
			d[i] = 7
		}
		return d
	})
}
