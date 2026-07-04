package main

import (
	"fmt"
	"math/rand"
	"time"
)

const (
	N100  = 100
	N1K   = 1000
	N10K  = 10000
	N100K = 100000
)

var (
	keys [N100K]int32
	miss [N100K]int32

	map100  map[int32]struct{}
	map1K   map[int32]struct{}
	map10K  map[int32]struct{}
	map100K map[int32]struct{}
)

func genData() {
	for i := 0; i < N100K; i++ {
		keys[i] = int32(i*2 + 1)
		miss[i] = int32(i * 2)
	}
}

func buildMaps() {
	map100 = make(map[int32]struct{}, N100)
	for i := 0; i < N100; i++ {
		map100[keys[i]] = struct{}{}
	}
	map1K = make(map[int32]struct{}, N1K)
	for i := 0; i < N1K; i++ {
		map1K[keys[i]] = struct{}{}
	}
	map10K = make(map[int32]struct{}, N10K)
	for i := 0; i < N10K; i++ {
		map10K[keys[i]] = struct{}{}
	}
	map100K = make(map[int32]struct{}, N100K)
	for i := 0; i < N100K; i++ {
		map100K[keys[i]] = struct{}{}
	}
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
	buildMaps()
	fmt.Println("=== Go hashset_bench ===")
	fmt.Println()

	// --- Build ---
	fmt.Println("[HashSet Build]")
	bench("map/100", 5000, func() {
		m := make(map[int32]struct{}, N100)
		for i := 0; i < N100; i++ {
			m[keys[i]] = struct{}{}
		}
	})
	bench("map/1K", 2000, func() {
		m := make(map[int32]struct{}, N1K)
		for i := 0; i < N1K; i++ {
			m[keys[i]] = struct{}{}
		}
	})
	bench("map/10K", 500, func() {
		m := make(map[int32]struct{}, N10K)
		for i := 0; i < N10K; i++ {
			m[keys[i]] = struct{}{}
		}
	})
	bench("map/100K", 100, func() {
		m := make(map[int32]struct{}, N100K)
		for i := 0; i < N100K; i++ {
			m[keys[i]] = struct{}{}
		}
	})

	// --- Lookup Hit (pre-built) ---
	fmt.Println()
	fmt.Println("[Lookup Hit]")
	bench("Hit/100", 50000, func() {
		sum := 0
		for i := 0; i < N100; i++ {
			if _, ok := map100[keys[i]]; ok {
				sum++
			}
		}
	})
	bench("Hit/1K", 50000, func() {
		sum := 0
		for i := 0; i < N1K; i++ {
			if _, ok := map1K[keys[i]]; ok {
				sum++
			}
		}
	})
	bench("Hit/10K", 10000, func() {
		sum := 0
		for i := 0; i < N10K; i++ {
			if _, ok := map10K[keys[i]]; ok {
				sum++
			}
		}
	})
	bench("Hit/100K", 2000, func() {
		sum := 0
		for i := 0; i < N100K; i++ {
			if _, ok := map100K[keys[i]]; ok {
				sum++
			}
		}
	})

	// --- Lookup Miss (pre-built) ---
	fmt.Println()
	fmt.Println("[Lookup Miss]")
	bench("Miss/1K", 50000, func() {
		sum := 0
		for i := 0; i < N1K; i++ {
			if _, ok := map1K[miss[i]]; ok {
				sum++
			}
		}
	})
	bench("Miss/10K", 10000, func() {
		sum := 0
		for i := 0; i < N10K; i++ {
			if _, ok := map10K[miss[i]]; ok {
				sum++
			}
		}
	})
	bench("Miss/100K", 2000, func() {
		sum := 0
		for i := 0; i < N100K; i++ {
			if _, ok := map100K[miss[i]]; ok {
				sum++
			}
		}
	})

	_ = rand.Int()
}
