package main

import (
	"fmt"
	"math/rand"
	"sort"
	"time"
)

const N = 100000

var (
	arr      [N]int32
	queries  [N]int32
	missQ    [N]int32
	eytz     [N]int32
)

func genData() {
	for i := 0; i < N; i++ {
		arr[i] = int32(i*2 + 1)
		queries[i] = arr[i]
		missQ[i] = int32(i * 2)
	}
	// Build eytzinger layout
	idx := 0
	var visit func(k int)
	visit = func(k int) {
		if k <= N {
			visit(2 * k)
			if idx < N {
				eytz[k-1] = arr[idx]
				idx++
			}
			visit(2*k + 1)
		}
	}
	visit(1)
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
	fmt.Println("=== Go binsearch_bench ===")
	fmt.Println()

	// Standard sort.Search (branchless)
	fmt.Println("[Hit]")
	bench("sort.Search Hit", 100, func() {
		sum := 0
		for i := 0; i < N; i++ {
			idx := sort.Search(len(arr[:]), func(j int) bool {
				return arr[j] >= queries[i]
			})
			if idx < N && arr[idx] == queries[i] {
				sum++
			}
		}
	})
	bench("Eytzinger Hit", 100, func() {
		sum := 0
		for i := 0; i < N; i++ {
			k := 1
			val := queries[i]
			for k <= N {
				v := eytz[k-1]
				if v < val {
					k = 2*k + 1
				} else if v == val {
					sum++
					break
				} else {
					k = 2 * k
				}
			}
		}
	})

	fmt.Println()
	fmt.Println("[Miss]")
	bench("sort.Search Miss", 100, func() {
		sum := 0
		for i := 0; i < N; i++ {
			idx := sort.Search(len(arr[:]), func(j int) bool {
				return arr[j] >= missQ[i]
			})
			if idx < N && arr[idx] == missQ[i] {
				sum++
			}
		}
	})
	bench("Eytzinger Miss", 100, func() {
		sum := 0
		for i := 0; i < N; i++ {
			k := 1
			val := missQ[i]
			for k <= N {
				v := eytz[k-1]
				if v < val {
					k = 2*k + 1
				} else if v == val {
					sum++
					break
				} else {
					k = 2 * k
				}
			}
		}
	})

	_ = rand.Int()
}
