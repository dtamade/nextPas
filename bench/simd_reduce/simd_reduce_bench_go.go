package main

import (
	"fmt"
	"math"
	"math/rand"
	"time"
)

const (
	N4K  = 4096
	N64K = 65536
	N1M  = 1048576
)

var (
	arr32 []float32
	arr64 []float64
)

func genData() {
	arr32 = make([]float32, N1M)
	arr64 = make([]float64, N1M)
	for i := 0; i < N1M; i++ {
		arr32[i] = float32(i) * 0.001
		arr64[i] = float64(i) * 0.001
	}
}

func reduceSum32(arr []float32) float32 {
	s := float32(0)
	for _, v := range arr {
		s += v
	}
	return s
}

func reduceSum64(arr []float64) float64 {
	s := float64(0)
	for _, v := range arr {
		s += v
	}
	return s
}

func bench(name string, iters int, fn func()) {
	for i := 0; i < 3; i++ {
		fn()
	}
	start := time.Now()
	for i := 0; i < iters; i++ {
		fn()
	}
	dur := time.Since(start)
	nsPerOp := float64(dur.Nanoseconds()) / float64(iters)
	fmt.Printf("  %-30s %10d iters  %10.1f ns/op\n", name, iters, nsPerOp)
}

func main() {
	genData()
	fmt.Println("=== Go simd_reduce_bench ===")
	fmt.Println()

	// F32 Sum
	fmt.Println("[ReduceSum F32]")
	bench("Sum32/4K", 50000, func() {
		r := reduceSum32(arr32[:N4K])
		if r < 0 {
			fmt.Println(r)
		}
	})
	bench("Sum32/64K", 5000, func() {
		r := reduceSum32(arr32[:N64K])
		if r < 0 {
			fmt.Println(r)
		}
	})
	bench("Sum32/1M", 500, func() {
		r := reduceSum32(arr32[:N1M])
		if r < 0 {
			fmt.Println(r)
		}
	})

	// F64 Sum
	fmt.Println()
	fmt.Println("[ReduceSum F64]")
	bench("Sum64/4K", 50000, func() {
		r := reduceSum64(arr64[:N4K])
		if r < 0 {
			fmt.Println(r)
		}
	})
	bench("Sum64/64K", 5000, func() {
		r := reduceSum64(arr64[:N64K])
		if r < 0 {
			fmt.Println(r)
		}
	})
	bench("Sum64/1M", 500, func() {
		r := reduceSum64(arr64[:N1M])
		if r < 0 {
			fmt.Println(r)
		}
	})

	_ = math.NaN()
	_ = rand.Int()
}
